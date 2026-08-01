-- // UltraMM2 v1.0 by Ultrakotik// --
-- Специализированный чит для Murder Mystery 2 с ролевым ESP, аимботом, авто-подбором и защитой

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local Mouse = LocalPlayer:GetMouse()

-- Определение игры (MM2 обычно определяется по имени плейса или наличию специфичных объектов)
local IsMM2 = (game.PlaceId == 142823291) -- основной PlaceId MM2, но бывают реплики
-- Если не определить, можно попробовать по наличию папки "GameFolder"

local function isMurderMystery()
    return workspace:FindFirstChild("GameFolder") ~= nil -- в MM2 есть папка GameFolder
end
IsMM2 = isMurderMystery()

-- Настройки
local ESP = {
    Enabled = true,
    ShowBox = true,
    ShowLine = true,
    ShowDistance = true,
    ShowName = true,
    ShowRole = true, -- новая фишка
    MaxDistance = 2000,
    TeamCheck = false, -- в MM2 команды нет, но роли есть
    Colors = {
        Murderer = Color3.fromRGB(255, 0, 0),   -- красный
        Sheriff = Color3.fromRGB(0, 100, 255),  -- синий
        Innocent = Color3.fromRGB(0, 255, 0)    -- зелёный
    }
}

local Aimbot = {
    Enabled = false,
    AimKey = Enum.UserInputType.MouseButton2,
    FOVRadius = 150,
    Smoothness = 0.3,
    TargetPart = "Head",
    TeamCheck = true, -- не аимить на союзных невинных (в MM2 все враги, кроме шерифа для убийцы)
    PrioritizeMurderer = true -- приоритет на убийцу, если ты шериф
}

local AutoPickup = {
    Enabled = false,
    PickupRange = 15 -- радиус подбора оружия (ножа/пистолета)
}

local GodMode = {
    Enabled = false,
    Health = 999999,
    MaxHealth = 999999
}

local FastKill = {
    Enabled = false -- убийца убивает мгновенно при касании
}

-- Хранилище объектов ESP
local playerESPs = {}

-- Функция определения роли игрока в MM2
local function getPlayerRole(player)
    if not IsMM2 then return "Unknown" end
    local char = player.Character
    if not char then return "Unknown" end
    -- В MM2 роли определяются по папкам в GameFolder или по оружию
    local gameFolder = workspace:FindFirstChild("GameFolder")
    if gameFolder then
        -- У убийцы в инвентаре нож, у шерифа пистолет, у невинных ничего
        local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeHandle")
        local gun = char:FindFirstChild("Pistol") or char:FindFirstChild("Revolver")
        if knife then
            return "Murderer"
        elseif gun then
            return "Sheriff"
        else
            return "Innocent"
        end
    end
    return "Unknown"
end

-- Удаление ESP игрока
local function removeESP(player)
    local esp = playerESPs[player]
    if esp then
        if esp.Connection then esp.Connection:Disconnect() end
        for _, obj in pairs(esp) do
            if type(obj) == "table" and obj.Remove then obj:Remove() end
        end
        playerESPs[player] = nil
    end
end

-- Создание ESP для одного игрока
local function createESP(player)
    local esp = {}
    local role = "Unknown"

    local function getColorFromRole(r)
        if r == "Murderer" then return ESP.Colors.Murderer
        elseif r == "Sheriff" then return ESP.Colors.Sheriff
        elseif r == "Innocent" then return ESP.Colors.Innocent
        else return Color3.fromRGB(255,255,255)
        end
    end

    -- Создаём объекты Drawing
    if ESP.ShowBox then
        esp.Box = Drawing.new("Square")
        esp.Box.Visible = false
        esp.Box.Thickness = 2
        esp.Box.Color = getColorFromRole("Unknown")
        esp.Box.Filled = false
    end
    if ESP.ShowLine then
        esp.Line = Drawing.new("Line")
        esp.Line.Visible = false
        esp.Line.Color = Color3.fromRGB(255,255,255)
        esp.Line.Thickness = 1
    end
    if ESP.ShowDistance then
        esp.DistanceText = Drawing.new("Text")
        esp.DistanceText.Visible = false
        esp.DistanceText.Color = Color3.fromRGB(255,255,255)
        esp.DistanceText.Size = 14
        esp.DistanceText.Center = true
        esp.DistanceText.Outline = true
    end
    if ESP.ShowName then
        esp.NameText = Drawing.new("Text")
        esp.NameText.Visible = false
        esp.NameText.Color = Color3.fromRGB(255,255,255)
        esp.NameText.Size = 14
        esp.NameText.Center = true
        esp.NameText.Outline = true
    end
    if ESP.ShowRole then
        esp.RoleText = Drawing.new("Text")
        esp.RoleText.Visible = false
        esp.RoleText.Color = Color3.fromRGB(255,255,255)
        esp.RoleText.Size = 14
        esp.RoleText.Center = true
        esp.RoleText.Outline = true
    end

    -- Цикл обновления
    local function update()
        if not ESP.Enabled then
            for _, obj in pairs(esp) do
                if type(obj) == "table" and obj.Visible ~= nil then obj.Visible = false end
            end
            return
        end
        role = getPlayerRole(player)
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        if rootPart and head then
            local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
            if distance > ESP.MaxDistance then
                for _, obj in pairs(esp) do if type(obj) == "table" and obj.Visible ~= nil then obj.Visible = false end end
                return
            end
            local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
            local bottom = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0,2,0))
            if top.OnScreen or bottom.OnScreen then
                local height = math.abs(top.Y - bottom.Y)
                local width = height * 0.7
                local x = top.X - width/2
                local y = top.Y
                local color = getColorFromRole(role)
                if esp.Box then
                    esp.Box.Visible = true
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(x, y)
                    esp.Box.Color = color
                end
                if esp.Line then
                    esp.Line.Visible = true
                    esp.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                    esp.Line.To = Vector2.new(top.X, bottom.Y)
                    esp.Line.Color = color
                end
                if esp.DistanceText then
                    esp.DistanceText.Visible = true
                    esp.DistanceText.Text = string.format("%.0f м", distance)
                    esp.DistanceText.Position = Vector2.new(top.X, bottom.Y + 5)
                end
                if esp.NameText then
                    esp.NameText.Visible = true
                    esp.NameText.Text = player.Name
                    esp.NameText.Position = Vector2.new(top.X, top.Y - 20)
                end
                if esp.RoleText then
                    esp.RoleText.Visible = true
                    esp.RoleText.Text = role
                    esp.RoleText.Position = Vector2.new(top.X, top.Y - 35)
                    esp.RoleText.Color = color
                end
            else
                for _, obj in pairs(esp) do if type(obj) == "table" and obj.Visible ~= nil then obj.Visible = false end end
            end
        else
            for _, obj in pairs(esp) do if type(obj) == "table" and obj.Visible ~= nil then obj.Visible = false end end
        end
    end

    esp.Connection = RunService.RenderStepped:Connect(update)
    playerESPs[player] = esp
end

-- Инициализация ESP для всех игроков
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then createESP(player) end
end
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then createESP(player) end
end)
Players.PlayerRemoving:Connect(removeESP)

-- ====== AIMBOT MM2 ======
local AimbotCircle = Drawing.new("Circle")
AimbotCircle.Visible = false
AimbotCircle.Radius = Aimbot.FOVRadius
AimbotCircle.Color = Color3.fromRGB(255,255,0)
AimbotCircle.Thickness = 1
AimbotCircle.Filled = false
AimbotCircle.NumSides = 64

local function getTarget()
    local myRole = getPlayerRole(LocalPlayer)
    local mousePos = UIS:GetMouseLocation()
    local bestTarget = nil
    local bestScore = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetPart = player.Character:FindFirstChild(Aimbot.TargetPart)
            if targetPart then
                local pos = Camera:WorldToViewportPoint(targetPart.Position)
                if pos.Z > 0 then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if dist <= Aimbot.FOVRadius then
                        -- Приоритеты
                        local role = getPlayerRole(player)
                        local score = dist
                        if Aimbot.PrioritizeMurderer and myRole == "Sheriff" and role == "Murderer" then
                            score = score - 500 -- сильный приоритет убийце
                        elseif myRole == "Murderer" and role == "Sheriff" then
                            score = score - 300 -- шериф опасен
                        end
                        if score < bestScore then
                            bestScore = score
                            bestTarget = targetPart
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

local function aimAt(targetPart)
    if not targetPart then return end
    local targetPos = targetPart.Position
    local camPos = Camera.CFrame.Position
    local newCFrame = CFrame.new(camPos, targetPos)
    if Aimbot.Smoothness > 0 then
        Camera.CFrame = Camera.CFrame:Lerp(newCFrame, 1 - Aimbot.Smoothness)
    else
        Camera.CFrame = newCFrame
    end
end

RunService.RenderStepped:Connect(function()
    AimbotCircle.Position = UIS:GetMouseLocation()
    AimbotCircle.Visible = Aimbot.Enabled
    if Aimbot.Enabled and UIS:IsMouseButtonPressed(Aimbot.AimKey) then
        local target = getTarget()
        if target then aimAt(target) end
    end
end)

-- ====== AUTO PICKUP ======
if AutoPickup.Enabled and IsMM2 then
    coroutine.wrap(function()
        while wait(0.3) do
            if AutoPickup.Enabled then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local root = char.HumanoidRootPart
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("Tool") and (obj.Name == "Knife" or obj.Name == "Pistol" or obj.Name == "Revolver" or obj.Name == "KnifeHandle") and obj.Parent ~= char then
                            if (root.Position - obj.Parent.Position).Magnitude <= AutoPickup.PickupRange then
                                obj.Parent = char
                            end
                        end
                    end
                end
            end
        end
    end)()
end

-- ====== GOD MODE ======
if GodMode.Enabled and IsMM2 then
    LocalPlayer.CharacterAdded:Connect(function(char)
        local humanoid = char:WaitForChild("Humanoid")
        humanoid.MaxHealth = GodMode.MaxHealth
        humanoid.Health = GodMode.Health
        humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health < GodMode.MaxHealth then
                humanoid.Health = GodMode.MaxHealth
            end
        end)
    end)
    -- для текущего персонажа
    local currentChar = LocalPlayer.Character
    if currentChar then
        local humanoid = currentChar:WaitForChild("Humanoid")
        humanoid.MaxHealth = GodMode.MaxHealth
        humanoid.Health = GodMode.Health
        humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if humanoid.Health < GodMode.MaxHealth then
                humanoid.Health = GodMode.MaxHealth
            end
        end)
    end
end

-- ====== FAST KILL (убийца) ======
if FastKill.Enabled and IsMM2 then
    LocalPlayer.CharacterAdded:Connect(function(char)
        local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeHandle")
        if knife then
            -- Делаем нож убийственным при касании
            knife.Touched:Connect(function(part)
                local targetChar = part.Parent
                if targetChar and targetChar:IsA("Model") and Players:GetPlayerFromCharacter(targetChar) then
                    local humanoid = targetChar:FindFirstChild("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        humanoid.Health = 0
                    end
                end
            end)
        end
    end)
end

-- ====== GUI ======
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltraMM2_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Красный квадрат
    local icon = Instance.new("TextButton")
    icon.Size = UDim2.new(0, 32, 0, 32)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    icon.Text = ""
    icon.BorderSizePixel = 0
    icon.AutoButtonColor = false
    icon.Active = true
    icon.Draggable = true
    icon.Parent = screenGui

    -- Панель
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 220, 0, 340)
    panel.Position = UDim2.new(0, 50, 0, 10)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui

    -- Заголовок
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    title.TextColor3 = Color3.new(1,1,1)
    title.Text = IsMM2 and "UltraMM2 v1" or "UltraESP (не MM2)"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = panel

    -- Вкладки
    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 0, 25)
    tabFrame.Position = UDim2.new(0,0,0,25)
    tabFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
    tabFrame.Parent = panel

    local espTab = Instance.new("TextButton")
    espTab.Size = UDim2.new(0.5, -1, 1, 0)
    espTab.BackgroundColor3 = Color3.fromRGB(80,80,80)
    espTab.Text = "ESP"
    espTab.TextColor3 = Color3.new(1,1,1)
    espTab.Font = Enum.Font.SourceSans
    espTab.TextSize = 13
    espTab.BorderSizePixel = 0
    espTab.Parent = tabFrame

    local aimTab = Instance.new("TextButton")
    aimTab.Size = UDim2.new(0.5, -1, 1, 0)
    aimTab.Position = UDim2.new(0.5,0,0,0)
    aimTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
    aimTab.Text = "Aimbot"
    aimTab.TextColor3 = Color3.new(1,1,1)
    aimTab.Font = Enum.Font.SourceSans
    aimTab.TextSize = 13
    aimTab.BorderSizePixel = 0
    aimTab.Parent = tabFrame

    local modTab = Instance.new("TextButton")
    modTab.Size = UDim2.new(0, 0, 0, 0) -- скрыто, если нужно будет
    modTab.Visible = false
    modTab.Parent = tabFrame

    -- Страницы
    local espPage = Instance.new("Frame")
    espPage.Size = UDim2.new(1, -10, 0, 250)
    espPage.Position = UDim2.new(0,5,0,55)
    espPage.BackgroundColor3 = Color3.fromRGB(30,30,30)
    espPage.Visible = true
    espPage.Parent = panel

    local aimPage = Instance.new("Frame")
    aimPage.Size = UDim2.new(1, -10, 0, 250)
    aimPage.Position = UDim2.new(0,5,0,55)
    aimPage.BackgroundColor3 = Color3.fromRGB(30,30,30)
    aimPage.Visible = false
    aimPage.Parent = panel

    -- Переключение вкладок
    espTab.MouseButton1Click:Connect(function()
        espPage.Visible = true
        aimPage.Visible = false
        espTab.BackgroundColor3 = Color3.fromRGB(80,80,80)
        aimTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end)
    aimTab.MouseButton1Click:Connect(function()
        espPage.Visible = false
        aimPage.Visible = true
        aimTab.BackgroundColor3 = Color3.fromRGB(80,80,80)
        espTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end)

    -- Помощник для тогглов
    local function addToggle(parent, text, getFunc, setFunc)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = getFunc() and Color3.fromRGB(0,170,0) or Color3.fromRGB(170,0,0)
        btn.Text = text .. ": " .. (getFunc() and "ON" or "OFF")
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.Parent = parent
        btn.Position = UDim2.new(0,0,0, (#parent:GetChildren() * 24) - 24)
        btn.MouseButton1Click:Connect(function()
            local newState = not getFunc()
            setFunc(newState)
            btn.BackgroundColor3 = newState and Color3.fromRGB(0,170,0) or Color3.fromRGB(170,0,0)
            btn.Text = text .. ": " .. (newState and "ON" or "OFF")
        end)
    end

    -- ESP тогглы
    addToggle(espPage, "ESP Enabled", function() return ESP.Enabled end, function(v) ESP.Enabled = v end)
    addToggle(espPage, "Show Box", function() return ESP.ShowBox end, function(v) ESP.ShowBox = v end)
    addToggle(espPage, "Show Line", function() return ESP.ShowLine end, function(v) ESP.ShowLine = v end)
    addToggle(espPage, "Show Distance", function() return ESP.ShowDistance end, function(v) ESP.ShowDistance = v end)
    addToggle(espPage, "Show Name", function() return ESP.ShowName end, function(v) ESP.ShowName = v end)
    addToggle(espPage, "Show Role", function() return ESP.ShowRole end, function(v) ESP.ShowRole = v end)

    -- Aimbot тогглы
    addToggle(aimPage, "Aimbot Enabled", function() return Aimbot.Enabled end, function(v) Aimbot.Enabled = v end)
    addToggle(aimPage, "Team Check", function() return Aimbot.TeamCheck end, function(v) Aimbot.TeamCheck = v end)
    addToggle(aimPage, "Prioritize Murderer", function() return Aimbot.PrioritizeMurderer end, function(v) Aimbot.PrioritizeMurderer = v end)

    -- Дополнительные фишки (если в MM2)
    if IsMM2 then
        addToggle(aimPage, "Auto Pickup", function() return AutoPickup.Enabled end, function(v) AutoPickup.Enabled = v end)
        addToggle(aimPage, "God Mode", function() return GodMode.Enabled end, function(v) GodMode.Enabled = v end)
        addToggle(aimPage, "Fast Kill", function() return FastKill.Enabled end, function(v) FastKill.Enabled = v end)
    end

    -- Кнопка закрытия
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -20, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255,0,0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = panel
    closeBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)

    -- Управление видимостью
    icon.MouseButton1Click:Connect(function()
        panel.Visible = not panel.Visible
    end)
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            panel.Visible = not panel.Visible
        end
    end)
end

createGUI()
