-- // UltraMM2 v2.1 by UltraAI for Ultrakotik // --
-- Мгновенное скрытие трупов, агрессивное определение ролей

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local IsMM2 = (workspace:FindFirstChild("GameFolder") ~= nil)

-- Настройки
local ESP = {
    Enabled = true,
    ShowBox = true,
    ShowLine = true,
    ShowDistance = true,
    ShowName = true,
    ShowRole = true,
    ShowDead = false,   -- если false, мёртвые игроки полностью исчезают с ESP
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

-- Кэш ролей (обновляется при возрождении)
local roleCache = {}

-- Рекурсивный поиск оружия в объекте
local function findWeaponTool(obj, weaponNames)
    for _, child in pairs(obj:GetChildren()) do
        if child:IsA("Tool") then
            for _, name in ipairs(weaponNames) do
                if child.Name == name then
                    return name
                end
            end
        end
        local result = findWeaponTool(child, weaponNames)
        if result then return result end
    end
    return nil
end

-- Определение роли по оружию (агрессивный поиск)
local function detectRoleByWeapons(player)
    local char = player.Character
    if not char then return nil end

    local weapon = findWeaponTool(char, {"Knife", "KnifeHandle", "Pistol", "Revolver"})
    if weapon == "Knife" or weapon == "KnifeHandle" then return "Murderer" end
    if weapon == "Pistol" or weapon == "Revolver" then return "Sheriff" end

    -- Если персонаж жив и оружия нет – невинный (но не форсируем, если роль не определена)
    local hum = char:FindFirstChild("Humanoid")
    if hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
        return nil  -- не форсируем Innocent, чтобы не перезаписать при временном отсутствии оружия
    end
    return nil
end

-- Сброс кэша при новом персонаже
local function onCharacterAdded(player)
    roleCache[player] = nil
    local char = player.Character
    if not char then return end

    -- Агрессивный поиск оружия в течение первых 3 секунд
    local attempts = 0
    local function tryDetect()
        if roleCache[player] then return end -- уже определили
        local role = detectRoleByWeapons(player)
        if role then
            roleCache[player] = role
            return
        end
        attempts += 1
        if attempts < 15 then  -- проверять каждые 0.5с около 7.5 секунд
            delay(0.5, tryDetect)
        else
            -- Если через 7.5 секунд оружие не появилось, а персонаж жив – ставим Innocent
            local charNow = player.Character
            if charNow then
                local hum = charNow:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                    roleCache[player] = "Innocent"
                end
            end
        end
    end
    tryDetect()

    -- Мгновенное скрытие при смерти
    local hum = char:WaitForChild("Humanoid")
    hum.Died:Connect(function()
        -- При смерти сразу помечаем как мёртвого, чтобы ESP скрылся
        roleCache[player] = "Dead"  -- переопределяем на Dead, чтобы гарантированно скрыть
    end)
end

-- Подписка на всех игроков
for _, p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function() onCharacterAdded(p) end)
    if p.Character then onCharacterAdded(p) end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() onCharacterAdded(p) end)
    if p.Character then onCharacterAdded(p) end
end)

-- Получение статуса (живой/мёртвый + роль)
local function getStatus(player)
    local char = player.Character
    if not char then return "Dead" end
    local hum = char:FindFirstChild("Humanoid")
    if hum then
        if hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then
            return "Dead"
        end
    end
    return roleCache[player] or "Unknown"
end

local function getRoleColor(role)
    return ESP.Colors[role] or Color3.new(1,1,1)
end

-- ESP хранилище
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

        local status = getStatus(player)
        -- Если игрок мёртв и показ мёртвых выключен – полностью скрываем всё
        if status == "Dead" and not ESP.ShowDead then
            setVisible(esp, false)
            return
        end

        local char = player.Character
        if not char then
            setVisible(esp, false)
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not (root and head) then
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
        local color = getRoleColor(status)

        local height = math.abs(top.Y - bottom.Y)
        local width = height * 0.7
        local x = top.X - width/2
        local y = top.Y

        if esp.Box then
            esp.Box.Visible = onScreen
            esp.Box.Size = Vector2.new(width, height)
            esp.Box.Position = Vector2.new(x, y)
            esp.Box.Color = color
        end
        if esp.Line then
            esp.Line.Visible = onScreen
            local vpSize = Camera.ViewportSize
            if vpSize then
                esp.Line.From = Vector2.new(vpSize.X/2, vpSize.Y)
            else
                esp.Line.From = Vector2.new(0,0)
            end
            esp.Line.To = Vector2.new(top.X, bottom.Y)
            esp.Line.Color = color
        end
        if esp.Dist then
            esp.Dist.Visible = onScreen
            esp.Dist.Text = string.format("%.0f м", dist)
            esp.Dist.Position = Vector2.new(top.X, bottom.Y + 5)
            esp.Dist.Color = color
        end
        if esp.Name then
            esp.Name.Visible = onScreen
            esp.Name.Text = player.Name
            esp.Name.Position = Vector2.new(top.X, top.Y - 20)
            esp.Name.Color = Color3.new(1,1,1)
        end
        if esp.Role then
            esp.Role.Visible = onScreen and ESP.ShowRole
            esp.Role.Text = status == "Dead" and "Dead" or (roleCache[player] or "Unknown")
            esp.Role.Position = Vector2.new(top.X, top.Y - 35)
            esp.Role.Color = color
        end
    end

    esp.Connection = RunService.RenderStepped:Connect(update)
    playerESPs[player] = esp
end

for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then createESP(p) end
end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then createESP(p) end end)
Players.PlayerRemoving:Connect(removeESP)

-- ====== AIMBOT ======
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false; fovCircle.Radius = Aimbot.FOVRadius; fovCircle.Color = Color3.fromRGB(255,255,0)
fovCircle.Thickness = 1; fovCircle.Filled = false; fovCircle.NumSides = 64

local function getAimTarget()
    local mousePos = UIS:GetMouseLocation()
    local myStatus = getStatus(LocalPlayer)
    local best, bestScore = nil, 99999
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetPart = p.Character:FindFirstChild(Aimbot.TargetPart)
            if targetPart then
                local screenPos = Camera:WorldToViewportPoint(targetPart.Position)
                if screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist <= Aimbot.FOVRadius then
                        local targetStatus = getStatus(p)
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

-- ====== AUTO PICKUP, GOD MODE, FAST KILL ======
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

-- ====== GUI (центральная кнопка, анимации) ======
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltraMM2_GUI_v2.1"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local icon = Instance.new("TextButton")
    icon.Size = UDim2.new(0, 40, 0, 40)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    icon.TextColor3 = Color3.new(1,1,1)
    icon.Text = "U"
    icon.Font = Enum.Font.SourceSansBold
    icon.TextSize = 20
    icon.BorderSizePixel = 0
    icon.AutoButtonColor = false
    icon.Active = true
    icon.Draggable = true
    icon.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = icon

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 240, 0, 300)
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.new(0.5, 0, 0.5, 0)
    panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    panel.BackgroundTransparency = 0.1
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui
    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 8)
    panelCorner.Parent = panel

    local shadow = Instance.new("ImageLabel")
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://6015897843"
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(10,10,10,10)
    shadow.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    title.Text = "UltraMM2 v2.1"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.BorderSizePixel = 0
    title.Parent = panel

    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(1, 0, 0, 26)
    tabFrame.Position = UDim2.new(0,0,0,30)
    tabFrame.BackgroundColor3 = Color3.fromRGB(30,30,30)
    tabFrame.BorderSizePixel = 0
    tabFrame.Parent = panel

    local function createTab(text, pos)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.5, -1, 1, 0)
        btn.Position = UDim2.new(pos, 0, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
        btn.Text = text
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 13
        btn.BorderSizePixel = 0
        btn.Parent = tabFrame
        return btn
    end

    local espTab = createTab("ESP", 0)
    local aimTab = createTab("Aimbot", 0.5)

    local espPage = Instance.new("Frame")
    espPage.Size = UDim2.new(1, -16, 0, 220)
    espPage.Position = UDim2.new(0,8,0,62)
    espPage.BackgroundColor3 = Color3.fromRGB(20,20,20)
    espPage.Visible = true
    espPage.Parent = panel

    local aimPage = Instance.new("Frame")
    aimPage.Size = UDim2.new(1, -16, 0, 220)
    aimPage.Position = UDim2.new(0,8,0,62)
    aimPage.BackgroundColor3 = Color3.fromRGB(20,20,20)
    aimPage.Visible = false
    aimPage.Parent = panel

    espTab.MouseButton1Click:Connect(function()
        espPage.Visible = true; aimPage.Visible = false
        espTab.BackgroundColor3 = Color3.fromRGB(60,60,60); aimTab.BackgroundColor3 = Color3.fromRGB(40,40,40)
    end)
    aimTab.MouseButton1Click:Connect(function()
        aimPage.Visible = true; espPage.Visible = false
        aimTab.BackgroundColor3 = Color3.fromRGB(60,60,60); espTab.BackgroundColor3 = Color3.fromRGB(40,40,40)
    end)

    local function addToggle(parent, name, get, set)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 24)
        btn.BackgroundColor3 = get() and Color3.fromRGB(0,160,0) or Color3.fromRGB(160,0,0)
        btn.Text = name .. ": " .. (get() and "ON" or "OFF")
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Position = UDim2.new(0,0,0, #parent:GetChildren() * 26)
        btn.Parent = parent
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            local new = not get()
            set(new)
            btn.BackgroundColor3 = new and Color3.fromRGB(0,160,0) or Color3.fromRGB(160,0,0)
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
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -24, 0, 3)
    closeBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1,1,1)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 14
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = panel
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function()
        panel.Visible = false
        icon.Visible = true
    end)

    local function togglePanel()
        if panel.Visible then
            panel.Visible = false
            icon.Visible = true
        else
            panel.Visible = true
            icon.Visible = false
            panel.Size = UDim2.new(0, 0, 0, 0)
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local goalSize = UDim2.new(0, 240, 0, 300)
            local tween = TweenService:Create(panel, tweenInfo, {Size = goalSize})
            tween:Play()
        end
    end

    icon.MouseButton1Click:Connect(togglePanel)

    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if panel.Visible then
                local mousePos = UIS:GetMouseLocation()
                local panelPos = panel.AbsolutePosition
                local panelSize = panel.AbsoluteSize
                if mousePos.X < panelPos.X or mousePos.X > panelPos.X + panelSize.X or
                   mousePos.Y < panelPos.Y or mousePos.Y > panelPos.Y + panelSize.Y then
                    togglePanel()
                end
            end
        end
        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            togglePanel()
        end
    end)
end

createGUI()

print("UltraMM2 v2.1 – трупы исчезают мгновенно, роли определяются чётко!")
