-- // UltraESP v3.0 by Ultrakotik // --

local SETTINGS = {
    TeamCheck = false,
    ShowBox = true,
    BoxColor = Color3.fromRGB(255, 0, 0),
    BoxThickness = 2,
    ShowLine = true,
    LineColor = Color3.fromRGB(255, 255, 255),
    LineThickness = 1,
    ShowDistance = true,
    DistanceColor = Color3.fromRGB(255, 255, 255),
    DistanceSize = 14,
    ShowName = true,
    NameColor = Color3.fromRGB(255, 255, 255),
    NameSize = 14,
    MaxDistance = 2000
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local ESP_Enabled = true
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
    if SETTINGS.ShowBox then
        esp.Box = Drawing.new("Square")
        esp.Box.Visible = false
        esp.Box.Thickness = SETTINGS.BoxThickness
        esp.Box.Color = SETTINGS.BoxColor
        esp.Box.Filled = false
    end
    if SETTINGS.ShowLine then
        esp.Line = Drawing.new("Line")
        esp.Line.Visible = false
        esp.Line.Color = SETTINGS.LineColor
        esp.Line.Thickness = SETTINGS.LineThickness
    end
    if SETTINGS.ShowDistance then
        esp.DistanceText = Drawing.new("Text")
        esp.DistanceText.Visible = false
        esp.DistanceText.Color = SETTINGS.DistanceColor
        esp.DistanceText.Size = SETTINGS.DistanceSize
        esp.DistanceText.Center = true
        esp.DistanceText.Outline = true
    end
    if SETTINGS.ShowName then
        esp.NameText = Drawing.new("Text")
        esp.NameText.Visible = false
        esp.NameText.Color = SETTINGS.NameColor
        esp.NameText.Size = SETTINGS.NameSize
        esp.NameText.Center = true
        esp.NameText.Outline = true
    end

    local function update()
        if not ESP_Enabled then
            setVisible(esp, false)
            return
        end
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local head = character and character:FindFirstChild("Head")
        if SETTINGS.TeamCheck and player.Team == LocalPlayer.Team then
            setVisible(esp, false)
            return
        end
        if rootPart and head then
            local distance = (Camera.CFrame.Position - rootPart.Position).Magnitude
            if distance > SETTINGS.MaxDistance then
                setVisible(esp, false)
                return
            end
            local top = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
            local bottom = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 2, 0))
            if top.OnScreen or bottom.OnScreen then
                local height = math.abs(top.Y - bottom.Y)
                local width = height * 0.7
                local x = top.X - width/2
                local y = top.Y
                if esp.Box then
                    esp.Box.Visible = true
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(x, y)
                end
                if esp.Line then
                    esp.Line.Visible = true
                    esp.Line.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    esp.Line.To = Vector2.new(top.X, bottom.Y)
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
            else
                setVisible(esp, false)
            end
        else
            setVisible(esp, false)
        end
    end

    esp.Connection = RunService.RenderStepped:Connect(update)
    playerESPs[player] = esp
end

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then createESP(player) end
end
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then createESP(player) end
end)
Players.PlayerRemoving:Connect(removeESP)

-- ========== НОВЫЙ GUI: КРАСНЫЙ КВАДРАТ + СВОРАЧИВАЕМАЯ ПАНЕЛЬ ==========
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "UltraESP_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- Красный квадрат-иконка (всегда на экране)
    local icon = Instance.new("TextButton")
    icon.Size = UDim2.new(0, 32, 0, 32)
    icon.Position = UDim2.new(0, 10, 0, 10)
    icon.BackgroundColor3 = Color3.fromRGB(255, 0, 0) -- чисто красный
    icon.Text = ""
    icon.BorderSizePixel = 0
    icon.AutoButtonColor = false
    icon.Active = true
    icon.Draggable = true
    icon.Parent = screenGui

    -- Панель управления (изначально скрыта)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 180, 0, 80)
    panel.Position = UDim2.new(0, 50, 0, 10) -- рядом с иконкой
    panel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.Active = true
    panel.Draggable = true
    panel.Parent = screenGui

    -- Кнопка ESP ON/OFF внутри панели
    local espButton = Instance.new("TextButton")
    espButton.Size = UDim2.new(0, 140, 0, 30)
    espButton.Position = UDim2.new(0, 20, 0, 10)
    espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    espButton.TextColor3 = Color3.new(1, 1, 1)
    espButton.TextSize = 16
    espButton.Text = "ESP: ON"
    espButton.Font = Enum.Font.SourceSansBold
    espButton.BorderSizePixel = 0
    espButton.Parent = panel

    -- Кнопка закрытия панели (крестик)
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 24, 0, 24)
    closeButton.Position = UDim2.new(0, 146, 0, 4)
    closeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.TextSize = 14
    closeButton.Text = "✕"
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = panel

    -- Функция переключения видимости панели
    local function togglePanel()
        panel.Visible = not panel.Visible
    end

    -- Открытие/закрытие по клику на красный квадрат
    icon.MouseButton1Click:Connect(togglePanel)

    -- Закрытие по кнопке "✕"
    closeButton.MouseButton1Click:Connect(function()
        panel.Visible = false
    end)

    -- Обработчик клавиш: Ctrl (LeftControl или RightControl) для переключения
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end -- не перехватываем ввод в текстовые поля
        if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
            togglePanel()
        end
    end)

    -- Логика кнопки ESP ON/OFF
    espButton.MouseButton1Click:Connect(function()
        ESP_Enabled = not ESP_Enabled
        if ESP_Enabled then
            espButton.Text = "ESP: ON"
            espButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        else
            espButton.Text = "ESP: OFF"
            espButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            -- Скрываем все ESP немедленно
            for _, esp in pairs(playerESPs) do
                setVisible(esp, false)
            end
        end
    end)
end

createGUI()
