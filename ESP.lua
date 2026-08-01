-- // UltraMM2 v1.7 by UltraAI for Ultrakotik // --
-- Роли отображаются всегда, кэшируются и не исчезают

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local Mouse = LocalPlayer:GetMouse()

local IsMM2 = (workspace:FindFirstChild("GameFolder") ~= nil)

-- Настройки
local ESP = {
    Enabled = true,
    ShowBox = true,
    ShowLine = true,
    ShowDistance = true,
    ShowName = true,
    ShowRole = true,
    ShowDead = false,   -- если false, ESP-рамка скрывается, но роль остаётся
    MaxDistance = 2000,
    Colors = {
        Murderer = Color3.fromRGB(255, 0, 0),
        Sheriff = Color3.fromRGB(0, 100, 255),
        Innocent = Color3.fromRGB(0, 255, 0),
        Dead = Color3.fromRGB(128, 128, 128)
    }
}

local Aimbot = {
    Enabled = false,
    AimKey = Enum.UserInputType.MouseButton2,
    FOVRadius = 150,
    Smoothness = 0.3,
    TargetPart = "Head",
    PrioritizeMurderer = true
}

local AutoPickup = { Enabled = false, Range = 15 }
local GodMode = { Enabled = false }
local FastKill = { Enabled = false }

-- Кэш ролей (сохраняется навсегда, обновляется при возрождении)
local roleCache = {}

-- Глубокий поиск роли (как в v1.6)
local function deepFindRole(player)
    local function search(parent)
        for _, child in pairs(parent:GetChildren()) do
            if child:IsA("StringValue") and (child.Name == "Role" or child.Name:lower():match("role")) then
                return child.Value
            end
            local result = search(child)
            if result then return result end
        end
        return nil
    end

    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local role = search(gui)
        if role then return role end
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local role = search(backpack)
        if role then return role end
    end

    local char = player.Character
    if char then
        local role = search(char)
        if role then return role end
    end

    local gameFolder = workspace:FindFirstChild("GameFolder")
    if gameFolder then
        local role = search(gameFolder)
        if role then return role end
    end

    -- Запасной: оружие
    if char then
        local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeHandle")
        local gun = char:FindFirstChild("Pistol") or char:FindFirstChild("Revolver")
        if knife then return "Murderer"
        elseif gun then return "Sheriff"
        else return "Innocent" end
    end

    return nil
end

-- Нормализация названия роли
local function normalizeRole(rawRole)
    if not rawRole then return "Unknown" end
    local r = rawRole:lower()
    if r:match("murder") then return "Murderer"
    elseif r:match("sheriff") then return "Sheriff"
    elseif r:match("innocent") then return "Innocent"
    else return rawRole end
end

-- Получение роли с кэшированием
local function getCachedRole(player)
    if not IsMM2 then return "Unknown" end
    -- При возрождении персонажа сбрасываем кэш
    if player.Character then
        local hum = player.Character:FindFirstChild("Humanoid")
        if hum and hum.Health > 0 then
            -- Живой, можно попытаться найти роль
            local role = deepFindRole(player)
            if role then
                roleCache[player] = normalizeRole(role)
            elseif not roleCache[player] then
                roleCache[player] = "Unknown"
            end
        end
    end
    return roleCache[player] or "Unknown"
end

-- Проверка, мёртв ли игрок
local function isPlayerDead(player)
    local char = player.Character
    if not char then return true end
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum.Health <= 0 then return true end
    return false
end

local function getPlayerStatus(player)
    local dead = isPlayerDead(player)
    local role = getCachedRole(player)
    if dead then return "Dead" end
    return role
end

local function getRoleColor(role)
    return ESP.Colors[role] or Color3.new(1,1,1)
end

-- Сброс кэша при возрождении
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        roleCache[p] = nil -- заставит переопределить роль
    end)
end)

-- Хранилище ESP
local playerESPs = {}

local function setVisible(esp, state)
    for _, obj in pairs(esp) do
        if type(obj) == "table" and obj.Visible ~= nil then
            obj.Visible = state
        end
    end
end

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

local function createESP(player)
    local esp = {}
    if ESP.ShowBox then
        esp.Box = Drawing.new("Square"); esp.Box.Visible = false; esp.Box.Thickness = 2; esp.Box.Filled = false
    end
    if ESP.ShowLine then
        esp.Line = Drawing.new("Line"); esp.Line.Visible = false; esp.Line.Thickness = 1
    end
    if ESP.ShowDistance then
        esp.Dist = Drawing.new("Text"); esp.Dist.Visible = false; esp.Dist.Size = 14; esp.Dist.Center = true; esp.Dist.Outline = true
    end
    if ESP.ShowName then
        esp.Name = Drawing.new("Text"); esp.Name.Visible = false; esp.Name.Size = 14; esp.Name.Center = true; esp.Name.Outline = true
    end
    if ESP.ShowRole then
        esp.Role = Drawing.new("Text"); esp.Role.Visible = false; esp.Role.Size = 14; esp.Role.Center = true; esp.Role.Outline = true
    end

    local function update()
        if not ESP.Enabled then
            setVisible(esp, false)
            return
        end

        local status = getPlayerStatus(player)
        local roleText = getCachedRole(player) -- всегда берём кэшированную роль для отображения

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not (root and head) then
            -- Если персонажа нет, но роль есть, мы всё равно можем показать текст роли? 
            -- Для простоты скроем всё, т.к. нет координат.
            setVisible(esp, false)
            return
        end

        local dist = (Camera.CFrame.Position - root.Position).Magnitude
        if dist > ESP.MaxDistance then
            setVisible(esp, false)
            return
        end

        local top, onScreen1 = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        local bottom, onScreen2 = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,2,0))

        local onScreen = (onScreen1 or onScreen2)

        -- Определяем, нужно ли показывать рамку/линию/расстояние
        local showFullESP = true
        if status == "Dead" and not ESP.ShowDead then
            showFullESP = false
        end

        -- Цвет для роли: если мёртв и ShowDead выключен, всё равно покажем роль серым
        local roleColor = getRoleColor(roleText) -- кэшированная роль, не статус
        if status == "Dead" and not ESP.ShowDead then
            -- рамку не показываем, но роль видна
            roleColor = ESP.Colors.Dead
        end

        local height = math.abs(top.Y - bottom.Y)
        local width = height * 0.7
        local x = top.X - width/2
        local y = top.Y

        -- Бокс
        if esp.Box then
            esp.Box.Visible = onScreen and showFullESP
            esp.Box.Size = Vector2.new(width, height)
            esp.Box.Position = Vector2.new(x, y)
            esp.Box.Color = roleColor
        end
        -- Линия
        if esp.Line then
            esp.Line.Visible = onScreen and showFullESP
            local vpSize = Camera.ViewportSize
            if vpSize then
                esp.Line.From = Vector2.new(vpSize.X/2, vpSize.Y)
            else
                esp.Line.From = Vector2.new(0,0)
            end
            esp.Line.To = Vector2.new(top.X, bottom.Y)
            esp.Line.Color = roleColor
        end
        -- Расстояние
        if esp.Dist then
            esp.Dist.Visible = onScreen and showFullESP
            esp.Dist.Text = string.format("%.0f м", dist)
            esp.Dist.Position = Vector2.new(top.X, bottom.Y + 5)
            esp.Dist.Color = roleColor
        end
        -- Имя
        if esp.Name then
            esp.Name.Visible = onScreen
            esp.Name.Text = player.Name
            esp.Name.Position = Vector2.new(top.X, top.Y - 20)
            esp.Name.Color = Color3.new(1,1,1)
        end
        -- Роль (всегда показываем, если ShowRole включена, даже если рамка скрыта)
        if esp.Role then
            esp.Role.Visible = onScreen and ESP.ShowRole
            esp.Role.Text = roleText -- кэшированная роль
            esp.Role.Position = Vector2.new(top.X, top.Y - 35)
            esp.Role.Color = roleColor
        end
    end

    esp.Connection = RunService.RenderStepped:Connect(update)
    playerESPs[player] = esp
end

-- Инициализация
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createESP(p) end
end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then createESP(p) end end)
Players.PlayerRemoving:Connect(removeESP)

-- ====== AIMBOT (без изменений) ======
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Radius = Aimbot.FOVRadius
fovCircle.Color = Color3.fromRGB(255,255,0)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.NumSides = 64

local function getAimTarget()
    local mousePos = UIS:GetMouseLocation()
    local myStatus = getPlayerStatus(LocalPlayer)
    local best, bestScore = nil, 99999
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetPart = p.Character:FindFirstChild(Aimbot.TargetPart)
            if targetPart then
                local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
                if screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist <= Aimbot.FOVRadius then
                        local targetStatus = getPlayerStatus(p)
                        if targetStatus == "Dead" then continue end
                        local score = dist
                        if Aimbot.PrioritizeMurderer then
                            if myStatus == "Sheriff" and targetStatus == "Murderer" then score = score - 500
                            elseif myStatus == "Murderer" and targetStatus == "Sheriff" then score = score - 300
                            end
                        end
                        if score < bestScore then
                            bestScore = score
                            best = targetPart
                        end
                    end
                end
            end
        end
    end
    return best
end

RunService.RenderStepped:Connect(function()
    fovCircle.Position = UIS:GetMouseLocation()
    fovCircle.Visible = Aimbot.Enabled
    if Aimbot.Enabled and UIS:IsMouseButtonPressed(Aimbot.AimKey) then
        local target = getAimTarget()
        if target then
            local targetPos = target.Position
            local newCF = CFrame.new(Camera.CFrame.Position, targetPos)
            if Aimbot.Smoothness > 0 then
                Camera.CFrame = Camera.CFrame:Lerp(newCF, 1 - Aimbot.Smoothness)
            else
                Camera.CFrame = newCF
            end
        end
    end
end)

-- ====== AUTO PICKUP, GOD MODE, FAST KILL (без изменений) ======
if IsMM2 then
    LocalPlayer.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart")
        local function scan()
            if not AutoPickup.Enabled then return end
            for _, tool in pairs(workspace:GetDescendants()) do
                if tool:IsA("Tool") and (tool.Name == "Knife" or tool.Name == "Pistol" or tool.Name == "Revolver") and tool.Parent ~= char then
                    if tool.Parent and tool.Parent:IsA("BasePart") and (root.Position - tool.Parent.Position).Magnitude <= AutoPickup.Range then
                        tool.Parent = char
                    end
                end
            end
        end
        local conn; conn = RunService.Heartbeat:Connect(scan)
        char.Destroying:Connect(function() if conn then conn:Disconnect() end end)
    end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        if GodMode.Enabled then
            hum.MaxHealth = 999999
            hum.Health = 999999
        end
        hum:GetPropertyChangedSignal("Health"):Connect(function()
            if GodMode.Enabled and hum.Health < 999999 then hum.Health = 999999 end
        end)
    end)

    LocalPlayer.CharacterAdded:Connect(function(char)
        if FastKill.Enabled then
            local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeHandle")
            if knife then
                knife.Touched:Connect(function(part)
                    local targetChar = part.Parent
                    if targetChar and targetChar:IsA("Model") then
                        local hum = targetChar:FindFirstChild("Humanoid")
                        if hum and hum.Health > 0 then hum.Health = 0 end
                    end
                end)
            end
        end
    end)
end

-- ====== GUI (упрощённый) ======
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltraMM2_GUI_v1.7"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

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

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 220, 0, 260)
    panel.Position = UDim2.new(0, 50, 0, 10)
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    title.Text = "UltraMM2 v1.7"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.SourceSansBold; title.TextSize = 14
    title.Parent = panel

    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 0, 22)
    tabFrame.Position = UDim2.new(0,0,0,22)
    tabFrame.BackgroundColor3 = Color3.fromRGB(50,50,50)
    tabFrame.Parent = panel

    local function createTab(text, pos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.5, -1, 1, 0)
        btn.Position = UDim2.new(pos, 0, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        btn.Text = text; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.SourceSans; btn.TextSize = 13; btn.BorderSizePixel = 0
        btn.Parent = tabFrame
        return btn
    end

    local espTab = createTab("ESP", 0)
    local aimTab = createTab("Aimbot", 0.5)

    local espPage = Instance.new("Frame")
    espPage.Size = UDim2.new(1, -10, 0, 200)
    espPage.Position = UDim2.new(0,5,0,47)
    espPage.BackgroundColor3 = Color3.fromRGB(30,30,30)
    espPage.Visible = true; espPage.Parent = panel

    local aimPage = Instance.new("Frame")
    aimPage.Size = UDim2.new(1, -10, 0, 200)
    aimPage.Position = UDim2.new(0,5,0,47)
    aimPage.BackgroundColor3 = Color3.fromRGB(30,30,30)
    aimPage.Visible = false; aimPage.Parent = panel

    espTab.MouseButton1Click:Connect(function()
        espPage.Visible = true; aimPage.Visible = false
        espTab.BackgroundColor3 = Color3.fromRGB(80,80,80); aimTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end)
    aimTab.MouseButton1Click:Connect(function()
        aimPage.Visible = true; espPage.Visible = false
        aimTab.BackgroundColor3 = Color3.fromRGB(80,80,80); espTab.BackgroundColor3 = Color3.fromRGB(50,50,50)
    end)

    local function addToggle(parent, name, get, set)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 22)
        btn.BackgroundColor3 = get() and Color3.fromRGB(0,170,0) or Color3.fromRGB(170,0,0)
        btn.Text = name .. ": " .. (get() and "ON" or "OFF")
        btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.SourceSans; btn.TextSize = 12; btn.BorderSizePixel = 0
        btn.Position = UDim2.new(0,0,0, #parent:GetChildren() * 24)
        btn.Parent = parent
        btn.MouseButton1Click:Connect(function()
            local new = not get()
            set(new)
            btn.BackgroundColor3 = new and Color3.fromRGB(0,170,0) or Color3.fromRGB(170,0,0)
            btn.Text = name .. ": " .. (new and "ON" or "OFF")
        end)
    end

    addToggle(espPage, "ESP Enabled", function() return ESP.Enabled end, function(v) ESP.Enabled = v end)
    addToggle(espPage, "Show Box", function() return ESP.ShowBox end, function(v) ESP.ShowBox = v end)
    addToggle(espPage, "Show Line", function() return ESP.ShowLine end, function(v) ESP.ShowLine = v end)
    addToggle(espPage, "Show Dist", function() return ESP.ShowDistance end, function(v) ESP.ShowDistance = v end)
    addToggle(espPage, "Show Name", function() return ESP.ShowName end, function(v) ESP.ShowName = v end)
    addToggle(espPage, "Show Role", function() return ESP.ShowRole end, function(v) ESP.ShowRole = v end)
    addToggle(espPage, "Show Dead", function() return ESP.ShowDead end, function(v) ESP.ShowDead = v end)

    addToggle(aimPage, "Aimbot", function() return Aimbot.Enabled end, function(v) Aimbot.Enabled = v end)
    addToggle(aimPage, "Prioritize Murder", function() return Aimbot.PrioritizeMurderer end, function(v) Aimbot.PrioritizeMurderer = v end)
    if IsMM2 then
        addToggle(aimPage, "Auto Pickup", function() return AutoPickup.Enabled end, function(v) AutoPickup.Enabled = v end)
        addToggle(aimPage, "God Mode", function() return GodMode.Enabled end, function(v) GodMode.Enabled = v end)
        addToggle(aimPage, "Fast Kill", function() return FastKill.Enabled end, function(v) FastKill.Enabled = v end)
    end

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20); closeBtn.Position = UDim2.new(1, -20, 0, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255,0,0); closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.SourceSansBold; closeBtn.TextSize = 14; closeBtn.BorderSizePixel = 0
    closeBtn.Parent = panel
    closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

    icon.MouseButton1Click:Connect(function() panel.Visible = not panel.Visible end)
    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            panel.Visible = not panel.Visible
        end
    end)
end

createGUI()

print("UltraMM2 v1.7 — роли теперь отображаются постоянно!")
