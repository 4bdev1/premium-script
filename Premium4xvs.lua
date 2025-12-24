-- ============================================================
-- 4xvs - INTERFACE AVEC CATÉGORIES
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIGURATION
-- ============================================================
local CONFIG = {
    WAYPOINTS = {
        {name = "Point A", pos = Vector3.new(-351.76, -6.66, 20.29)},
        {name = "Point B", pos = Vector3.new(-332.14, -4.51, 18.41)},
    },
    DELAY = 0.15,
    COOLDOWN = 0.5,
    THEME = {
        Background = Color3.fromRGB(0, 0, 0),
        Text = Color3.fromRGB(255, 255, 255),
        TextDim = Color3.fromRGB(150, 150, 150),
        Accent = Color3.fromRGB(255, 200, 0),
        Success = Color3.fromRGB(0, 255, 150),
        Error = Color3.fromRGB(255, 80, 100),
    }
}

-- ============================================================
-- ÉTAT
-- ============================================================
local State = {
    isTeleporting = false,
    lastTeleportTime = 0,
    totalTeleports = 0,
    guiVisible = true,
    wallhackEnabled = false,
    wallhackParts = {},
    wallhackConnection = nil,
    espEnabled = false,
    espBoxes = {},
    espConnections = {},
    optimizerEnabled = false,
    currentCategory = "Misc",
}

-- ============================================================
-- FONCTIONS UTILITAIRES
-- ============================================================
local function getHRP()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChild("Humanoid")
    if hrp and humanoid and humanoid.Health > 0 then
        return hrp
    end
    return nil
end

local function canTeleport()
    if State.isTeleporting then
        return false, "En cours..."
    end
    if tick() - State.lastTeleportTime < CONFIG.COOLDOWN then
        return false, "Cooldown..."
    end
    if not getHRP() then
        return false, "Erreur..."
    end
    return true, "Prêt"
end

local function tween(object, properties, duration)
    local info = TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local tw = TweenService:Create(object, info, properties)
    tw:Play()
    return tw
end

-- ============================================================
-- TÉLÉPORTATION
-- ============================================================
local function teleportSequence()
    local canTP, message = canTeleport()
    if not canTP then
        return false, message
    end
    
    State.isTeleporting = true
    State.lastTeleportTime = tick()
    
    local success, err = pcall(function()
        for i, waypoint in ipairs(CONFIG.WAYPOINTS) do
            local hrp = getHRP()
            if not hrp then error("Personnage perdu") end
            hrp.CFrame = CFrame.new(waypoint.pos)
            if i < #CONFIG.WAYPOINTS then
                task.wait(CONFIG.DELAY)
            end
        end
    end)
    
    State.isTeleporting = false
    
    if success then
        State.totalTeleports += 1
        return true, "Succès!"
    else
        return false, "Échec"
    end
end

-- ============================================================
-- OPTIMIZER
-- ============================================================
local function toggleOptimizer(enabled)
    if enabled then
        settings().Rendering.QualityLevel = 1
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end
        return true, "Optimizer activé"
    else
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
        return true, "Optimizer désactivé"
    end
end

-- ============================================================
-- WALLHACK
-- ============================================================
local function clearWallhack()
    for part, data in pairs(State.wallhackParts) do
        if part and part.Parent then
            part.LocalTransparencyModifier = data.OriginalTransparency or 0
        end
    end
    State.wallhackParts = {}
    
    if State.wallhackConnection then
        State.wallhackConnection:Disconnect()
        State.wallhackConnection = nil
    end
end

local function toggleWallhack(enabled)
    State.wallhackEnabled = enabled
    
    if enabled then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name ~= "Terrain" then
                local isPlayerPart = false
                if LocalPlayer.Character then
                    isPlayerPart = obj:IsDescendantOf(LocalPlayer.Character)
                end
                
                if not isPlayerPart then
                    State.wallhackParts[obj] = {
                        OriginalTransparency = obj.LocalTransparencyModifier
                    }
                    obj.LocalTransparencyModifier = 0.8
                end
            end
        end
        
        State.wallhackConnection = workspace.DescendantAdded:Connect(function(obj)
            if State.wallhackEnabled and obj:IsA("BasePart") then
                task.wait(0.1)
                if State.wallhackEnabled then
                    local isPlayerPart = LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character)
                    if not isPlayerPart then
                        obj.LocalTransparencyModifier = 0.8
                        State.wallhackParts[obj] = {OriginalTransparency = 0}
                    end
                end
            end
        end)
    else
        clearWallhack()
    end
end

-- ============================================================
-- ESP
-- ============================================================
local function clearESP()
    for _, data in pairs(State.espBoxes) do
        if data.Box then data.Box:Destroy() end
        if data.NameLabel then data.NameLabel:Destroy() end
    end
    State.espBoxes = {}
    
    for _, connection in pairs(State.espConnections) do
        if connection then connection:Disconnect() end
    end
    State.espConnections = {}
end

local function createRainbowESP(player)
    if player == LocalPlayer or not player.Character then return end
    
    local char = player.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end
    
    local box = Instance.new("BoxHandleAdornment")
    box.Name = "ESP_" .. player.Name
    box.Adornee = hrp
    box.Size = Vector3.new(4, 5, 1)
    box.Color3 = Color3.fromRGB(255, 0, 0)
    box.Transparency = 0.3
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Parent = hrp
    
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESP_Name_" .. player.Name
    billboardGui.Adornee = head
    billboardGui.Size = UDim2.new(0, 200, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = head
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 1, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 18
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Parent = billboardGui
    
    State.espBoxes[player.UserId] = {
        Box = box,
        NameLabel = billboardGui,
    }
    
    local humanoid = char:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            if State.espBoxes[player.UserId] then
                if State.espBoxes[player.UserId].Box then State.espBoxes[player.UserId].Box:Destroy() end
                if State.espBoxes[player.UserId].NameLabel then State.espBoxes[player.UserId].NameLabel:Destroy() end
                State.espBoxes[player.UserId] = nil
            end
        end)
    end
end

local function toggleESP(enabled)
    State.espEnabled = enabled
    
    if enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                createRainbowESP(player)
            end
        end
        
        table.insert(State.espConnections, Players.PlayerAdded:Connect(function(player)
            if State.espEnabled then
                player.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if State.espEnabled then createRainbowESP(player) end
                end)
            end
        end))
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(State.espConnections, player.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if State.espEnabled then createRainbowESP(player) end
                end))
            end
        end
    else
        clearESP()
    end
end

-- ============================================================
-- INTERFACE AVEC CATÉGORIES
-- ============================================================
local function createCategorizedGUI()
    local existing = PlayerGui:FindFirstChild("MinimalTP_GUI")
    if existing then existing:Destroy() end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "MinimalTP_GUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui
    
    -- BOUTON RÉOUVERTURE (Modifié: fond noir + bordure bleue + texte blanc)
    local reopenBtn = Instance.new("TextButton")
    reopenBtn.Name = "ReopenButton"
    reopenBtn.Size = UDim2.new(0, 50, 0, 50)
    reopenBtn.Position = UDim2.new(1, -60, 0, 10)
    reopenBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    reopenBtn.Text = "4x"
    reopenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    reopenBtn.Font = Enum.Font.GothamBold
    reopenBtn.TextSize = 22
    reopenBtn.Visible = false
    reopenBtn.Parent = gui
    
    local reopenCorner = Instance.new("UICorner", reopenBtn)
    reopenCorner.CornerRadius = UDim.new(0, 8)
    
    local reopenStroke = Instance.new("UIStroke", reopenBtn)
    reopenStroke.Color = Color3.fromRGB(0, 80, 180)
    reopenStroke.Thickness = 3
    
    -- DRAG SYSTEM POUR LE BOUTON RÉOUVERTURE
    local reopenDragging, reopenDragInput, reopenDragStart, reopenStartPos
    
    reopenBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            reopenDragging = true
            reopenDragStart = input.Position
            reopenStartPos = reopenBtn.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    reopenDragging = false
                end
            end)
        end
    end)
    
    reopenBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            reopenDragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == reopenDragInput and reopenDragging then
            local delta = input.Position - reopenDragStart
            reopenBtn.Position = UDim2.new(
                reopenStartPos.X.Scale,
                reopenStartPos.X.Offset + delta.X,
                reopenStartPos.Y.Scale,
                reopenStartPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- CONTAINER PRINCIPAL
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 380, 0, 520)
    mainFrame.Position = UDim2.new(0.5, -190, 0.5, -260)
    mainFrame.BackgroundColor3 = CONFIG.THEME.Background
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Parent = gui
    
    local mainCorner = Instance.new("UICorner", mainFrame)
    mainCorner.CornerRadius = UDim.new(0, 12)
    
    local mainStroke = Instance.new("UIStroke", mainFrame)
    mainStroke.Color = Color3.fromRGB(0, 80, 180)
    mainStroke.Thickness = 2
    
    -- HEADER
    local header = Instance.new("Frame", mainFrame)
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 60)
    header.BackgroundColor3 = CONFIG.THEME.Background
    header.BorderSizePixel = 0
    
    local headerStroke = Instance.new("UIStroke", header)
    headerStroke.Color = Color3.fromRGB(0, 80, 180)
    headerStroke.Thickness = 2
    headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    local logo = Instance.new("TextLabel", header)
    logo.Size = UDim2.new(1, -60, 1, 0)
    logo.Position = UDim2.new(0, 20, 0, 0)
    logo.BackgroundTransparency = 1
    logo.Text = "4xvs"
    logo.TextColor3 = CONFIG.THEME.Text
    logo.Font = Enum.Font.GothamBold
    logo.TextSize = 32
    logo.TextXAlignment = Enum.TextXAlignment.Left
    
    local closeBtn = Instance.new("TextButton", header)
    closeBtn.Size = UDim2.new(0, 35, 0, 35)
    closeBtn.Position = UDim2.new(1, -45, 0, 12)
    closeBtn.BackgroundColor3 = CONFIG.THEME.TextDim
    closeBtn.BackgroundTransparency = 0.8
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = CONFIG.THEME.Text
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 18
    closeBtn.AutoButtonColor = false
    
    local closeBtnCorner = Instance.new("UICorner", closeBtn)
    closeBtnCorner.CornerRadius = UDim.new(1, 0)
    
    closeBtn.MouseButton1Click:Connect(function()
        State.guiVisible = false
        mainFrame.Visible = false
        reopenBtn.Visible = true
    end)
    
    reopenBtn.MouseButton1Click:Connect(function()
        State.guiVisible = true
        mainFrame.Visible = true
        reopenBtn.Visible = false
    end)
    
    -- TABS CONTAINER
    local tabsContainer = Instance.new("Frame", mainFrame)
    tabsContainer.Name = "TabsContainer"
    tabsContainer.Size = UDim2.new(1, -20, 0, 50)
    tabsContainer.Position = UDim2.new(0, 10, 0, 70)
    tabsContainer.BackgroundTransparency = 1
    
    local tabsLayout = Instance.new("UIListLayout", tabsContainer)
    tabsLayout.FillDirection = Enum.FillDirection.Horizontal
    tabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    tabsLayout.Padding = UDim.new(0, 8)
    
    -- CONTENT CONTAINER
    local contentFrame = Instance.new("Frame", mainFrame)
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -30, 1, -180)
    contentFrame.Position = UDim2.new(0, 15, 0, 130)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ClipsDescendants = true
    
    -- FOOTER (by 8v & 4b)
    local footer = Instance.new("TextLabel", mainFrame)
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, 0, 0, 30)
    footer.Position = UDim2.new(0, 0, 1, -35)
    footer.BackgroundTransparency = 1
    footer.Text = "by 8v & 4b"
    footer.TextColor3 = CONFIG.THEME.TextDim
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 12
    footer.TextXAlignment = Enum.TextXAlignment.Center
    
    -- FONCTION POUR CRÉER UN TAB
    local tabs = {}
    local function createTab(name)
        local tabBtn = Instance.new("TextButton", tabsContainer)
        tabBtn.Name = name .. "Tab"
        tabBtn.Size = UDim2.new(0, 80, 1, 0)
        tabBtn.BackgroundColor3 = CONFIG.THEME.TextDim
        tabBtn.BackgroundTransparency = 0.9
        tabBtn.Text = name
        tabBtn.TextColor3 = CONFIG.THEME.TextDim
        tabBtn.Font = Enum.Font.GothamBold
        tabBtn.TextSize = 14
        tabBtn.AutoButtonColor = false
        
        local tabCorner = Instance.new("UICorner", tabBtn)
        tabCorner.CornerRadius = UDim.new(0, 8)
        
        local contentContainer = Instance.new("Frame", contentFrame)
        contentContainer.Name = name .. "Content"
        contentContainer.Size = UDim2.new(1, 0, 1, 0)
        contentContainer.BackgroundTransparency = 1
        contentContainer.Visible = false
        
        local contentLayout = Instance.new("UIListLayout", contentContainer)
        contentLayout.FillDirection = Enum.FillDirection.Vertical
        contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        contentLayout.Padding = UDim.new(0, 10)
        
        tabs[name] = {
            Button = tabBtn,
            Content = contentContainer
        }
        
        tabBtn.MouseButton1Click:Connect(function()
            for tabName, tabData in pairs(tabs) do
                tabData.Content.Visible = false
                tabData.Button.BackgroundTransparency = 0.9
                tabData.Button.TextColor3 = CONFIG.THEME.TextDim
            end
            
            contentContainer.Visible = true
            tabBtn.BackgroundTransparency = 0.5
            tabBtn.TextColor3 = CONFIG.THEME.Accent
            State.currentCategory = name
        end)
        
        return contentContainer
    end
    
    -- CRÉER LES TABS
    local miscContent = createTab("Misc")
    local espContent = createTab("ESP")
    local keyContent = createTab("Key")
    local infoContent = createTab("Info")
    
    -- ACTIVER MISC PAR DÉFAUT
    tabs["Misc"].Content.Visible = true
    tabs["Misc"].Button.BackgroundTransparency = 0.5
    tabs["Misc"].Button.TextColor3 = CONFIG.THEME.Accent
    
    -- FONCTION POUR CRÉER UN BOUTON
    local function createButton(parent, name, callback)
        local btn = Instance.new("TextButton", parent)
        btn.Name = name .. "Btn"
        btn.Size = UDim2.new(1, 0, 0, 50)
        btn.BackgroundColor3 = CONFIG.THEME.TextDim
        btn.BackgroundTransparency = 0.9
        btn.Text = name
        btn.TextColor3 = CONFIG.THEME.Text
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 15
        btn.AutoButtonColor = false
        
        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 8)
        
        local btnStroke = Instance.new("UIStroke", btn)
        btnStroke.Color = CONFIG.THEME.TextDim
        btnStroke.Thickness = 1
        
        local statusIcon = Instance.new("TextLabel", btn)
        statusIcon.Name = "StatusIcon"
        statusIcon.Size = UDim2.new(0, 30, 0, 30)
        statusIcon.Position = UDim2.new(1, -40, 0.5, -15)
        statusIcon.BackgroundTransparency = 1
        statusIcon.Text = "○"
        statusIcon.TextColor3 = CONFIG.THEME.TextDim
        statusIcon.Font = Enum.Font.GothamBold
        statusIcon.TextSize = 18
        
        btn.MouseEnter:Connect(function()
            tween(btn, {BackgroundTransparency = 0.7}, 0.2)
        end)
        
        btn.MouseLeave:Connect(function()
            tween(btn, {BackgroundTransparency = 0.9}, 0.2)
        end)
        
        if callback then
            btn.MouseButton1Click:Connect(function()
                callback(btn, statusIcon)
            end)
        end
        
        return btn, statusIcon
    end
    
    -- FONCTION POUR CRÉER UN LABEL
    local function createLabel(parent, text, color)
        local label = Instance.new("TextLabel", parent)
        label.Size = UDim2.new(1, 0, 0, 30)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color or CONFIG.THEME.Text
        label.Font = Enum.Font.Gotham
        label.TextSize = 14
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextWrapped = true
        return label
    end
    
    -- MISC TAB
    createButton(miscContent, "Téléporter", function(btn, icon)
        local success, msg = teleportSequence()
        if success then
            icon.Text = "✓"
            icon.TextColor3 = CONFIG.THEME.Success
            task.wait(1)
            icon.Text = "○"
            icon.TextColor3 = CONFIG.THEME.TextDim
        end
    end)
    
    createButton(miscContent, "Optimizer", function(btn, icon)
        State.optimizerEnabled = not State.optimizerEnabled
        local success, msg = toggleOptimizer(State.optimizerEnabled)
        
        if State.optimizerEnabled then
            icon.Text = "●"
            icon.TextColor3 = CONFIG.THEME.Accent
        else
            icon.Text = "○"
            icon.TextColor3 = CONFIG.THEME.TextDim
        end
    end)
    
    -- ESP TAB
    createButton(espContent, "ESP", function(btn, icon)
        State.espEnabled = not State.espEnabled
        toggleESP(State.espEnabled)
        
        if State.espEnabled then
            icon.Text = "●"
            icon.TextColor3 = CONFIG.THEME.Success
        else
            icon.Text = "○"
            icon.TextColor3 = CONFIG.THEME.TextDim
        end
    end)
    
    createButton(espContent, "Wallhack", function(btn, icon)
        State.wallhackEnabled = not State.wallhackEnabled
        toggleWallhack(State.wallhackEnabled)
        
        if State.wallhackEnabled then
            icon.Text = "●"
            icon.TextColor3 = CONFIG.THEME.Success
        else
            icon.Text = "○"
            icon.TextColor3 = CONFIG.THEME.TextDim
        end
    end)
    
    -- KEY TAB
    createLabel(keyContent, "Raccourcis clavier:", CONFIG.THEME.Accent)
    createLabel(keyContent, "[T] - Téléporter", CONFIG.THEME.Text)
    createLabel(keyContent, "[INSERT] - Ouvrir/Fermer", CONFIG.THEME.Text)
    
    -- INFO TAB
    createLabel(infoContent, "Discord:", CONFIG.THEME.Accent)
    
    local discordBtn = Instance.new("TextButton", infoContent)
    discordBtn.Size = UDim2.new(1, 0, 0, 50)
    discordBtn.BackgroundColor3 = CONFIG.THEME.TextDim
    discordBtn.BackgroundTransparency = 0.9
    discordBtn.Text = "discord.gg/TVBtZ47K"
    discordBtn.TextColor3 = CONFIG.THEME.Accent
    discordBtn.Font = Enum.Font.GothamBold
    discordBtn.TextSize = 14
    discordBtn.AutoButtonColor = false
    
    local discordCorner = Instance.new("UICorner", discordBtn)
    discordCorner.CornerRadius = UDim.new(0, 8)
    
    discordBtn.MouseButton1Click:Connect(function()
        setclipboard("https://discord.gg/TVBtZ47K")
        discordBtn.Text = "Copié!"
        task.wait(2)
        discordBtn.Text = "discord.gg/TVBtZ47K"
    end)
    
    -- DRAG SYSTEM
    local dragging, dragInput, dragStart, startPos
    
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- RACCOURCIS CLAVIER
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.T then
            teleportSequence()
        end
        
        if input.KeyCode == Enum.KeyCode.Insert then
            State.guiVisible = not State.guiVisible
            mainFrame.Visible = State.guiVisible
            reopenBtn.Visible = not State.guiVisible
        end
    end)
    
    print("═══════════════════════════════════")
    print("  4xvs - Interface avec catégories")
    print("  by 8v")
    print("  Discord: discord.gg/TVBtZ47K")
    print("═══════════════════════════════════")
end

-- ============================================================
-- INITIALISATION
-- ============================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")
    task.wait(1)
end)

createCategorizedGUI()
