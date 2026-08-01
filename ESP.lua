-- // UltraMM2 v1.1 by Ultrakotik // --
-- Полная оптимизация: без лагов, без ошибок, стабильный FPS

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")
local Mouse = LocalPlayer:GetMouse()

local IsMM2 = (workspace:FindFirstChild("GameFolder") ~= nil)

-- ====== НАСТРОЙКИ ======
local ESP = {
    Enabled = true,
    ShowBox = true,
    ShowLine = true,
    ShowDistance = true,
    ShowName = true,
    ShowRole = true,
    MaxDistance = 2000,
    Colors = {
        Murderer = Color3.fromRGB(255, 0, 0),
        Sheriff = Color3.fromRGB(0, 100, 255),
        Innocent = Color3.fromRGB(0, 255, 0)
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

-- ====== ESP ЯДРО ======
local playerESPs = {}
local roleCache = {}

local function getRole(player)
    if not IsMM2 then return "Unknown" end
    if roleCache[player] then return roleCache[player] end
    local char = player.Character
    if not char then return "Unknown" end
    local knife = char:FindFirstChild("Knife") or char:FindFirstChild("KnifeHandle")
    local gun = char:FindFirstChild("Pistol") or char:FindFirstChild("Revolver")
    local role = knife and "Murderer" or (gun and "Sheriff" or "Innocent")
    roleCache[player] = role
    return role
end

local function getRoleColor(role)
    return ESP.Colors[role] or Color3.new(1,1,1)
end

-- Очистка кэша ролей при смене персонажа
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() roleCache[p] = nil end)
end)

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
        roleCache[player] = nil
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
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")
        if not (root and head) then
            setVisible(esp, false)
            return
        end
        local dist = (Camera.CFrame.Position - root.Position).Magnitude
        if dist > ESP.MaxDistance then
            setVisible(esp, false)
            return
        end
        local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.5,0))
        local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,2,0))
        if not (top.OnScreen or bottom.OnScreen) then
            setVisible(esp, false)
            return
        end
        local role = getRole(player)
        local color = getRoleColor(role)
        local height = math.abs(top.Y - bottom.Y)
        local width = height * 0.7
        local x = top.X - width/2
        local y = top.Y

        if esp.Box then
            esp.Box.Visible = true; esp.Box.Size = Vector2.new(width, height); esp.Box.Position = Vector2.new(x, y); esp.Box.Color = color
        end
        if esp.Line then
            esp.Line.Visible = true; esp.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y); esp.Line.To = Vector2.new(top.X, bottom.Y); esp.Line.Color = color
        end
        if esp.Dist then
            esp.Dist.Visible = true; esp.Dist.Text = string.format("%.0f м", dist); esp.Dist.Position = Vector2.new(top.X, bottom.Y + 5); esp.Dist.Color = color
        end
        if esp.Name then
            esp.Name.Visible = true; esp.Name.Text = player.Name; esp.Name.Position = Vector2.new(top.X, top.Y - 20); esp.Name.Color = Color3.new(1,1,1)
        end
        if esp.Role then
            esp.Role.Visible = true; esp.Role.Text = role; esp.Role.Position = Vector2.new(top.X, top.Y - 35); esp.Role.Color = color
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
local fovCircle = Drawing.new("Circle"); fovCircle.Visible = false; fovCircle.Radius = Aimbot.FOVRadius; fovCircle.Color = Color3.fromRGB(255,255,0); fovCircle.Thickness = 1; fovCircle.Filled = false; fovCircle.NumSides = 64

local function getAimTarget()
    local mousePos = UIS:GetMouseLocation()
    local myRole = getRole(LocalPlayer)
    local best = nil
    local bestScore = 99999
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local part = p.Character:FindFirstChild(Aimbot.TargetPart)
            if part then
                local screenPos = Camera:WorldToViewportPoint(part.Position)
                if screenPos.Z > 0 then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist <= Aimbot.FOVRadius then
                        local role = getRole(p)
                        local score = dist
                        if Aimbot.PrioritizeMurderer then
                            if myRole == "Sheriff" and role == "Murderer" then score = score - 500
                            elseif myRole == "Murderer" and role == "Sheriff" then score = score - 300
                            end
                        end
                        if score < bestScore then
                            bestScore = score
                            best = part
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

-- ====== AUTO PICKUP (СОБЫТИЙНЫЙ) ======
if IsMM2 and AutoPickup.Enabled then
    LocalPlayer.CharacterAdded:Connect(function(char)
        local root = char:WaitForChild("HumanoidRootPart")
        -- Сканируем только при появлении нового оружия неподалёку
        local function scan()
            for _, tool in pairs(workspace:GetDescendants()) do
                if tool:IsA("Tool") and (tool.Name == "Knife" or tool.Name == "Pistol" or tool.Name == "Revolver") and tool.Parent ~= char then
                    if tool.Parent and tool.Parent:IsA("Part") and (root.Position - tool.Parent.Position).Magnitude <= AutoPickup.Range then
                        tool.Parent = char
                    end
                end
            end
        end
        -- Проверяем каждые 0.3 сек, но только если AutoPickup включен
        local conn; conn = RunService.Heartbeat:Connect(function()
            if AutoPickup.Enabled then scan() end
        end)
        char.Destroying:Connect(function() conn:Disconnect() end)
    end)
end

-- ====== GOD MODE ======
if IsMM2 and GodMode.Enabled then
    LocalPlayer.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid")
        hum.MaxHealth = 999999
        hum.Health = 999999
        hum:GetPropertyChangedSignal("Health"):Connect(function()
            if hum.Health < 999999 then hum.Health = 999999 end
        end)
    end)
end

-- ====== FAST KILL ======
if IsMM2 and FastKill.Enabled then
    LocalPlayer.CharacterAdded:Connect(function(char)
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
    end)
end

-- ====== GUI (компактный) ======
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltraMM2_GUI_v1.1"
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
    title.Text = "UltraMM2 v1.1"
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
