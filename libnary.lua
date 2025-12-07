    -- ModernUI Library
    -- Eine moderne GUI Library für Roblox
    -- Version 1.0

    local ModernUI = {}
    ModernUI.__index = ModernUI

    -- Services
    local Players = game:GetService('Players')
    local TweenService = game:GetService('TweenService')
    local TextService = game:GetService('TextService')
    local UserInputService = game:GetService('UserInputService')
    local RunService = game:GetService('RunService')

    local GuiService = game:GetService('GuiService')

    local player = Players.LocalPlayer
    -- Verwende CoreGui für Persistenz bei Character Reset, Fallback zu PlayerGui
    local function getGuiParent()
        local success, coreGui = pcall(function()
            return game:GetService('CoreGui')
        end)
        
        if success and coreGui then
            return coreGui
        else
            -- Fallback zu PlayerGui falls CoreGui nicht verfügbar
            return player:WaitForChild('PlayerGui')
        end
    end

    local guiParent = getGuiParent()

    -- Mobile Detection & Scaling System
    local function isMobile()
        return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    end

    local function getScreenScale()
        local viewport = workspace.CurrentCamera.ViewportSize
        
        if isMobile() then
            -- Mobile: Berechne Skalierung basierend auf GUI-Größe vs Bildschirm
            local isLandscape = viewport.X > viewport.Y
            
            if isLandscape then
                -- Landscape: GUI ist 450px breit, Bildschirm ist viewport.X
                local scale = 450 / 650 -- GUI wird auf 450px skaliert von 650px = 0.69
                return math.clamp(scale, 0.6, 0.8)
            else
                -- Portrait: GUI ist 380px breit, Bildschirm ist viewport.X  
                local scale = 380 / 650 -- GUI wird auf 380px skaliert von 650px = 0.58
                return math.clamp(scale, 0.5, 0.7)
            end
        else
            -- Desktop: Normale Skalierung
            return 1.0
        end
    end

    local function getMobileLayout()
        local viewport = workspace.CurrentCamera.ViewportSize
        return {
            isMobile = isMobile(),
            scale = getScreenScale(),
            isLandscape = viewport.X > viewport.Y,
            safeArea = GuiService:GetGuiInset(),
            viewport = viewport
        }
    end

    -- Library Funktionen
    function ModernUI.new(options)
        local self = setmetatable({}, ModernUI)
        
        -- Mobile Layout Detection
        self.mobileLayout = getMobileLayout()
        
        -- Mobile-responsive size calculation - Hauptmenü kleiner
        local function calculateSize()
            if self.mobileLayout.isMobile then
                local viewport = self.mobileLayout.viewport
                
                if self.mobileLayout.isLandscape then
                    -- Landscape Mobile: Etwas schmaler
                    local width = math.min(450, viewport.X * 0.55)
                    local height = math.min(350, viewport.Y * 0.65)
                    return UDim2.new(0, width, 0, height)
                else
                    -- Portrait Mobile: Etwas schmaler  
                    local width = math.min(380, viewport.X * 0.65)
                    local height = math.min(400, viewport.Y * 0.60)
                    return UDim2.new(0, width, 0, height)
                end
            else
                -- Desktop: Standard size
                return UDim2.new(0, 650, 0, 430)
            end
        end
        -- Default Optionen
        local defaults = {
            title = 'ModernUI',
            size = calculateSize(),
            logo = 'rbxassetid://89538627714651',
            draggable = true,
            theme = {
                primary = Color3.fromRGB(215, 35, 36),
                background = Color3.fromRGB(19, 18, 21),
                surface = Color3.fromRGB(26, 25, 28),
                text = Color3.fromRGB(200, 200, 200),
                textDark = Color3.fromRGB(0, 0, 0),
            }
        }
        
        -- Helper to copy tables (shallow)
        local function copyTable(tbl)
            local clone = {}
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    clone[k] = copyTable(v)
                else
                    clone[k] = v
                end
            end
            return clone
        end
        
        -- Merge Optionen (mit geschützten Feldern)
        self.options = copyTable(defaults)
        if options then
            for k, v in pairs(options) do
                self.options[k] = v
            end
        end
        
        -- Geschützte Felder wieder auf Standardwerte setzen
        self.options.title = defaults.title
        self.options.size = calculateSize()
        self.options.logo = defaults.logo
        self.options.theme = copyTable(defaults.theme)
        
        -- Update size if mobile layout changes
        self._updateMobileLayout = function()
            self.mobileLayout = getMobileLayout()
            self.options.size = calculateSize()
            if self.mainFrame then
                self.mainFrame.Size = self.options.size
            end
        end
        
        self.tabs = {}
        self.tabButtons = {}
        self.contentFrames = {}
        self.currentTab = 1
        self._themeRefs = {
            sliderFills = {},
            checkboxUpdaters = {},
            dropdownOptionButtons = {},
            multiDropdownOptionButtons = {},
            licenseLabels = {},
            windowTitleGradients = {}, -- Für Window-Titel-Gradienten
        }
        
        -- Element Registry für Config System
        self._elementRegistry = {}
        self._elementCounter = 0
        
        -- Z-Index Counter für Dropdowns (damit obere Dropdowns untere überdecken)
        self._dropdownZIndexCounter = 50
        
        -- Active Keybinds Registry für Callback-System
        self.activeKeybinds = {}
        self._keybindListener = nil
        
        self:_createMainFrame()
        
        -- Sofortige Mobile Größenanpassung nach Erstellung
        if self.mobileLayout.isMobile then
            self:_applyMobileSizing()
            self:_setupOrientationListener()
        end
        
        self:_setupDragging()
        self:_setupToggleKeyListener()
        self:_createWatermark()
        self:_createKeybindList()

        -- Mobile Floating Logo (minimierte Ansicht)
        if self.mobileLayout.isMobile then
            self:_createFloatingLogo()
        end
        
        -- Notification System initialisieren
        self:_setupNotificationSystem()
        
        -- Config Manager Integration
        self.configManager = nil
        self:_setupConfigManagerIntegration()
        
        return self
    end

    function ModernUI:_createMainFrame()
        -- Hauptcontainer
        self.screenGui = Instance.new('ScreenGui')
        self.screenGui.Name = 'ModernGUI'
        self.screenGui.Parent = guiParent
        self.screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        self.screenGui.IgnoreGuiInset = false -- Respect safe areas on mobile

        -- Hauptframe mit mobile-optimierter Positionierung
        self.mainFrame = Instance.new('Frame')
        self.mainFrame.Name = 'MainFrame'
        self.mainFrame.Size = self.options.size
        
        -- Mobile-specific positioning
        if self.mobileLayout.isMobile then
            -- Center with safe area consideration
            local safeInset = self.mobileLayout.safeArea
            if self.mobileLayout.isLandscape then
                -- Landscape: Center but avoid notches
                self.mainFrame.Position = UDim2.new(0.5, -self.options.size.X.Offset/2, 0.5, -self.options.size.Y.Offset/2)
            else
                -- Portrait: Slightly higher to avoid home indicator
                self.mainFrame.Position = UDim2.new(0.5, -self.options.size.X.Offset/2, 0.5, -self.options.size.Y.Offset/2 - 20)
            end
        else
            -- Desktop: Standard center
            self.mainFrame.Position = UDim2.new(0.5, -self.options.size.X.Offset/2, 0.5, -self.options.size.Y.Offset/2)
        end
        
        self.mainFrame.BackgroundColor3 = self.options.theme.background
        self.mainFrame.BorderSizePixel = 0
        self.mainFrame.Parent = self.screenGui

        local mainCorner = Instance.new('UICorner')
        mainCorner.CornerRadius = UDim.new(0, 8)
        mainCorner.Parent = self.mainFrame

        -- Header mit skalierter Höhe
        local headerHeight = math.floor(50 * self.mobileLayout.scale)
        self.header = Instance.new('Frame')
        self.header.Name = 'Header'
        self.header.Size = UDim2.new(1, 0, 0, headerHeight)
        self.header.Position = UDim2.new(0, 0, 0, 0)
        self.header.BackgroundColor3 = self.options.theme.surface
        self.header.BorderSizePixel = 0
        self.header.Parent = self.mainFrame

        local headerCorner = Instance.new('UICorner')
        headerCorner.CornerRadius = UDim.new(0, 8)
        headerCorner.Parent = self.header

        local headerBottomMask = Instance.new('Frame')
        headerBottomMask.Size = UDim2.new(1, 0, 0, 8)
        headerBottomMask.Position = UDim2.new(0, 0, 1, -8)
        headerBottomMask.BackgroundColor3 = self.options.theme.surface
        headerBottomMask.BorderSizePixel = 0
        headerBottomMask.Parent = self.header

        -- Logo mit skalierter Größe
        local logoSize = math.floor(45 * self.mobileLayout.scale)
        local logoIcon = Instance.new('ImageLabel')
        logoIcon.Name = 'LogoIcon'
        logoIcon.Size = UDim2.new(0, logoSize, 0, logoSize)
        logoIcon.Position = UDim2.new(0, 8, 0.5, -logoSize/2)
        logoIcon.BackgroundTransparency = 1
        logoIcon.Image = self.options.logo
        logoIcon.ImageColor3 = self.options.theme.primary
        logoIcon.ScaleType = Enum.ScaleType.Fit
        logoIcon.Parent = self.header
        self.logoIcon = logoIcon

        -- Title
        local titleLabel = Instance.new('TextLabel')
        titleLabel.Name = 'TitleLabel'
        titleLabel.Size = UDim2.new(1, -150, 1, 0)
        titleLabel.Position = UDim2.new(0, 70, 0, 0)
        titleLabel.BackgroundTransparency = 1
        -- Remove header title text per request
        titleLabel.Text = ""
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextYAlignment = Enum.TextYAlignment.Center
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 16
        titleLabel.Parent = self.header

        -- Close Button mit skalierter Größe
        local closeSize = math.floor(30 * self.mobileLayout.scale)
        -- Mindestgröße für Touch auf Mobile
        if self.mobileLayout.isMobile and closeSize < 25 then
            closeSize = 25
        end
        local closeButton = Instance.new('TextButton')
        closeButton.Name = 'CloseButton'
        closeButton.Size = UDim2.new(0, closeSize, 0, closeSize)
        -- Close-Button immer ganz rechts
        closeButton.Position = UDim2.new(1, -closeSize - 8, 0.5, -closeSize/2)
        closeButton.BackgroundTransparency = 1
        closeButton.Text = '×'
        closeButton.TextColor3 = self.options.theme.text
        closeButton.TextScaled = true
        closeButton.Font = Enum.Font.GothamBold
        closeButton.Parent = self.header

        -- Touch + Mouse support
        closeButton.MouseButton1Click:Connect(function()
            self:Destroy()
        end)
        
        -- Mobile touch feedback
        if self.mobileLayout.isMobile then
            closeButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(closeButton, TweenInfo.new(0.1), {
                        BackgroundTransparency = 0.2,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    }):Play()
                end
            end)
            
            closeButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(closeButton, TweenInfo.new(0.2), {
                        BackgroundTransparency = 1
                    }):Play()
                end
            end)
        end

        -- Minimize Button nur für Mobile
        if self.mobileLayout.isMobile then
            local minimizeButton = Instance.new('TextButton')
            minimizeButton.Name = 'MinimizeButton'
            minimizeButton.Size = UDim2.new(0, closeSize, 0, closeSize)
            -- Minimize-Button links neben Close-Button
            minimizeButton.Position = UDim2.new(1, -closeSize * 2 - 16, 0.5, -closeSize/2)
            minimizeButton.BackgroundTransparency = 1
            minimizeButton.Text = '−'
            minimizeButton.TextColor3 = self.options.theme.text
            minimizeButton.TextScaled = true
            minimizeButton.Font = Enum.Font.GothamBold
            minimizeButton.Parent = self.header

            -- Touch feedback für Minimize-Button
            minimizeButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(minimizeButton, TweenInfo.new(0.1), {
                        BackgroundTransparency = 0.2,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    }):Play()
                end
            end)
            
            minimizeButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(minimizeButton, TweenInfo.new(0.2), {
                        BackgroundTransparency = 1
                    }):Play()
                end
            end)

            minimizeButton.MouseButton1Click:Connect(function()
                self:MinimizeToLogo()
            end)
            
            self.minimizeButton = minimizeButton
        end

        -- Tab Container schmaler für mehr Content-Platz
        local tabWidth = math.floor(100 * self.mobileLayout.scale)
        -- Mindestbreite für Lesbarkeit
        if tabWidth < 70 then tabWidth = 70 end
        self.tabContainer = Instance.new('Frame')
        self.tabContainer.Name = 'TabContainer'
        
        if self.mobileLayout.isMobile and not self.mobileLayout.isLandscape then
            -- Portrait Mobile: Horizontale Tabs oben
            self.tabContainer.Size = UDim2.new(1, 0, 0, 50)
            self.tabContainer.Position = UDim2.new(0, 0, 0, headerHeight)
        else
            -- Desktop oder Landscape: Vertikale Tabs links
            self.tabContainer.Size = UDim2.new(0, tabWidth, 1, -headerHeight - 80)
            self.tabContainer.Position = UDim2.new(0, 0, 0, headerHeight)
        end
        
        self.tabContainer.BackgroundColor3 = self.options.theme.background
        self.tabContainer.BorderSizePixel = 0
        self.tabContainer.Parent = self.mainFrame

        -- Content Container mit responsive Anpassung
        self.contentContainer = Instance.new('Frame')
        self.contentContainer.Name = 'ContentContainer'
        
        if self.mobileLayout.isMobile and not self.mobileLayout.isLandscape then
            -- Portrait Mobile: Content nimmt vollen Platz unter Tabs
            self.contentContainer.Size = UDim2.new(1, -20, 1, -headerHeight - 50 - 20)
            self.contentContainer.Position = UDim2.new(0, 10, 0, headerHeight + 50)
        else
            -- Desktop oder Landscape: Content rechts von Tabs (breiter, mehr nach unten)
            self.contentContainer.Size = UDim2.new(1, -tabWidth - 15, 1, -headerHeight - 20)
            self.contentContainer.Position = UDim2.new(0, tabWidth + 8, 0, headerHeight)
        end
        
        self.contentContainer.BackgroundColor3 = self.options.theme.background
        self.contentContainer.BorderSizePixel = 0
        self.contentContainer.Parent = self.mainFrame

        -- Player Info (unten links)
        self:_createPlayerInfo()
    end

    function ModernUI:_createPlayerInfo()
        -- Avatar-Sektion nur so breit wie Tab-Container
        local tabWidth = math.floor(100 * self.mobileLayout.scale)
        if tabWidth < 70 then tabWidth = 70 end -- Mindestbreite
        
        local containerHeight = math.floor(60 * self.mobileLayout.scale)
        local avatarSize = math.floor(35 * self.mobileLayout.scale)
        local padding = math.floor(8 * self.mobileLayout.scale)
        local bottomOffset = math.floor(68 * self.mobileLayout.scale)
        
        -- Mindestgrößen für Lesbarkeit
        if containerHeight < 45 then containerHeight = 45 end
        if avatarSize < 28 then avatarSize = 28 end
        if padding < 5 then padding = 5 end
        
        -- Avatar-Container nur so breit wie Tab-Container
        local playerInfoContainer = Instance.new('Frame')
        playerInfoContainer.Name = 'PlayerInfoContainer'
        playerInfoContainer.Size = UDim2.new(0, tabWidth, 0, containerHeight)
        playerInfoContainer.Position = UDim2.new(0, padding, 1, -bottomOffset)
        playerInfoContainer.BackgroundTransparency = 1
        playerInfoContainer.Parent = self.mainFrame

        local playerAvatar = Instance.new('ImageLabel')
        playerAvatar.Name = 'PlayerAvatar'
        playerAvatar.Size = UDim2.new(0, avatarSize, 0, avatarSize)
        playerAvatar.Position = UDim2.new(0, padding, 0.5, -avatarSize/2)
        playerAvatar.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        playerAvatar.BorderSizePixel = 0
        playerAvatar.Image = 'https://www.roblox.com/headshot-thumbnail/image?userId=' .. player.UserId .. '&width=150&height=150&format=png'
        playerAvatar.Parent = playerInfoContainer

        local avatarCorner = Instance.new('UICorner')
        avatarCorner.CornerRadius = UDim.new(0, math.floor(6 * self.mobileLayout.scale))
        avatarCorner.Parent = playerAvatar

        -- Text-Labels kompakter für schmäleren Container
        local nameWidth = tabWidth - avatarSize - padding * 3
        local nameHeight = math.floor(18 * self.mobileLayout.scale)
        local licenseHeight = math.floor(14 * self.mobileLayout.scale)
        
        local playerNameLabel = Instance.new('TextLabel')
        playerNameLabel.Name = 'PlayerNameLabel'
        playerNameLabel.Size = UDim2.new(0, nameWidth, 0, nameHeight)
        playerNameLabel.Position = UDim2.new(0, avatarSize + padding * 2, 0.5, -nameHeight/2 - 2)
        playerNameLabel.BackgroundTransparency = 1
        playerNameLabel.Text = player.Name
        playerNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        playerNameLabel.TextXAlignment = Enum.TextXAlignment.Left
        playerNameLabel.Font = Enum.Font.GothamBold
        playerNameLabel.TextSize = math.max(8, math.floor(10 * self.mobileLayout.scale))
        playerNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        playerNameLabel.Parent = playerInfoContainer

        local licenseLabel = Instance.new('TextLabel')
        licenseLabel.Name = 'LicenseLabel'
        licenseLabel.Size = UDim2.new(0, nameWidth, 0, licenseHeight)
        licenseLabel.Position = UDim2.new(0, avatarSize + padding * 2, 0.5, 2)
        licenseLabel.BackgroundTransparency = 1
        licenseLabel.Text = 'Lifetime'
        licenseLabel.TextColor3 = self.options.theme.primary
        licenseLabel.TextXAlignment = Enum.TextXAlignment.Left
        licenseLabel.Font = Enum.Font.Gotham
        licenseLabel.TextSize = math.max(7, math.floor(9 * self.mobileLayout.scale))
        licenseLabel.Parent = playerInfoContainer
        table.insert(self._themeRefs.licenseLabels, licenseLabel)
    end

    -- Floating Logo für Mobile Minimize
    function ModernUI:_createFloatingLogo()
        -- Floating Logo Container (anfangs unsichtbar)
        self._floatingLogo = Instance.new('Frame')
        self._floatingLogo.Name = 'FloatingLogo'
        self._floatingLogo.BackgroundColor3 = self.options.theme.surface
        self._floatingLogo.BorderSizePixel = 0
        self._floatingLogo.Visible = false
        self._floatingLogo.Active = true
        self._floatingLogo.ZIndex = 200
        
        -- Skalierte Logo-Größe
        local logoSize = math.floor(45 * self.mobileLayout.scale)
        if logoSize < 35 then logoSize = 35 end -- Mindestgröße für Touch
        
        self._floatingLogo.Size = UDim2.new(0, logoSize, 0, logoSize)
        self._floatingLogo.Position = UDim2.new(0, 20, 0, 100) -- Standard Position links oben
        self._floatingLogo.Parent = self.screenGui

        -- Abgerundete Ecken
        local logoCorner = Instance.new('UICorner')
        logoCorner.CornerRadius = UDim.new(0, 12)
        logoCorner.Parent = self._floatingLogo

        -- Logo Icon im Floating Logo
        local floatingLogoIcon = Instance.new('ImageLabel')
        floatingLogoIcon.Name = 'LogoIcon'
        floatingLogoIcon.Size = UDim2.new(0.7, 0, 0.7, 0)
        floatingLogoIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        floatingLogoIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        floatingLogoIcon.BackgroundTransparency = 1
        floatingLogoIcon.Image = self.options.logo
        floatingLogoIcon.ImageColor3 = self.options.theme.primary
        floatingLogoIcon.ScaleType = Enum.ScaleType.Fit
        floatingLogoIcon.Parent = self._floatingLogo
        self._floatingLogoIcon = floatingLogoIcon

        -- Touch feedback direkt auf Floating Logo
        self._floatingLogo.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(self._floatingLogo, TweenInfo.new(0.1), {
                    Size = UDim2.new(0, logoSize * 0.9, 0, logoSize * 0.9)
                }):Play()
            end
        end)
        
        self._floatingLogo.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                TweenService:Create(self._floatingLogo, TweenInfo.new(0.2), {
                    Size = UDim2.new(0, logoSize, 0, logoSize)
                }):Play()
            end
        end)

        -- Dragging für Floating Logo
        self:_setupFloatingLogoDragging()
    end

    -- Floating Logo Dragging
    function ModernUI:_setupFloatingLogoDragging()
        if not self._floatingLogo then return end
        
        local dragging = false
        local dragInput, mousePos, framePos
        local dragStartTime = 0
        local clickThreshold = 0.2 -- Sekunden für Click vs Drag

        self._floatingLogo.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false -- Erst mal kein Dragging
                dragStartTime = tick()
                mousePos = input.Position
                framePos = self._floatingLogo.Position
            end
        end)

        self._floatingLogo.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
                -- Starte Dragging wenn Bewegung erkannt wird
                if mousePos and not dragging then
                    local delta = input.Position - mousePos
                    if delta.Magnitude > 5 then -- Mindest-Bewegung für Dragging
                        dragging = true
                    end
                end
            end
        end)

        self._floatingLogo.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local dragDuration = tick() - dragStartTime
                
                -- Wenn kurzer Tap ohne Dragging -> Restore GUI
                if not dragging and dragDuration < clickThreshold then
                    self:RestoreFromLogo()
                end
                
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging and mousePos then
                local delta = input.Position - mousePos
                self._floatingLogo.Position = UDim2.new(
                    framePos.X.Scale,
                    framePos.X.Offset + delta.X,
                    framePos.Y.Scale,
                    framePos.Y.Offset + delta.Y
                )
            end
        end)
    end





    function ModernUI:_setupDragging()
        if not self.options.draggable then return end
        
        local dragging = false
        local dragInput, mousePos, framePos

        self.header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                mousePos = input.Position
                framePos = self.mainFrame.Position
            end
        end)

        self.header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)

        self.header.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - mousePos
                self.mainFrame.Position = UDim2.new(
                    framePos.X.Scale,
                    framePos.X.Offset + delta.X,
                    framePos.Y.Scale,
                    framePos.Y.Offset + delta.Y
                )
            end
        end)
    end

    -- Toggle key handling
    function ModernUI:_setupToggleKeyListener()
        -- default toggle key is RightShift
        self._toggleKeyCode = Enum.KeyCode.RightShift
        if self._toggleConn then
            self._toggleConn:Disconnect()
            self._toggleConn = nil
        end
        self._toggleConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if self._isCapturingKeybind then return end
            if self._ignoreNextToggleKeyCode and input.KeyCode == self._ignoreNextToggleKeyCode then
                -- ignore this one key press (from binding capture) and clear flag
                self._ignoreNextToggleKeyCode = nil
                return
            end
            if self._ignoreToggleUntil and os.clock() < self._ignoreToggleUntil then
                return
            end
            if input.KeyCode == self._toggleKeyCode then
                self:Toggle()
            end
            
            -- Check for active keybinds and trigger callbacks
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local keyName = input.KeyCode.Name
                for keybindId, keybindData in pairs(self.activeKeybinds) do
                    if keybindData.key == keyName and keybindData.key ~= "None" then
                        if keybindData.callback then
                            keybindData.callback(keyName)
                        end
                        -- Highlight in Keybindlist
                        self:_highlightKeybindInList(keybindId)
                    end
                end
            end
        end)
    end

    -- Watermark (top-right, draggable when UI is open)
    function ModernUI:_createWatermark()
        self._watermarkVisible = true
        self._watermarkFrame = Instance.new('Frame')
        self._watermarkFrame.Name = 'Watermark'
        self._watermarkFrame.BackgroundColor3 = self.options.theme.surface
        self._watermarkFrame.BorderSizePixel = 0
        -- Skalierte Watermark-Größe (breiter für "Radiant")
        local watermarkWidth = math.floor(200 * self.mobileLayout.scale)
        local watermarkHeight = math.floor(32 * self.mobileLayout.scale)
        local watermarkOffset = math.floor(220 * self.mobileLayout.scale)
        local watermarkPadding = math.floor(8 * self.mobileLayout.scale)
        
        -- Mindestgrößen (erhöht für "Radiant")
        if watermarkWidth < 160 then watermarkWidth = 160 end
        if watermarkHeight < 24 then watermarkHeight = 24 end
        
        self._watermarkFrame.Size = UDim2.new(0, watermarkWidth, 0, watermarkHeight)
        self._watermarkFrame.Position = UDim2.new(1, -watermarkOffset, 0, watermarkPadding)
        self._watermarkFrame.AnchorPoint = Vector2.new(0, 0)
        self._watermarkFrame.Active = true
        self._watermarkFrame.Visible = true
        self._watermarkFrame.Parent = self.screenGui

        local wmCorner = Instance.new('UICorner')
        wmCorner.CornerRadius = UDim.new(0, 6) -- Etwas größerer Radius
        wmCorner.Parent = self._watermarkFrame

        -- Farbiger Strich auf der linken Seite
        local accentBar = Instance.new('Frame')
        accentBar.Name = 'AccentBar'
        accentBar.Size = UDim2.new(0, 3, 1, 0) -- 3px breiter Strich
        accentBar.Position = UDim2.new(0, 0, 0, 0)
        accentBar.BackgroundColor3 = self.options.theme.primary -- Theme-Farbe
        accentBar.BorderSizePixel = 0
        accentBar.Parent = self._watermarkFrame

        local accentCorner = Instance.new('UICorner')
        accentCorner.CornerRadius = UDim.new(0, 6)
        accentCorner.Parent = accentBar

        -- Speichere Referenz für Theme-Updates
        self._watermarkAccentBar = accentBar

        local wmLabel = Instance.new('TextLabel')
        wmLabel.Name = 'Label'
        wmLabel.BackgroundTransparency = 1
        wmLabel.Size = UDim2.new(1, -18, 1, 0) -- Mehr Platz für den Strich
        wmLabel.Position = UDim2.new(0, 12, 0, 0) -- Weiter nach rechts verschoben
        wmLabel.Font = Enum.Font.Gotham
        wmLabel.TextSize = 14 -- Größere Schrift
        wmLabel.TextXAlignment = Enum.TextXAlignment.Left
        wmLabel.TextColor3 = self.options.theme.text
        wmLabel.RichText = true
        wmLabel.Parent = self._watermarkFrame

        local function colorToHex(c)
            local r = math.clamp(math.floor(c.R * 255 + 0.5), 0, 255)
            local g = math.clamp(math.floor(c.G * 255 + 0.5), 0, 255)
            local b = math.clamp(math.floor(c.B * 255 + 0.5), 0, 255)
            return string.format("#%02X%02X%02X", r, g, b)
        end

        local function setWatermarkText(fps, pingMs)
            local radiant = string.format('<font color="%s">Radiant</font>', colorToHex(self.options.theme.primary))
            wmLabel.Text = string.format("%s | %d FPS | %d ms", radiant, fps, pingMs)
            local plainText = string.format("Radiant | %d FPS | %d ms", fps, pingMs)
            local bounds = TextService:GetTextSize(plainText, wmLabel.TextSize, wmLabel.Font, Vector2.new(10000, 32))
            self._watermarkFrame.Size = UDim2.new(0, bounds.X + 24, 0, 32) -- Mehr Platz für "Radiant"
        end

        -- Efficient update: one per frame for FPS, ping sampled when available
        if self._watermarkUpdateConn then self._watermarkUpdateConn:Disconnect() end
        self._watermarkUpdateConn = RunService.RenderStepped:Connect(function()
            -- RenderStepped yields in formatStats; avoid nested Wait by caching delta
            -- Instead compute FPS from passed step
        end)

        -- Re-implement with delta-based FPS
        local lastUpdate = os.clock()
        local accum = 0
        local frames = 0
        local pingMs = 0
        if self._watermarkUpdateConn then self._watermarkUpdateConn:Disconnect() end
        self._watermarkUpdateConn = RunService.RenderStepped:Connect(function(dt)
            frames = frames + 1
            accum = accum + dt
            if accum >= 0.25 then
                local fps = math.floor(frames / accum)
                -- Update ping occasionally
                local network = game:GetService('Stats') and game:GetService('Stats').Network
                if network and network.ServerStatsItem and network.ServerStatsItem['Data Ping'] and network.ServerStatsItem['Data Ping'].GetValue then
                    local ok, val = pcall(function()
                        return network.ServerStatsItem['Data Ping']:GetValue()
                    end)
                    if ok and typeof(val) == 'number' then
                        pingMs = math.floor(val)
                    end
                end
                setWatermarkText(fps, pingMs)
                accum = 0
                frames = 0
            end
        end)

        -- Dragging only when main UI visible
        local dragging = false
        local dragInput, mousePos, framePos
        self._watermarkFrame.InputBegan:Connect(function(input)
            if not self.mainFrame.Visible then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                mousePos = input.Position
                framePos = self._watermarkFrame.Position
            end
        end)
        self._watermarkFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        self._watermarkFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - mousePos
                self._watermarkFrame.Position = UDim2.new(
                    framePos.X.Scale,
                    framePos.X.Offset + delta.X,
                    framePos.Y.Scale,
                    framePos.Y.Offset + delta.Y
                )
            end
        end)
    end

    function ModernUI:SetWatermarkVisible(visible)
        self._watermarkVisible = not not visible
        if self._watermarkFrame then
            self._watermarkFrame.Visible = self._watermarkVisible
        end
    end

    -- Keybind List (ähnlich wie Watermark)
    function ModernUI:_createKeybindList()
        self._keybindListVisible = false
        self._keybindListFrame = Instance.new('Frame')
        self._keybindListFrame.Name = 'KeybindList'
        self._keybindListFrame.BackgroundColor3 = self.options.theme.surface
        self._keybindListFrame.BorderSizePixel = 0
        self._keybindListFrame.Visible = false
        self._keybindListFrame.AutomaticSize = Enum.AutomaticSize.Y
        self._keybindListFrame.Active = true
        self._keybindListFrame.Parent = self.screenGui

        -- Skalierte Größe
        local listWidth = math.floor(200 * self.mobileLayout.scale)
        local listPadding = math.floor(10 * self.mobileLayout.scale)
        if listWidth < 160 then listWidth = 160 end

        self._keybindListFrame.Size = UDim2.new(0, listWidth, 0, 0)
        self._keybindListFrame.Position = UDim2.new(0, listPadding, 0.5, -100)

        local listCorner = Instance.new('UICorner')
        listCorner.CornerRadius = UDim.new(0, 6)
        listCorner.Parent = self._keybindListFrame

        -- Titel "Keybindlist"
        local titleFrame = Instance.new('Frame')
        titleFrame.Name = 'TitleFrame'
        titleFrame.Size = UDim2.new(1, 0, 0, 35)
        titleFrame.BackgroundColor3 = self.options.theme.primary
        titleFrame.BorderSizePixel = 0
        titleFrame.Parent = self._keybindListFrame

        local titleCorner = Instance.new('UICorner')
        titleCorner.CornerRadius = UDim.new(0, 6)
        titleCorner.Parent = titleFrame

        local titleMask = Instance.new('Frame')
        titleMask.Size = UDim2.new(1, 0, 0, 6)
        titleMask.Position = UDim2.new(0, 0, 1, -6)
        titleMask.BackgroundColor3 = self.options.theme.primary
        titleMask.BorderSizePixel = 0
        titleMask.Parent = titleFrame

        local titleLabel = Instance.new('TextLabel')
        titleLabel.Name = 'TitleLabel'
        titleLabel.Size = UDim2.new(1, -20, 1, 0)
        titleLabel.Position = UDim2.new(0, 10, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = 'Keybindlist'
        titleLabel.TextColor3 = self.options.theme.textDark
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 14
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = titleFrame

        -- Container für Keybinds
        self._keybindListContainer = Instance.new('Frame')
        self._keybindListContainer.Name = 'Container'
        self._keybindListContainer.Size = UDim2.new(1, 0, 0, 0)
        self._keybindListContainer.Position = UDim2.new(0, 0, 0, 35)
        self._keybindListContainer.BackgroundTransparency = 1
        self._keybindListContainer.AutomaticSize = Enum.AutomaticSize.Y
        self._keybindListContainer.Parent = self._keybindListFrame

        local listLayout = Instance.new('UIListLayout')
        listLayout.Padding = UDim.new(0, 5)
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = self._keybindListContainer

        local containerPadding = Instance.new('UIPadding')
        containerPadding.PaddingTop = UDim.new(0, 8)
        containerPadding.PaddingBottom = UDim.new(0, 8)
        containerPadding.PaddingLeft = UDim.new(0, 8)
        containerPadding.PaddingRight = UDim.new(0, 8)
        containerPadding.Parent = self._keybindListContainer

        -- Speichere Referenz für Theme-Updates
        self._keybindListTitleFrame = titleFrame
        self._keybindListTitleMask = titleMask

        -- Dragging (wie Watermark)
        local dragging = false
        local dragInput, mousePos, framePos
        self._keybindListFrame.InputBegan:Connect(function(input)
            if not self.mainFrame.Visible then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                mousePos = input.Position
                framePos = self._keybindListFrame.Position
            end
        end)
        self._keybindListFrame.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        self._keybindListFrame.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - mousePos
                self._keybindListFrame.Position = UDim2.new(
                    framePos.X.Scale,
                    framePos.X.Offset + delta.X,
                    framePos.Y.Scale,
                    framePos.Y.Offset + delta.Y
                )
            end
        end)
    end

    function ModernUI:SetKeybindListVisible(visible)
        self._keybindListVisible = not not visible
        if self._keybindListFrame then
            self._keybindListFrame.Visible = self._keybindListVisible
            if self._keybindListVisible then
                self:_updateKeybindList()
            end
        end
    end

    function ModernUI:_updateKeybindList()
        if not self._keybindListContainer then return end

        -- Lösche alle bestehenden Keybind-Einträge
        for _, child in ipairs(self._keybindListContainer:GetChildren()) do
            if child:IsA('Frame') and child.Name == 'KeybindEntry' then
                child:Destroy()
            end
        end

        -- Füge aktive Keybinds hinzu (nur die mit showInList = true)
        for keybindId, keybindData in pairs(self.activeKeybinds) do
            if keybindData.showInList and keybindData.key ~= "None" then
                local entry = Instance.new('Frame')
                entry.Name = 'KeybindEntry'
                entry.Size = UDim2.new(1, -16, 0, 25)
                entry.BackgroundColor3 = self.options.theme.background
                entry.BorderSizePixel = 0
                entry.Parent = self._keybindListContainer

                local entryCorner = Instance.new('UICorner')
                entryCorner.CornerRadius = UDim.new(0, 4)
                entryCorner.Parent = entry

                local nameLabel = Instance.new('TextLabel')
                nameLabel.Name = 'NameLabel'
                nameLabel.Size = UDim2.new(0.6, -8, 1, 0)
                nameLabel.Position = UDim2.new(0, 6, 0, 0)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = keybindData.name or 'Keybind'
                nameLabel.TextColor3 = self.options.theme.text
                nameLabel.Font = Enum.Font.Gotham
                nameLabel.TextSize = 11
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                nameLabel.Parent = entry

                local keyLabel = Instance.new('TextLabel')
                keyLabel.Name = 'KeyLabel'
                keyLabel.Size = UDim2.new(0.4, -8, 1, 0)
                keyLabel.Position = UDim2.new(0.6, 0, 0, 0)
                keyLabel.BackgroundTransparency = 1
                keyLabel.Text = '[' .. keybindData.key .. ']'
                keyLabel.TextColor3 = self.options.theme.text
                keyLabel.Font = Enum.Font.GothamBold
                keyLabel.TextSize = 11
                keyLabel.TextXAlignment = Enum.TextXAlignment.Right
                keyLabel.Parent = entry

                -- Speichere Referenzen für Highlighting
                keybindData.listEntry = entry
                keybindData.listEntryNameLabel = nameLabel
                keybindData.listEntryKeyLabel = keyLabel
            end
        end
    end

    function ModernUI:_highlightKeybindInList(keybindId)
        if not self._keybindListVisible then return end

        local keybindData = self.activeKeybinds[keybindId]
        if not keybindData or not keybindData.listEntry then return end

        local entry = keybindData.listEntry
        local originalBg = self.options.theme.background

        -- Highlight mit Theme-Farbe
        TweenService:Create(entry, TweenInfo.new(0.1), {
            BackgroundColor3 = self.options.theme.primary
        }):Play()

        -- Nach kurzer Zeit zurück zur Original-Farbe
        task.delay(0.5, function()
            if entry and entry.Parent then
                TweenService:Create(entry, TweenInfo.new(0.3), {
                    BackgroundColor3 = originalBg
                }):Play()
            end
        end)
    end

    function ModernUI:SetToggleKey(key)
        -- Accept Enum.KeyCode or string name (e.g., "RightShift")
        local keyCode = nil
        if typeof(key) == "EnumItem" and tostring(key.EnumType) == "Enum.KeyCode" then
            keyCode = key
        elseif typeof(key) == "string" and Enum.KeyCode[key] then
            keyCode = Enum.KeyCode[key]
        end
        if keyCode then
            self._toggleKeyCode = keyCode
        end
    end

    function ModernUI:GetToggleKey()
        return self._toggleKeyCode
    end

    -- Tab Management with Mobile Support
    function ModernUI:CreateTab(name, icon)
        local tabIndex = #self.tabs + 1
        
        -- Mobile-responsive Tab Button
        local tabButton = Instance.new('TextButton')
        tabButton.Name = name .. 'Tab'
        
        -- Mobile layout adjustments
        if self.mobileLayout.isMobile and not self.mobileLayout.isLandscape then
            -- Portrait Mobile: Horizontal tabs
            local tabWidth = math.floor((self.tabContainer.AbsoluteSize.X - 20) / math.max(#self.tabs + 1, 3))
            tabButton.Size = UDim2.new(0, tabWidth, 1, -10)
            tabButton.Position = UDim2.new(0, (tabIndex - 1) * (tabWidth + 5) + 10, 0, 5)
            tabButton.TextSize = 11 -- Smaller text for mobile
                else
                -- Desktop or Landscape: Vertical tabs (skaliert)
                local buttonHeight = math.floor(35 * self.mobileLayout.scale)
                local spacing = math.floor(10 * self.mobileLayout.scale)
                local padding = math.floor(8 * self.mobileLayout.scale)
                -- Mindestgrößen für Touch
                if self.mobileLayout.isMobile then
                    if buttonHeight < 25 then buttonHeight = 25 end
                    if spacing < 6 then spacing = 6 end
                    if padding < 5 then padding = 5 end
                end
                tabButton.Size = UDim2.new(1, -10, 0, buttonHeight)
                tabButton.Position = UDim2.new(0, padding, 0, (tabIndex - 1) * (buttonHeight + spacing) + padding)
                tabButton.TextSize = math.floor(14 * self.mobileLayout.scale)
            end
        
        tabButton.BackgroundColor3 = self.options.theme.surface
        tabButton.BorderSizePixel = 0
        tabButton.Text = name
        tabButton.TextColor3 = self.options.theme.text
        tabButton.Font = Enum.Font.Gotham
        tabButton.Parent = self.tabContainer
        
        -- Mobile touch feedback
        if self.mobileLayout.isMobile then
            tabButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(tabButton, TweenInfo.new(0.1), {
                        BackgroundTransparency = 0.1
                    }):Play()
                end
            end)
            
            tabButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(tabButton, TweenInfo.new(0.2), {
                        BackgroundTransparency = 0
                    }):Play()
                end
            end)
        end

        local tabCorner = Instance.new('UICorner')
        tabCorner.CornerRadius = UDim.new(0, 4)
        tabCorner.Parent = tabButton

        table.insert(self.tabButtons, tabButton)

        -- Content Frame
        local contentFrame = Instance.new('ScrollingFrame')
        contentFrame.Name = name .. 'Content'
        contentFrame.Size = UDim2.new(1, -20, 1, -20)
        contentFrame.Position = UDim2.new(0, 10, 0, 10)
        contentFrame.BackgroundTransparency = 1
        contentFrame.BorderSizePixel = 0
        contentFrame.ScrollBarThickness = 6
        contentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        contentFrame.Visible = (tabIndex == 1)
        contentFrame.Parent = self.contentContainer

        local contentPadding = Instance.new('UIPadding')
        contentPadding.PaddingLeft = UDim.new(0, 0)
        contentPadding.Parent = contentFrame

        table.insert(self.contentFrames, contentFrame)

        -- Create two layout columns inside the content frame for auto-stacking windows
        self._columnsByContentFrame = self._columnsByContentFrame or {}
        local columnsContainer = Instance.new('Frame')
        columnsContainer.Name = 'ColumnsContainer'
        columnsContainer.BackgroundTransparency = 1
        columnsContainer.Size = UDim2.new(1, -12, 0, 0)
        columnsContainer.Position = UDim2.new(0, 4, 0, 12)
        columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
        columnsContainer.Parent = contentFrame

        -- Use constraints and padding to avoid overlaps and keep gutters
        local columnsPadding = Instance.new('UIPadding')
        columnsPadding.PaddingRight = UDim.new(0, 0)
        columnsPadding.PaddingLeft = UDim.new(0, 0)
        columnsPadding.PaddingTop = UDim.new(0, 0)
        columnsPadding.PaddingBottom = UDim.new(0, 0)
        columnsPadding.Parent = columnsContainer

        local col1 = Instance.new('Frame')
        col1.Name = 'Column1'
        col1.BackgroundTransparency = 1
        col1.Size = UDim2.new(0.5, -6, 0, 0)
        col1.Position = UDim2.new(0, 0, 0, 0)
        col1.ClipsDescendants = true
        col1.AutomaticSize = Enum.AutomaticSize.Y
        col1.Parent = columnsContainer

        local col2 = Instance.new('Frame')
        col2.Name = 'Column2'
        col2.BackgroundTransparency = 1
        col2.Size = UDim2.new(0.5, -6, 0, 0)
        col2.Position = UDim2.new(1, 0, 0, 0)
        col2.AnchorPoint = Vector2.new(1, 0)
        col2.ClipsDescendants = true
        col2.AutomaticSize = Enum.AutomaticSize.Y
        col2.Parent = columnsContainer

        local list1 = Instance.new('UIListLayout')
        list1.Padding = UDim.new(0, 12)
        list1.FillDirection = Enum.FillDirection.Vertical
        list1.SortOrder = Enum.SortOrder.LayoutOrder
        list1.Parent = col1

        local list2 = Instance.new('UIListLayout')
        list2.Padding = UDim.new(0, 12)
        list2.FillDirection = Enum.FillDirection.Vertical
        list2.SortOrder = Enum.SortOrder.LayoutOrder
        list2.Parent = col2

        -- Prevent overlap: give windows full width inside column and respect padding via layout
        local function applyColumnChildProps(column)
            local function apply(child)
                if child:IsA('Frame') then
                    child.Size = UDim2.new(1, 0, 0, child.AbsoluteSize.Y)
                    child.AutomaticSize = Enum.AutomaticSize.Y
                    child.ClipsDescendants = false
                end
            end
            for _, c in ipairs(column:GetChildren()) do apply(c) end
            column.ChildAdded:Connect(apply)
        end
        applyColumnChildProps(col1)
        applyColumnChildProps(col2)

        self._columnsByContentFrame[contentFrame] = { col1 = col1, col2 = col2 }

        -- Keep the scrollable area sized to tallest column
        local function updateCanvasSize()
            local h1 = list1.AbsoluteContentSize.Y
            local h2 = list2.AbsoluteContentSize.Y
            local tallest = math.max(h1, h2)
            contentFrame.CanvasSize = UDim2.new(0, 0, 0, tallest + 40)
        end
        list1:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateCanvasSize)
        list2:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateCanvasSize)
        columnsContainer:GetPropertyChangedSignal('AbsoluteSize'):Connect(updateCanvasSize)
        updateCanvasSize()

        -- Tab Click Event
        tabButton.MouseButton1Click:Connect(function()
            self:SwitchTab(tabIndex)
        end)

        -- Initialer Tab
        if tabIndex == 1 then
            self:SwitchTab(1)
        end

        -- Return Tab Object
        local tab = {
            frame = contentFrame,
            index = tabIndex,
            windows = {},
            library = self
        }
        
        function tab:CreateWindow(title, size, position, defaultExpanded)
            return self.library:_createWindow(self.frame, title, size, position, defaultExpanded)
        end
        
        table.insert(self.tabs, tab)

        -- No auto-injection here; keep library generic

        return tab
    end

    function ModernUI:SwitchTab(tabIndex)
        for i, button in ipairs(self.tabButtons) do
            local isActive = (i == tabIndex)
            local bgColor = isActive and self.options.theme.primary or self.options.theme.surface
            local textColor = isActive and self.options.theme.textDark or self.options.theme.text
            
            local tween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                BackgroundColor3 = bgColor,
                TextColor3 = textColor
            })
            tween:Play()
            
            self.contentFrames[i].Visible = isActive
        end
        
        self.currentTab = tabIndex
    end

    -- Apply theme to tab buttons without tween (for real-time theme updates)
    function ModernUI:_applyTabThemeColors()
        for i, button in ipairs(self.tabButtons) do
            local isActive = (i == self.currentTab)
            button.BackgroundColor3 = isActive and self.options.theme.primary or self.options.theme.surface
            button.TextColor3 = isActive and self.options.theme.textDark or self.options.theme.text
        end
    end

    -- Window Creation
    function ModernUI:_createWindow(parent, title, size, position, defaultExpanded)
        -- size and position can be hinted; auto-layout will place and size
        size = size or UDim2.new(0, 0, 0, 0)
        position = position or UDim2.new(0, 0, 0, 0)
        defaultExpanded = defaultExpanded or false -- Standard: eingeklappt
        
        local window = Instance.new('Frame')
        window.Name = title .. 'Window'
        window.BackgroundColor3 = Color3.fromRGB(21, 21, 23)
        window.BorderSizePixel = 0
        window.AutomaticSize = Enum.AutomaticSize.Y
        window.Size = UDim2.new(1, 0, 0, 0)
        window.Parent = parent

        local windowCorner = Instance.new('UICorner')
        windowCorner.CornerRadius = UDim.new(0, 6)
        windowCorner.Parent = window

        -- Header
        local windowHeader = Instance.new('Frame')
        windowHeader.Name = 'Header'
        windowHeader.Size = UDim2.new(1, 0, 0, 30)
        windowHeader.BackgroundColor3 = self.options.theme.surface
        windowHeader.BorderSizePixel = 0
        windowHeader.Parent = window

        local headerCorner = Instance.new('UICorner')
        headerCorner.CornerRadius = UDim.new(0, 6)
        headerCorner.Parent = windowHeader

        local headerMask = Instance.new('Frame')
        headerMask.Size = UDim2.new(1, 0, 0, 6)
        headerMask.Position = UDim2.new(0, 0, 1, -6)
        headerMask.BackgroundColor3 = self.options.theme.surface
        headerMask.BorderSizePixel = 0
        headerMask.Parent = windowHeader

        -- Title (mit Platz für Collapse-Button und Gradient)
        local windowTitle = Instance.new('TextLabel')
        windowTitle.Name = 'Title'
        -- Größe wird dynamisch basierend auf Textlänge angepasst
        windowTitle.Size = UDim2.new(0, 0, 1, 0) -- Wird später angepasst
        windowTitle.Position = UDim2.new(0, 10, 0, 0)
        windowTitle.BackgroundTransparency = 1
        windowTitle.Text = title
        -- WICHTIG: TextColor3 muss auf Weiß sein, damit Gradient funktioniert
        windowTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        windowTitle.TextXAlignment = Enum.TextXAlignment.Left
        windowTitle.TextYAlignment = Enum.TextYAlignment.Center
        windowTitle.Font = Enum.Font.GothamBold
        windowTitle.TextSize = 14
        windowTitle.TextTruncate = Enum.TextTruncate.None
        windowTitle.Parent = windowHeader
        
        -- Textgröße berechnen und TextLabel-Größe anpassen (für korrekten Gradient)
        -- Funktion zum Aktualisieren der TextLabel-Größe
        local function updateTitleSize()
            -- Berechne Textgröße mit TextService
            local textBounds = TextService:GetTextSize(
                windowTitle.Text,
                windowTitle.TextSize,
                windowTitle.Font,
                Vector2.new(10000, windowHeader.AbsoluteSize.Y)
            )
            
            -- Setze TextLabel-Größe auf Textgröße (mit etwas Padding)
            local textWidth = textBounds.X + 4 -- Kleines Padding
            local maxWidth = windowHeader.AbsoluteSize.X - 60 -- Platz für Collapse-Button
            windowTitle.Size = UDim2.new(0, math.min(textWidth, maxWidth), 1, 0)
        end
        
        -- Größe nach Rendering aktualisieren
        task.spawn(function()
            -- Warte auf Rendering
            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()
            updateTitleSize()
        end)
        
        -- Größe aktualisieren, wenn sich Text ändert
        windowTitle:GetPropertyChangedSignal("Text"):Connect(function()
            task.spawn(function()
                RunService.RenderStepped:Wait()
                updateTitleSize()
            end)
        end)
        
        -- Gradient für Titel - Komplett neu programmiert
        local function createTitleGradient()
            local titleGradient = Instance.new('UIGradient')
            titleGradient.Name = 'TitleGradient'
            titleGradient.Rotation = 0 -- Horizontaler Gradient (von links nach rechts)
            
            -- Transparency: Vollständig sichtbar
            titleGradient.Transparency = NumberSequence.new(0)
            
            -- Color: 50/50 Split mit breitem, sichtbarem Gradient-Übergang
            local whiteColor = Color3.fromRGB(255, 255, 255)
            local themeColor = self.options.theme.primary
            
            -- Breiter Gradient-Übergang: Weiß bis 30%, Übergang 30-70%, Theme Color ab 70%
            -- Mehr Keypoints für sichtbareren Gradient-Effekt
            local midColor1 = Color3.new(
                whiteColor.R * 0.7 + themeColor.R * 0.3,
                whiteColor.G * 0.7 + themeColor.G * 0.3,
                whiteColor.B * 0.7 + themeColor.B * 0.3
            )
            local midColor2 = Color3.new(
                whiteColor.R * 0.3 + themeColor.R * 0.7,
                whiteColor.G * 0.3 + themeColor.G * 0.7,
                whiteColor.B * 0.3 + themeColor.B * 0.7
            )
            
            titleGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.0, whiteColor),      -- Start: Weiß
                ColorSequenceKeypoint.new(0.3, whiteColor),      -- Weiß bis 30%
                ColorSequenceKeypoint.new(0.4, midColor1),      -- Erste Mischung bei 40%
                ColorSequenceKeypoint.new(0.5, Color3.new(
                    (whiteColor.R + themeColor.R) / 2,
                    (whiteColor.G + themeColor.G) / 2,
                    (whiteColor.B + themeColor.B) / 2
                )),                                              -- Mitte: 50/50 Mischung
                ColorSequenceKeypoint.new(0.6, midColor2),      -- Zweite Mischung bei 60%
                ColorSequenceKeypoint.new(0.7, themeColor),     -- Theme Color ab 70%
                ColorSequenceKeypoint.new(1.0, themeColor)       -- Theme Color bis Ende
            })
            
            -- Gradient muss als Child des TextLabels hinzugefügt werden
            titleGradient.Parent = windowTitle
            
            return titleGradient
        end
        
        -- Gradient erstellen
        local titleGradient = createTitleGradient()
        
        -- Gradient zur Theme-Referenzliste hinzufügen für Updates
        table.insert(self._themeRefs.windowTitleGradients, titleGradient)

        -- Collapse Button (Pfeil wie bei Dropdown)
        local collapseButton = Instance.new('TextButton')
        collapseButton.Name = 'CollapseButton'
        collapseButton.Size = UDim2.new(0, 30, 1, 0)
        collapseButton.Position = UDim2.new(1, -35, 0, 0)
        collapseButton.BackgroundTransparency = 1
        collapseButton.BorderSizePixel = 0
        collapseButton.AutoButtonColor = false
        collapseButton.Text = ''
        collapseButton.Parent = windowHeader

        -- Collapse Arrow (wie bei Dropdown) - Größer gemacht
        local collapseArrow = Instance.new('ImageLabel')
        collapseArrow.Name = 'Arrow'
        collapseArrow.Size = UDim2.new(0, 22, 0, 22) -- Größer: von 16x16 auf 22x22
        collapseArrow.AnchorPoint = Vector2.new(0.5, 0.5)
        collapseArrow.Position = UDim2.new(0.5, 0, 0.5, 0)
        collapseArrow.BackgroundTransparency = 1
        collapseArrow.Image = 'rbxassetid://128488479848041'
        collapseArrow.ImageColor3 = self.options.theme.text
        collapseArrow.Rotation = defaultExpanded and 0 or 180 -- Start: basierend auf defaultExpanded
        collapseArrow.Parent = collapseButton

        -- Separator
        local separator = Instance.new('Frame')
        separator.Name = 'Separator'
        separator.Size = UDim2.new(1, 0, 0, defaultExpanded and 1 or 0) -- Basierend auf defaultExpanded
        separator.Position = UDim2.new(0, 0, 0, 30)
        separator.BackgroundColor3 = Color3.fromRGB(30, 30, 32)
        separator.BackgroundTransparency = defaultExpanded and 0 or 1 -- Basierend auf defaultExpanded
        separator.BorderSizePixel = 0
        separator.Parent = window
        separator.Visible = defaultExpanded -- Basierend auf defaultExpanded

        -- Content Wrapper Frame für Animation (umschließt Content Area)
        local contentWrapper = Instance.new('Frame')
        contentWrapper.Name = 'ContentWrapper'
        contentWrapper.Size = UDim2.new(1, -16, 0, 0) -- Wird durch Animation gesteuert
        contentWrapper.Position = UDim2.new(0, 8, 0, 35)
        contentWrapper.BackgroundTransparency = 1
        contentWrapper.ClipsDescendants = true -- Wichtig: Clippt Content bei Animation
        contentWrapper.Parent = window
        contentWrapper.Visible = defaultExpanded

        -- Content Area (breiter für größere Elemente) - IMMER mit AutomaticSize
        local contentArea = Instance.new('Frame')
        contentArea.Name = 'ContentArea'
        contentArea.AutomaticSize = Enum.AutomaticSize.Y -- IMMER aktiviert
        contentArea.Size = UDim2.new(1, 0, 0, 0)
        contentArea.Position = UDim2.new(0, 0, 0, 0)
        contentArea.BackgroundTransparency = 1
        contentArea.Parent = contentWrapper -- Parent ist jetzt contentWrapper
        contentArea.Visible = true -- IMMER sichtbar (Clipping wird durch Wrapper gesteuert)

        -- Auto-stack elements inside window with spacing
        local contentList = Instance.new('UIListLayout')
        contentList.Padding = UDim.new(0, 10)
        contentList.FillDirection = Enum.FillDirection.Vertical
        contentList.SortOrder = Enum.SortOrder.LayoutOrder
        contentList.Parent = contentArea
        
        -- ensure bottom spacing at end of window
        local contentPadding = Instance.new('UIPadding')
        contentPadding.PaddingBottom = UDim.new(0, 10)
        contentPadding.Parent = contentArea
        
        -- Wenn defaultExpanded, warte auf Höhenberechnung und setze Wrapper-Höhe
        if defaultExpanded then
            task.spawn(function()
                local RunService = game:GetService("RunService")
                
                for i = 1, 30 do
                    RunService.Heartbeat:Wait()
                    local height = 0
                    if contentList then
                        height = contentList.AbsoluteContentSize.Y
                    end
                    if height <= 0 then
                        height = contentArea.AbsoluteSize.Y
                    end
                    if height > 10 then
                        contentWrapper.Size = UDim2.new(1, -16, 0, height)
                        break
                    end
                end
            end)
        end

        -- Collapse State (basierend auf defaultExpanded)
        local isCollapsed = not defaultExpanded

        -- Funktion zum Setzen der Sichtbarkeit aller Content-Kinder
        local function setContentChildrenVisible(visible)
            for _, child in ipairs(contentArea:GetChildren()) do
                if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    child.Visible = visible
                end
            end
        end

        -- Alle bestehenden Elemente basierend auf defaultExpanded sichtbar/unsichtbar machen
        setContentChildrenVisible(defaultExpanded)

        -- Listener für neue Kinder: Wenn eingeklappt, neue Elemente automatisch unsichtbar machen
        contentArea.ChildAdded:Connect(function(child)
            if isCollapsed and child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                child.Visible = false
            end
        end)

        -- Collapse/Expand Funktion - Komplett neu mit Wrapper-Ansatz
        local function toggleCollapse()
            isCollapsed = not isCollapsed
            
            -- Pfeil rotieren
            local targetRotation = isCollapsed and 180 or 0
            TweenService:Create(collapseArrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                Rotation = targetRotation
            }):Play()
            
            if isCollapsed then
                -- ===== EINKLAPPEN =====
                -- Alle offenen Dropdowns und ColorPicker schließen
                local function closeAllExpandedElements()
                    -- Einfache und robuste Methode: Schließe ALLE Dropdowns und ColorPicker im window
                    for _, element in ipairs(window:GetChildren()) do
                        if element.Name == "DropdownMenu" or element.Name == "MultiDropdownMenu" then
                            if element.Visible then
                                element.Visible = false
                                -- Finde und rotiere zugehörigen Arrow zurück
                                for _, contentChild in ipairs(contentArea:GetChildren()) do
                                    local button = contentChild:FindFirstChild("DropdownButton") or contentChild:FindFirstChild("MultiDropdownButton")
                                    if button then
                                        local arrow = button:FindFirstChild("Arrow")
                                        if arrow then
                                            TweenService:Create(arrow, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Rotation = 0}):Play()
                                        end
                                    end
                                end
                            end
                        elseif element.Name == "ColorPickerPopup" then
                            element.Visible = false
                        elseif element.Name == "CustomScrollTrack" then
                            element.Visible = false
                        end
                    end
                end

                closeAllExpandedElements()

                -- Aktuelle Höhe des Wrappers
                local currentHeight = contentWrapper.AbsoluteSize.Y
                if currentHeight <= 0 then
                    contentWrapper.Visible = false
                    separator.Visible = false
                    setContentChildrenVisible(false)
                    return
                end
                
                -- Wrapper und Separator sichtbar für Animation
                contentWrapper.Visible = true
                separator.Visible = true
                separator.Size = UDim2.new(1, 0, 0, 1)
                separator.BackgroundTransparency = 0
                
                -- Elemente während Animation ausblenden
                task.spawn(function()
                    task.wait(0.1)
                    setContentChildrenVisible(false)
                end)
                
                -- Animation: Wrapper-Höhe auf 0
                local wrapperTween = TweenService:Create(contentWrapper, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Size = UDim2.new(1, -16, 0, 0)
                })
                
                local sepTween = TweenService:Create(separator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1
                })
                
                wrapperTween:Play()
                sepTween:Play()
                
                wrapperTween.Completed:Connect(function()
                    contentWrapper.Visible = false
                    separator.Visible = false
                    -- Window-Höhe auf nur Header reduzieren (30px)
                    window.AutomaticSize = Enum.AutomaticSize.None
                    window.Size = UDim2.new(1, 0, 0, 30)
                end)
                
            else
                -- ===== AUSKLAPPEN =====
                -- Window AutomaticSize wieder aktivieren für dynamische Höhe
                window.AutomaticSize = Enum.AutomaticSize.Y
                window.Size = UDim2.new(1, 0, 0, 0)

                -- Elemente sichtbar machen
                setContentChildrenVisible(true)
                contentWrapper.Visible = true
                separator.Visible = true
                separator.BackgroundTransparency = 0

                -- Wrapper auf 0 setzen für Animation
                contentWrapper.Size = UDim2.new(1, -16, 0, 0)
                separator.Size = UDim2.new(1, 0, 0, 0)
                
                -- Warte auf Höhenberechnung der Content Area
                task.spawn(function()
                    local RunService = game:GetService("RunService")
                    local contentList = contentArea:FindFirstChildOfClass("UIListLayout")
                    local targetHeight = 0
                    
                    -- Warte auf Berechnung (Content Area hat AutomaticSize aktiviert)
                    for i = 1, 30 do
                        RunService.Heartbeat:Wait()
                        
                        -- Versuche Höhe zu bekommen
                        if contentList then
                            targetHeight = contentList.AbsoluteContentSize.Y
                        end
                        if targetHeight <= 0 then
                            targetHeight = contentArea.AbsoluteSize.Y
                        end
                        
                        if targetHeight > 10 then
                            -- Höhe gefunden!
                            break
                        end
                    end
                    
                    -- Fallback wenn keine Höhe gefunden
                    if targetHeight <= 10 then
                        local childCount = 0
                        for _, child in ipairs(contentArea:GetChildren()) do
                            if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                                childCount = childCount + 1
                            end
                        end
                        targetHeight = math.max(childCount * 50, 50)
                    end
                    
                    -- Kurz warten für sauberen Start
                    task.wait(0.01)
                    
                    -- Animation: Wrapper von 0 auf Zielhöhe
                    local wrapperTween = TweenService:Create(contentWrapper, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, -16, 0, targetHeight)
                    })
                    
                    local sepTween = TweenService:Create(separator, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Size = UDim2.new(1, 0, 0, 1),
                        BackgroundTransparency = 0
                    })
                    
                    wrapperTween:Play()
                    sepTween:Play()
                end)
            end
        end

        -- Collapse Button Click Event
        collapseButton.MouseButton1Click:Connect(function()
            toggleCollapse()
        end)
        
        -- Mobile Touch Support für Collapse Button
        if self.mobileLayout.isMobile then
            collapseButton.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(collapseButton, TweenInfo.new(0.1), {
                        BackgroundTransparency = 0.8,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    }):Play()
                end
            end)
            
            collapseButton.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(collapseButton, TweenInfo.new(0.2), {
                        BackgroundTransparency = 1
                    }):Play()
                end
            end)
        end

        -- Return Window Object mit UI Elementen
        local windowObj = {
            frame = window,
            content = contentArea,
            library = self,
            _nextY = 0,
            _column = 1, -- default column index (1 or 2)
            _autoSize = true,
            _isCollapsed = false,
            Collapse = function(self)
                if not isCollapsed then
                    toggleCollapse()
                    self._isCollapsed = true
                end
            end,
            Expand = function(self)
                if isCollapsed then
                    toggleCollapse()
                    self._isCollapsed = false
                end
            end,
            ToggleCollapse = function(self)
                toggleCollapse()
                self._isCollapsed = isCollapsed
            end
        }
        
        -- UI Element Creation Methods (unterstützt beide Syntaxen: einfach und Tabellen)
        function windowObj:CreateCheckbox(textOrTable, defaultOrNil, callbackOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Default = false, Callback = function...}
                local text = textOrTable.Title or textOrTable.title or ""
                local default = textOrTable.Default or textOrTable.default or false
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                return self.library:_createCheckbox(self, text, default, callback)
            else
                -- Einfache Syntax: CreateCheckbox("Text", false, function...)
                return self.library:_createCheckbox(self, textOrTable, defaultOrNil, callbackOrNil)
            end
        end
        
        function windowObj:CreateSlider(textOrTable, minOrNil, maxOrNil, defaultOrNil, callbackOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Min = 1, Max = 100, Default = 50, Callback = function...}
                local text = textOrTable.Title or textOrTable.title or ""
                local min = textOrTable.Min or textOrTable.min or 0
                local max = textOrTable.Max or textOrTable.max or 100
                local default = textOrTable.Default or textOrTable.default or min
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                return self.library:_createSlider(self, text, min, max, default, callback)
            else
                -- Einfache Syntax: CreateSlider("Text", 1, 100, 50, function...)
                return self.library:_createSlider(self, textOrTable, minOrNil, maxOrNil, defaultOrNil, callbackOrNil)
            end
        end
        
        function windowObj:CreateDropdown(textOrTable, optionsOrNil, defaultOrNil, callbackOrNil, enableSearchOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Options = {...}, Default = "...", Callback = function..., EnableSearch = true/false}
                local text = textOrTable.Title or textOrTable.title or ""
                local options = textOrTable.Options or textOrTable.options or {}
                local default = textOrTable.Default or textOrTable.default or (options[1] or "")
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                local enableSearch = textOrTable.EnableSearch or textOrTable.enableSearch or false
                return self.library:_createDropdown(self, text, options, default, callback, enableSearch)
            else
                -- Einfache Syntax: CreateDropdown("Text", {...}, "...", function..., enableSearch)
                local enableSearch = enableSearchOrNil or false
                return self.library:_createDropdown(self, textOrTable, optionsOrNil, defaultOrNil, callbackOrNil, enableSearch)
            end
        end
        
        function windowObj:CreateMultiDropdown(textOrTable, optionsOrNil, defaultsOrNil, callbackOrNil, enableSearchOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Options = {...}, Default = {...}, Callback = function..., EnableSearch = true/false}
                local text = textOrTable.Title or textOrTable.title or ""
                local options = textOrTable.Options or textOrTable.options or {}
                local defaults = textOrTable.Default or textOrTable.default or {}
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                local enableSearch = textOrTable.EnableSearch or textOrTable.enableSearch or false
                return self.library:_createMultiDropdown(self, text, options, defaults, callback, enableSearch)
            else
                -- Einfache Syntax: CreateMultiDropdown("Text", {...}, {...}, function..., enableSearch)
                local enableSearch = enableSearchOrNil or false
                return self.library:_createMultiDropdown(self, textOrTable, optionsOrNil, defaultsOrNil, callbackOrNil, enableSearch)
            end
        end
        
        function windowObj:CreateColorPicker(textOrTable, defaultOrNil, callbackOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Default = Color3, Callback = function...}
                local text = textOrTable.Title or textOrTable.title or ""
                local default = textOrTable.Default or textOrTable.default or Color3.fromRGB(110, 117, 243)
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                return self.library:_createColorPicker(self, text, default, callback)
            else
                -- Einfache Syntax: CreateColorPicker("Text", Color3, function...)
                return self.library:_createColorPicker(self, textOrTable, defaultOrNil, callbackOrNil)
            end
        end
        
        function windowObj:CreateButton(textOrTable, callbackOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Callback = function...}
                local text = textOrTable.Title or textOrTable.title or ""
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                return self.library:_createButton(self, text, callback)
            else
                -- Einfache Syntax: CreateButton("Text", function...)
                return self.library:_createButton(self, textOrTable, callbackOrNil)
            end
        end
        
        function windowObj:CreateTextBox(textOrTable, placeholderOrNil, callbackOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Placeholder = "...", Callback = function...}
                local text = textOrTable.Title or textOrTable.title or ""
                local placeholder = textOrTable.Placeholder or textOrTable.placeholder or "Enter text..."
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                return self.library:_createTextBox(self, text, placeholder, callback)
            else
                -- Einfache Syntax: CreateTextBox("Text", "...", function...)
                return self.library:_createTextBox(self, textOrTable, placeholderOrNil, callbackOrNil)
            end
        end
        
        function windowObj:CreateKeybind(textOrTable, defaultOrNil, callbackOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Title = "...", Default = "...", Callback = function...}
                local text = textOrTable.Title or textOrTable.title or ""
                local default = textOrTable.Default or textOrTable.default or "None"
                local callback = textOrTable.Callback or textOrTable.callback or function() end
                return self.library:_createKeybind(self, text, default, callback)
            else
                -- Einfache Syntax: CreateKeybind("Text", "...", function...)
                return self.library:_createKeybind(self, textOrTable, defaultOrNil, callbackOrNil)
            end
        end
        
        function windowObj:CreateDescription(textOrTable, wrapOrNil)
            if type(textOrTable) == "table" then
                -- Tabellen-Syntax: {Text = "...", WrapText = true/false}
                local text = textOrTable.Text or textOrTable.text or ""
                local wrapText = textOrTable.WrapText or textOrTable.wrapText or textOrTable.Wrap or textOrTable.wrap
                if wrapText == nil then wrapText = true end -- Default: wrap text
                return self.library:_createDescription(self, text, wrapText)
            else
                -- Einfache Syntax: CreateDescription("Text", wrapText)
                local wrapText = wrapOrNil
                if wrapText == nil then wrapText = true end -- Default: wrap text
                return self.library:_createDescription(self, textOrTable, wrapText)
            end
        end

        -- Place window into a column if parent is a tab content frame
        local columns = self._columnsByContentFrame[parent]
        if columns then
            local targetCol = (columns.col1.AbsoluteSize.Y <= columns.col2.AbsoluteSize.Y) and columns.col1 or columns.col2
            window.Parent = targetCol
        end

        return windowObj
    end

    -- UI Elements
    function ModernUI:_createCheckbox(window, text, default, callback)
        default = default or false
        callback = callback or function() end
        
        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, checkboxSize, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.max(25, math.floor(30 * self.mobileLayout.scale))
            checkboxSize = math.max(18, math.floor(22 * self.mobileLayout.scale))
            spacing = math.max(30, math.floor(38 * self.mobileLayout.scale))
        else
            -- PC: Original-Größen
            containerHeight = 25
            checkboxSize = 18
            spacing = 30
        end
        
        local container = Instance.new('Frame')
        container.Name = 'CheckboxContainer'
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        
        window._nextY = window._nextY + spacing

        local checkbox = Instance.new('ImageButton')
        checkbox.Name = 'Checkbox'
        checkbox.Size = UDim2.new(0, checkboxSize, 0, checkboxSize)
        checkbox.Position = UDim2.new(0, 0, 0.5, -checkboxSize/2)
        checkbox.BackgroundColor3 = self.options.theme.surface
        checkbox.BorderSizePixel = 0
        checkbox.Image = ''
        checkbox.Parent = container

        local checkIcon = Instance.new('ImageLabel')
        checkIcon.Name = 'CheckIcon'
        checkIcon.Size = UDim2.new(0, 12, 0, 12)
        checkIcon.Position = UDim2.new(0.5, -6, 0.5, -5)
        checkIcon.BackgroundTransparency = 1
        checkIcon.Image = ''
        checkIcon.ImageColor3 = Color3.fromRGB(0, 0, 0)
        checkIcon.Parent = checkbox

        local checkboxCorner = Instance.new('UICorner')
        checkboxCorner.CornerRadius = UDim.new(0, 3)
        checkboxCorner.Parent = checkbox

        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.new(1, -25, 1, 0)
        label.Position = UDim2.new(0, 25, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.options.theme.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Font = Enum.Font.Gotham
        label.TextSize = math.max(9, math.floor(12 * self.mobileLayout.scale)) -- Skalierte Textgröße
        label.Parent = container

        local enabled = default

        local function updateCheckbox()
            if enabled then
                checkbox.BackgroundColor3 = self.options.theme.primary
                checkIcon.Image = 'rbxassetid://98902844787044'
            else
                checkbox.BackgroundColor3 = self.options.theme.surface
                checkIcon.Image = ''
            end
        end

        -- Enhanced click/touch support
        checkbox.MouseButton1Click:Connect(function()
            enabled = not enabled
            updateCheckbox()
            callback(enabled)
        end)
        
        -- Mobile touch feedback
        if self.mobileLayout.isMobile then
            checkbox.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(checkbox, TweenInfo.new(0.1), {
                        Size = UDim2.new(0, checkboxSize * 0.9, 0, checkboxSize * 0.9)
                    }):Play()
                end
            end)
            
            checkbox.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    TweenService:Create(checkbox, TweenInfo.new(0.2), {
                        Size = UDim2.new(0, checkboxSize, 0, checkboxSize)
                    }):Play()
                end
            end)
        end

        updateCheckbox()

        -- Register theme updater to refresh colors in real time when theme changes
        table.insert(self._themeRefs.checkboxUpdaters, function()
            updateCheckbox()
        end)

        local api = {
            SetValue = function(value)
                enabled = value
                updateCheckbox()
            end,
            GetValue = function()
                return enabled
            end
        }
        
        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            -- Tab und Window Namen aus dem Parent-Frame ermitteln
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("checkbox", tabName, windowName, text, api, callback)
        end
        
        return api
    end

    function ModernUI:_createMultiDropdown(window, text, options, defaults, callback, enableSearch)
        options = options or {}
        defaults = defaults or {}
        callback = callback or function() end
        enableSearch = enableSearch or false

        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.floor(58 * self.mobileLayout.scale)
            spacing = math.floor(66 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            containerHeight = 48
            spacing = 55
        end
        
        local container = Instance.new('Frame')
        container.Name = 'MultiDropdownContainer'
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        window._nextY = window._nextY + spacing

        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.new(1, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text or 'Select'
        label.TextColor3 = self.options.theme.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = math.max(9, math.floor(12 * self.mobileLayout.scale)) -- Skalierte Textgröße
        label.Parent = container

        local button = Instance.new('TextButton')
        button.Name = 'MultiDropdownButton'
        button.Size = UDim2.new(1, 0, 0, 25)
        button.Position = UDim2.new(0, 0, 0, 22)
        button.BackgroundColor3 = self.options.theme.surface
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.TextTruncate = Enum.TextTruncate.AtEnd
        button.Text = ''
        button.TextColor3 = self.options.theme.text
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.TextYAlignment = Enum.TextYAlignment.Center
        button.Font = Enum.Font.Gotham
        button.TextSize = 11
        button.ClipsDescendants = false
        button.Parent = container

        local btnCorner = Instance.new('UICorner')
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = button

        local btnPadding = Instance.new('UIPadding')
        btnPadding.PaddingLeft = UDim.new(0, 10)
        btnPadding.PaddingRight = UDim.new(0, 12)
        btnPadding.Parent = button

        local arrow = Instance.new('ImageButton')
        arrow.Name = 'Arrow'
        arrow.Size = UDim2.new(0, 20, 0, 20)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, 10, 0.5, 0)
        arrow.BackgroundTransparency = 1
        arrow.Image = 'rbxassetid://116164752384094'
        arrow.ImageColor3 = self.options.theme.text
        arrow.ZIndex = 60
        arrow.AutoButtonColor = false
        arrow.Active = true
        arrow.Parent = button

        local menu = Instance.new('ScrollingFrame')
        menu.Name = 'MultiDropdownMenu'
        menu.Size = UDim2.new(0, 0, 0, 150)
        menu.BackgroundColor3 = self.options.theme.surface
        menu.BorderSizePixel = 0
        menu.Visible = false
        menu.ZIndex = 50 -- Wird dynamisch beim Öffnen erhöht
        menu.ScrollBarThickness = 0
        menu.ScrollingDirection = Enum.ScrollingDirection.Y
        menu.ElasticBehavior = Enum.ElasticBehavior.Never
        menu.CanvasSize = UDim2.new(0, 0, 0, 0)
        menu.Parent = window.frame

        local maxMenuHeight = 150
        local menuCorner = Instance.new('UICorner')
        menuCorner.CornerRadius = UDim.new(0, 4)
        menuCorner.Parent = menu
        local isOpen = false
        -- Track open state early so option handlers close correctly
        local isOpen = false

        local scrollTrack = Instance.new('Frame')
        scrollTrack.Name = 'CustomScrollTrack'
        scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
        scrollTrack.Position = UDim2.new(0, 0, 0, 0)
        scrollTrack.BackgroundTransparency = 1
        scrollTrack.BorderSizePixel = 0
        scrollTrack.ZIndex = 200
        scrollTrack.Visible = false
        scrollTrack.Parent = window.frame

        local scrollThumb = Instance.new('Frame')
        scrollThumb.Name = 'Thumb'
        scrollThumb.Size = UDim2.new(1, 0, 0, 24)
        scrollThumb.Position = UDim2.new(0, 0, 0, 0)
        scrollThumb.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
        scrollThumb.BorderSizePixel = 0
        scrollThumb.ZIndex = 52
        scrollThumb.Parent = scrollTrack

        local thumbCorner = Instance.new('UICorner')
        thumbCorner.CornerRadius = UDim.new(0, 3)
        thumbCorner.Parent = scrollThumb

        local selectedMap = {}
        for _, d in ipairs(defaults) do selectedMap[tostring(d)] = true end

        local function computeButtonText()
            local names = {}
            for _, name in ipairs(options) do
                if selectedMap[tostring(name)] then table.insert(names, tostring(name)) end
            end
            if #names == 0 then return 'None' end
            local text = table.concat(names, ', ')
            if #text > 22 then return tostring(#names) .. ' selected' end
            return text
        end
        button.Text = computeButtonText()

        local function syncMenuPlacement()
            local parentAbs = window.frame.AbsolutePosition
            local btnAbs = button.AbsolutePosition
            local xOffset = btnAbs.X - parentAbs.X
            local yOffset = (btnAbs.Y - parentAbs.Y) + button.AbsoluteSize.Y + 2
            menu.Position = UDim2.new(0, xOffset, 0, yOffset)
            menu.Size = UDim2.new(0, button.AbsoluteSize.X, 0, maxMenuHeight)
            scrollTrack.Position = UDim2.new(0, xOffset + menu.AbsoluteSize.X - 6, 0, yOffset)
            scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
            arrow.Position = UDim2.new(1, 10, 0.5, 0)
        end
        syncMenuPlacement()
        button:GetPropertyChangedSignal('AbsoluteSize'):Connect(syncMenuPlacement)
        button:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)
        window.frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)

        local function updateMenuCanvas()
            local optionHeight = 30
            local offsetY = enableSearch and 38 or 6
            menu.CanvasSize = UDim2.new(0, 0, 0, (#options * (optionHeight + 2)) + offsetY + 6)
        end

        -- Sync scrollbar with canvas position changes (Funktion bereits oben definiert)
        menu:GetPropertyChangedSignal('CanvasPosition'):Connect(updateCustomScrollbar)
        menu:GetPropertyChangedSignal('AbsoluteSize'):Connect(updateCustomScrollbar)
        menu:GetPropertyChangedSignal('CanvasSize'):Connect(updateCustomScrollbar)

        local draggingThumb = false
        local dragStartY = 0
        local thumbStartY = 0
        
        -- Enhanced thumb dragging with mobile support
        scrollThumb.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingThumb = true
                dragStartY = input.Position.Y
                thumbStartY = scrollThumb.AbsolutePosition.Y
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingThumb and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local visibleHeight = menu.AbsoluteSize.Y
                local contentHeight = menu.CanvasSize.Y.Offset
                local trackHeight = visibleHeight
                local thumbHeight = scrollThumb.AbsoluteSize.Y
                local maxThumbY = trackHeight - thumbHeight
                local deltaY = input.Position.Y - dragStartY
                local newThumbY = math.clamp((thumbStartY - scrollTrack.AbsolutePosition.Y) + deltaY, 0, maxThumbY)
                scrollThumb.Position = UDim2.new(0, 0, 0, newThumbY)
                local maxScroll = math.max(0, contentHeight - visibleHeight)
                local newRatio = (maxThumbY > 0) and (newThumbY / maxThumbY) or 0
                menu.CanvasPosition = Vector2.new(0, newRatio * maxScroll)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingThumb = false
            end
        end)

        local optionButtons = {}
        local optionFrames = {} -- Speichere alle Option-Frames für Filterung
        local optionHeight = 30
        local searchText = ""

        -- Scrollbar Update-Funktion (muss VOR filterOptions definiert werden)
        local function updateCustomScrollbar()
            local visibleHeight = menu.AbsoluteSize.Y
            local contentHeight = menu.CanvasSize.Y.Offset
            if contentHeight <= visibleHeight then
                scrollTrack.Visible = false
                return
            end
            scrollTrack.Visible = menu.Visible
            local trackHeight = visibleHeight
            local minThumb = 20
            local thumbHeight = math.clamp(math.floor((visibleHeight / contentHeight) * trackHeight), minThumb, trackHeight)
            scrollThumb.Size = UDim2.new(1, 0, 0, thumbHeight)
            local maxScroll = math.max(0, contentHeight - visibleHeight)
            local ratio = (maxScroll > 0) and (menu.CanvasPosition.Y / maxScroll) or 0
            ratio = math.clamp(ratio, 0, 1) -- Ensure ratio is valid
            local thumbY = math.floor(ratio * (trackHeight - thumbHeight))
            scrollThumb.Position = UDim2.new(0, 0, 0, thumbY)
        end

        -- Suchleiste erstellen (wenn enableSearch aktiviert)
        local searchBox = nil
        if enableSearch then
            searchBox = Instance.new('TextBox')
            searchBox.Name = 'SearchBox'
            searchBox.Size = UDim2.new(1, -10, 0, 28)
            searchBox.Position = UDim2.new(0, 5, 0, 6)
            searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            searchBox.BorderSizePixel = 0
            searchBox.Text = ""
            searchBox.PlaceholderText = "Search..."
            searchBox.TextColor3 = self.options.theme.text
            searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
            searchBox.TextXAlignment = Enum.TextXAlignment.Left
            searchBox.Font = Enum.Font.Gotham
            searchBox.TextSize = 11
            searchBox.ClearTextOnFocus = false
            searchBox.Parent = menu
            
            local searchCorner = Instance.new('UICorner')
            searchCorner.CornerRadius = UDim.new(0, 3)
            searchCorner.Parent = searchBox
            
            local searchPadding = Instance.new('UIPadding')
            searchPadding.PaddingLeft = UDim.new(0, 8)
            searchPadding.PaddingRight = UDim.new(0, 8)
            searchPadding.Parent = searchBox
            
            -- Filter-Funktion
            local function filterOptions()
                local searchLower = string.lower(searchText)
                local visibleCount = 0
                local offsetY = enableSearch and 38 or 6
                
                -- Zuerst alle Optionen filtern
                for i, option in ipairs(options) do
                    local optionFrame = optionFrames[option]
                    if optionFrame then
                        local optionStr = string.lower(tostring(option))
                        local isVisible = searchText == "" or string.find(optionStr, searchLower, 1, true) ~= nil
                        optionFrame.Visible = isVisible
                    end
                end
                
                -- Dann Positionen basierend auf sichtbaren Optionen setzen
                local visibleIndex = 0
                for i, option in ipairs(options) do
                    local optionFrame = optionFrames[option]
                    if optionFrame and optionFrame.Visible then
                        visibleIndex = visibleIndex + 1
                        visibleCount = visibleCount + 1
                        optionFrame.Position = UDim2.new(0, 5, 0, (visibleIndex - 1) * (optionHeight + 2) + offsetY)
                    end
                end
                
                -- Canvas-Größe aktualisieren
                menu.CanvasSize = UDim2.new(0, 0, 0, (visibleCount * (optionHeight + 2)) + offsetY + 6)
                updateCustomScrollbar()
            end
            
            -- Suchtext-Änderung überwachen
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                searchText = searchBox.Text
                filterOptions()
            end)
        end
        
        for i, option in ipairs(options) do
            local optionFrame = Instance.new('Frame')
            optionFrame.Name = tostring(option) .. 'Option'
            optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
            local offsetY = enableSearch and 38 or 6
            optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + offsetY)
            optionFrame.BackgroundTransparency = 1
            optionFrame.Parent = menu
            optionFrames[option] = optionFrame -- Speichere Frame für Filterung

            local optionButton = Instance.new('TextButton')
            optionButton.Name = 'Button'
            optionButton.Size = UDim2.new(1, 0, 1, 0)
            optionButton.BackgroundColor3 = self.options.theme.primary
            optionButton.BackgroundTransparency = selectedMap[tostring(option)] and 0 or 1
            optionButton.BorderSizePixel = 0
            optionButton.AutoButtonColor = false
            optionButton.Text = tostring(option)
            optionButton.TextColor3 = selectedMap[tostring(option)] and self.options.theme.textDark or self.options.theme.text
            optionButton.TextXAlignment = Enum.TextXAlignment.Left
            optionButton.Font = Enum.Font.Gotham
            optionButton.TextSize = 11
            optionButton.Parent = optionFrame
            optionButtons[tostring(option)] = optionButton
            table.insert(self._themeRefs.multiDropdownOptionButtons, optionButton)

            local optionCorner = Instance.new('UICorner')
            optionCorner.CornerRadius = UDim.new(0, 3)
            optionCorner.Parent = optionButton

            local optionPadding = Instance.new('UIPadding')
            optionPadding.PaddingLeft = UDim.new(0, 8)
            optionPadding.Parent = optionButton

            optionButton.MouseButton1Click:Connect(function()
                local key = tostring(option)
                selectedMap[key] = not selectedMap[key]
                local isOn = selectedMap[key]
                optionButton.BackgroundTransparency = isOn and 0 or 1
                if isOn then optionButton.BackgroundColor3 = self.options.theme.primary end
                optionButton.TextColor3 = isOn and self.options.theme.textDark or self.options.theme.text
                button.Text = computeButtonText()
                callback(selectedMap)
            end)
        end
        updateMenuCanvas()
        updateCustomScrollbar()

        local function toggleMenu()
            isOpen = not isOpen
            syncMenuPlacement()
            
            -- Z-Index dynamisch erhöhen, damit obere Dropdowns untere überdecken
            if isOpen then
                self._dropdownZIndexCounter = self._dropdownZIndexCounter + 1
                menu.ZIndex = self._dropdownZIndexCounter
                scrollTrack.ZIndex = self._dropdownZIndexCounter + 150 -- Scrollbar über Menu
            end
            
            menu.Visible = isOpen
            scrollTrack.Visible = isOpen and (menu.CanvasSize.Y.Offset > menu.AbsoluteSize.Y)
            updateCustomScrollbar()
            local rotation = isOpen and 180 or 0
            TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = rotation}):Play()
            
            -- Suchleiste zurücksetzen beim Öffnen
            if isOpen and enableSearch and searchBox then
                searchBox.Text = ""
                searchText = ""
                -- Alle Optionen wieder sichtbar machen und Positionen zurücksetzen
                for i, option in ipairs(options) do
                    local optionFrame = optionFrames[option]
                    if optionFrame then
                        optionFrame.Visible = true
                        local offsetY = enableSearch and 38 or 6
                        optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + offsetY)
                    end
                end
                updateMenuCanvas()
                menu.CanvasPosition = Vector2.new(0, 0) -- Zurück zum Anfang scrollen
            end
        end
        
        -- Flag um doppeltes Toggle zu verhindern
        local arrowClicked = false
        
        button.MouseButton1Click:Connect(function()
            -- Prüfe ob Arrow geklickt wurde (dann ignorieren)
            if arrowClicked then
                arrowClicked = false
                return
            end
            -- Force open on first click if closed
            if not menu.Visible then
                isOpen = false
            end
            toggleMenu()
        end)
        
        -- Arrow-Handler: Setzt Flag, damit Button-Handler nicht auch ausgelöst wird
        arrow.MouseButton1Click:Connect(function()
            arrowClicked = true
            if not menu.Visible then isOpen = false end
            toggleMenu()
            -- Flag nach kurzer Zeit zurücksetzen
            task.spawn(function()
                task.wait(0.1)
                arrowClicked = false
            end)
        end)

        local api = {}
        function api.GetValue()
            return selectedMap
        end
        function api.SetValue(map)
            if type(map) ~= 'table' then return end
            selectedMap = {}
            for k,v in pairs(map) do if v then selectedMap[tostring(k)] = true end end
            for _, opt in ipairs(options) do
                local btn = optionButtons[tostring(opt)]
                if btn then
                    local isOn = selectedMap[tostring(opt)]
                    btn.BackgroundTransparency = isOn and 0 or 1
                    btn.TextColor3 = isOn and self.options.theme.textDark or self.options.theme.text
                end
            end
            button.Text = computeButtonText()
            callback(selectedMap)
        end
        function api.SetOptions(newOptions)
            for _, btn in pairs(optionButtons) do
                if btn and btn.Parent then
                    btn.Parent:Destroy()
                end
            end
            optionButtons = {}
            options = newOptions or {}
            updateMenuCanvas()
            for i, option in ipairs(options) do
                local optionFrame = Instance.new('Frame')
                optionFrame.Name = tostring(option) .. 'Option'
                optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
                optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + 6)
                optionFrame.BackgroundTransparency = 1
                optionFrame.Parent = menu

                local optionButton = Instance.new('TextButton')
                optionButton.Name = 'Button'
                optionButton.Size = UDim2.new(1, 0, 1, 0)
                optionButton.BackgroundColor3 = self.options.theme.primary
                optionButton.BackgroundTransparency = selectedMap[tostring(option)] and 0 or 1
                optionButton.BorderSizePixel = 0
                optionButton.AutoButtonColor = false
                optionButton.Text = tostring(option)
                optionButton.TextColor3 = selectedMap[tostring(option)] and self.options.theme.textDark or self.options.theme.text
                optionButton.TextXAlignment = Enum.TextXAlignment.Left
                optionButton.Font = Enum.Font.Gotham
                optionButton.TextSize = 11
                optionButton.Parent = optionFrame
                optionButtons[tostring(option)] = optionButton
                table.insert(self._themeRefs.multiDropdownOptionButtons, optionButton)

                local optionCorner = Instance.new('UICorner')
                optionCorner.CornerRadius = UDim.new(0, 3)
                optionCorner.Parent = optionButton

                local optionPadding = Instance.new('UIPadding')
                optionPadding.PaddingLeft = UDim.new(0, 8)
                optionPadding.Parent = optionButton

                optionButton.MouseButton1Click:Connect(function()
                    local key = tostring(option)
                    selectedMap[key] = not selectedMap[key]
                    local isOn = selectedMap[key]
                    optionButton.BackgroundTransparency = isOn and 0 or 1
                    optionButton.TextColor3 = isOn and self.options.theme.textDark or self.options.theme.text
                    button.Text = computeButtonText()
                    callback(selectedMap)
                end)
            end
            updateCustomScrollbar()
            button.Text = computeButtonText()
        end

        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("multidropdown", tabName, windowName, text, api, callback)
        end

        return api
    end

    function ModernUI:_createSlider(window, text, min, max, default, callback)
        min = min or 0
        max = max or 100
        default = default or min
        callback = callback or function() end

        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.floor(60 * self.mobileLayout.scale)
            spacing = math.floor(68 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            containerHeight = 50
            spacing = 55
        end
        
        local container = Instance.new('Frame')
        container.Name = 'SliderContainer'
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        
        window._nextY = window._nextY + spacing

        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.new(0.6, 0, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.options.theme.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = math.max(9, math.floor(12 * self.mobileLayout.scale)) -- Skalierte Textgröße
        label.Parent = container

        local valueLabel = Instance.new('TextLabel')
        valueLabel.Name = 'ValueLabel'
        valueLabel.Size = UDim2.new(0.4, 0, 0, 20)
        valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = tostring(math.floor(default))
        valueLabel.TextColor3 = self.options.theme.text
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Font = Enum.Font.Gotham
        valueLabel.TextSize = 12
        valueLabel.Parent = container

        local track = Instance.new('Frame')
        track.Name = 'Track'
        track.Size = UDim2.new(1, 0, 0, 12)
        track.Position = UDim2.new(0, 0, 0, 28)
        track.BackgroundColor3 = self.options.theme.surface
        track.BorderSizePixel = 0
        track.Parent = container

        local trackCorner = Instance.new('UICorner')
        trackCorner.CornerRadius = UDim.new(0, 2)
        trackCorner.Parent = track

        local fill = Instance.new('Frame')
        fill.Name = 'Fill'
        fill.Size = UDim2.new(0, 0, 1, 0)
        fill.BackgroundColor3 = self.options.theme.primary
        fill.BorderSizePixel = 0
        fill.Parent = track

        table.insert(self._themeRefs.sliderFills, fill)

        local fillCorner = Instance.new('UICorner')
        fillCorner.CornerRadius = UDim.new(0, 2)
        fillCorner.Parent = fill

        local value = default
        local dragging = false

        local function updateSlider()
            local percentage = (value - min) / (max - min)
            local tween = TweenService:Create(fill, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {
                Size = UDim2.new(percentage, 0, 1, 0)
            })
            tween:Play()
            valueLabel.Text = tostring(math.floor(value))
        end

        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                value = min + (relativeX * (max - min))
                updateSlider()
                callback(value)
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local relativeX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                value = min + (relativeX * (max - min))
                updateSlider()
                callback(value)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        updateSlider()

        local api = {
            SetValue = function(newValue)
                value = math.clamp(newValue, min, max)
                updateSlider()
            end,
            GetValue = function()
                return value
            end
        }
        
        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("slider", tabName, windowName, text, api, callback)
        end
        
        return api
    end

    function ModernUI:_createButton(window, text, callback)
        callback = callback or function() end

        -- PC: Original-Größen, Mobile: Skaliert
        local buttonHeight, spacing, textSize
        if self.mobileLayout.isMobile then
            buttonHeight = math.floor(40 * self.mobileLayout.scale)
            spacing = math.floor(48 * self.mobileLayout.scale)
            textSize = math.max(10, math.floor(14 * self.mobileLayout.scale))
        else
            -- PC: Original-Größen
            buttonHeight = 32
            spacing = 40
            textSize = 14
        end
        
        local button = Instance.new('TextButton')
        button.Name = 'Button'
        button.Size = UDim2.new(1, 0, 0, buttonHeight)
        button.Position = UDim2.new(0, 0, 0, window._nextY)
        button.BackgroundColor3 = self.options.theme.surface
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = text
        button.Font = Enum.Font.Gotham
        button.TextSize = textSize
        button.TextColor3 = self.options.theme.text
        button.Parent = window.content
        
        window._nextY = window._nextY + spacing

        local buttonCorner = Instance.new('UICorner')
        buttonCorner.CornerRadius = UDim.new(0, 5)
        buttonCorner.Parent = button

        -- Match Radiant GUI exactly: immediate flash on press (mouse/touch), smooth fade back on release; callback on click
        local baseButtonBg = button.BackgroundColor3
        local baseButtonText = button.TextColor3
        local bgTween = nil
        local textTween = nil

        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if bgTween then bgTween:Cancel() end
                if textTween then textTween:Cancel() end
                button.BackgroundColor3 = self.options.theme.primary
                button.TextColor3 = self.options.theme.textDark
            end
        end)

        button.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if bgTween then bgTween:Cancel() end
                if textTween then textTween:Cancel() end
                bgTween = TweenService:Create(button, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    BackgroundColor3 = baseButtonBg
                })
                textTween = TweenService:Create(button, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    TextColor3 = baseButtonText
                })
                bgTween:Play()
                textTween:Play()
            end
        end)

        button.MouseButton1Click:Connect(function()
            callback()
        end)

        local api = {
            SetText = function(newText)
                button.Text = newText
            end,
            GetValue = function()
                return button.Text
            end,
            SetValue = function(newText)
                button.Text = newText
            end
        }
        
        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("button", tabName, windowName, text, api, callback)
        end
        
        return api
    end

    -- Simple implementations für andere UI Elemente
    function ModernUI:_createDropdown(window, text, options, default, callback, enableSearch)
        options = options or {}
        callback = callback or function() end
        enableSearch = enableSearch or false

        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.floor(58 * self.mobileLayout.scale)
            spacing = math.floor(66 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            containerHeight = 48
            spacing = 55
        end
        
        local container = Instance.new('Frame')
        container.Name = 'DropdownContainer'
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        window._nextY = window._nextY + spacing
        
        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Text = text or 'Select'
        label.TextColor3 = self.options.theme.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = math.max(9, math.floor(12 * self.mobileLayout.scale)) -- Skalierte Textgröße
        label.Parent = container

        local button = Instance.new('TextButton')
        button.Name = 'DropdownButton'
        button.Size = UDim2.new(1, 0, 0, 25)
        button.Position = UDim2.new(0, 0, 0, 22)
        button.BackgroundColor3 = self.options.theme.surface
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.TextTruncate = Enum.TextTruncate.AtEnd
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.TextYAlignment = Enum.TextYAlignment.Center
        button.Font = Enum.Font.Gotham
        button.TextSize = 11
        button.TextColor3 = self.options.theme.text
        button.ClipsDescendants = false
        button.Parent = container
        
        local btnCorner = Instance.new('UICorner')
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = button

        local btnPadding = Instance.new('UIPadding')
        btnPadding.PaddingLeft = UDim.new(0, 10)
        btnPadding.PaddingRight = UDim.new(0, 12)
        btnPadding.Parent = button

        local arrow = Instance.new('ImageButton')
        arrow.Name = 'Arrow'
        arrow.Size = UDim2.new(0, 16, 0, 16)
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, 10, 0.5, 0)
        arrow.BackgroundTransparency = 1
        arrow.Image = 'rbxassetid://128488479848041'
        arrow.ImageColor3 = self.options.theme.text
        arrow.ZIndex = 60
        arrow.AutoButtonColor = false
        arrow.Active = true
        arrow.Parent = button

        -- Overlay menu on the window for proper placement
        local menu = Instance.new('ScrollingFrame')
        menu.Name = 'DropdownMenu'
        menu.Size = UDim2.new(0, 0, 0, 150)
        menu.BackgroundColor3 = self.options.theme.surface
        menu.BorderSizePixel = 0
        menu.Visible = false
        menu.ZIndex = 50 -- Wird dynamisch beim Öffnen erhöht
        menu.ScrollBarThickness = 0
        menu.ScrollingDirection = Enum.ScrollingDirection.Y
        menu.ElasticBehavior = Enum.ElasticBehavior.Never
        menu.CanvasSize = UDim2.new(0, 0, 0, 0)
        menu.Parent = window.frame

        local maxMenuHeight = 150
        local menuCorner = Instance.new('UICorner')
        menuCorner.CornerRadius = UDim.new(0, 4)
        menuCorner.Parent = menu

        -- Custom slim scrollbar (visible only on overflow)
        local scrollTrack = Instance.new('Frame')
        scrollTrack.Name = 'CustomScrollTrack'
        scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
        scrollTrack.Position = UDim2.new(0, 0, 0, 0)
        scrollTrack.BackgroundTransparency = 1
        scrollTrack.BorderSizePixel = 0
        scrollTrack.ZIndex = 200
        scrollTrack.Visible = false
        scrollTrack.Parent = window.frame

        local scrollThumb = Instance.new('Frame')
        scrollThumb.Name = 'Thumb'
        scrollThumb.Size = UDim2.new(1, 0, 0, 24)
        scrollThumb.Position = UDim2.new(0, 0, 0, 0)
        scrollThumb.BackgroundColor3 = Color3.fromRGB(120, 120, 130)
        scrollThumb.BorderSizePixel = 0
        scrollThumb.ZIndex = 52
        scrollThumb.Parent = scrollTrack

        local thumbCorner = Instance.new('UICorner')
        thumbCorner.CornerRadius = UDim.new(0, 3)
        thumbCorner.Parent = scrollThumb

        local selected = default or options[1] or 'Select...'
        button.Text = tostring(selected)

        local optionButtons = {}
        local optionFrames = {} -- Speichere alle Option-Frames für Filterung
        local optionHeight = 30
        local searchText = ""

        -- Scrollbar Update-Funktion (muss VOR filterOptions definiert werden)
        local function updateCustomScrollbar()
            local visibleHeight = menu.AbsoluteSize.Y
            local contentHeight = menu.CanvasSize.Y.Offset
            if contentHeight <= visibleHeight then
                scrollTrack.Visible = false
                return
            end
            scrollTrack.Visible = menu.Visible
            local trackHeight = visibleHeight
            local minThumb = 20
            local thumbHeight = math.clamp(math.floor((visibleHeight / contentHeight) * trackHeight), minThumb, trackHeight)
            scrollThumb.Size = UDim2.new(1, 0, 0, thumbHeight)
            local maxScroll = contentHeight - visibleHeight
            local ratio = (maxScroll > 0) and (menu.CanvasPosition.Y / maxScroll) or 0
            local thumbY = math.floor(ratio * (trackHeight - thumbHeight))
            scrollThumb.Position = UDim2.new(0, 0, 0, thumbY)
        end

        -- Suchleiste erstellen (wenn enableSearch aktiviert)
        local searchBox = nil
        if enableSearch then
            searchBox = Instance.new('TextBox')
            searchBox.Name = 'SearchBox'
            searchBox.Size = UDim2.new(1, -10, 0, 28)
            searchBox.Position = UDim2.new(0, 5, 0, 6)
            searchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
            searchBox.BorderSizePixel = 0
            searchBox.Text = ""
            searchBox.PlaceholderText = "Search..."
            searchBox.TextColor3 = self.options.theme.text
            searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
            searchBox.TextXAlignment = Enum.TextXAlignment.Left
            searchBox.Font = Enum.Font.Gotham
            searchBox.TextSize = 11
            searchBox.ClearTextOnFocus = false
            searchBox.Parent = menu
            
            local searchCorner = Instance.new('UICorner')
            searchCorner.CornerRadius = UDim.new(0, 3)
            searchCorner.Parent = searchBox
            
            local searchPadding = Instance.new('UIPadding')
            searchPadding.PaddingLeft = UDim.new(0, 8)
            searchPadding.PaddingRight = UDim.new(0, 8)
            searchPadding.Parent = searchBox
            
            -- Filter-Funktion
            local function filterOptions()
                local searchLower = string.lower(searchText)
                local visibleCount = 0
                local offsetY = enableSearch and 38 or 6
                
                -- Zuerst alle Optionen filtern
                for i, option in ipairs(options) do
                    local optionFrame = optionFrames[option]
                    if optionFrame then
                        local optionStr = string.lower(tostring(option))
                        local isVisible = searchText == "" or string.find(optionStr, searchLower, 1, true) ~= nil
                        optionFrame.Visible = isVisible
                    end
                end
                
                -- Dann Positionen basierend auf sichtbaren Optionen setzen
                local visibleIndex = 0
                for i, option in ipairs(options) do
                    local optionFrame = optionFrames[option]
                    if optionFrame and optionFrame.Visible then
                        visibleIndex = visibleIndex + 1
                        visibleCount = visibleCount + 1
                        optionFrame.Position = UDim2.new(0, 5, 0, (visibleIndex - 1) * (optionHeight + 2) + offsetY)
                    end
                end
                
                -- Canvas-Größe aktualisieren
                menu.CanvasSize = UDim2.new(0, 0, 0, (visibleCount * (optionHeight + 2)) + offsetY + 6)
                updateCustomScrollbar()
            end
            
            -- Suchtext-Änderung überwachen
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                searchText = searchBox.Text
                filterOptions()
            end)
        end

        local function syncMenuPlacement()
            local parentAbs = window.frame.AbsolutePosition
            local btnAbs = button.AbsolutePosition
            local xOffset = btnAbs.X - parentAbs.X
            local yOffset = (btnAbs.Y - parentAbs.Y) + button.AbsoluteSize.Y + 2
            menu.Position = UDim2.new(0, xOffset, 0, yOffset)
            menu.Size = UDim2.new(0, button.AbsoluteSize.X, 0, maxMenuHeight)
            scrollTrack.Position = UDim2.new(0, xOffset + menu.AbsoluteSize.X - 6, 0, yOffset)
            scrollTrack.Size = UDim2.new(0, 4, 0, maxMenuHeight)
            arrow.Position = UDim2.new(1, 10, 0.5, 0)
        end
        syncMenuPlacement()
        button:GetPropertyChangedSignal('AbsoluteSize'):Connect(syncMenuPlacement)
        button:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)
        window.frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncMenuPlacement)

        local function updateMenuCanvas()
            local offsetY = enableSearch and 38 or 6
            menu.CanvasSize = UDim2.new(0, 0, 0, (#options * (optionHeight + 2)) + offsetY + 6)
        end

        -- build options
        for i, option in ipairs(options) do
            local optionFrame = Instance.new('Frame')
            optionFrame.Name = tostring(option) .. 'Option'
            optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
            local offsetY = enableSearch and 38 or 6
            optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + offsetY)
            optionFrame.BackgroundTransparency = 1
            optionFrame.Parent = menu
            optionFrames[option] = optionFrame -- Speichere Frame für Filterung

        local optionButton = Instance.new('TextButton')
            optionButton.Name = 'Button'
            optionButton.Size = UDim2.new(1, 0, 1, 0)
            optionButton.BackgroundColor3 = self.options.theme.primary
            optionButton.BackgroundTransparency = (option == selected) and 0 or 1
            optionButton.BorderSizePixel = 0
            optionButton.AutoButtonColor = false
            optionButton.Text = tostring(option)
            optionButton.TextColor3 = (option == selected) and self.options.theme.textDark or self.options.theme.text
            optionButton.TextXAlignment = Enum.TextXAlignment.Left
            optionButton.Font = Enum.Font.Gotham
            optionButton.TextSize = 11
            optionButton.Parent = optionFrame
            optionButtons[option] = optionButton
            table.insert(self._themeRefs.dropdownOptionButtons, optionButton)

            local optionCorner = Instance.new('UICorner')
            optionCorner.CornerRadius = UDim.new(0, 3)
            optionCorner.Parent = optionButton

            local optionPadding = Instance.new('UIPadding')
            optionPadding.PaddingLeft = UDim.new(0, 8)
            optionPadding.Parent = optionButton

            optionButton.MouseButton1Click:Connect(function()
                selected = option
                button.Text = tostring(selected)
                for _, opt in ipairs(options) do
                    local btn = optionButtons[opt]
                    if btn then
                        local isSel = (opt == selected)
                        btn.BackgroundTransparency = isSel and 0 or 1
                        if isSel then btn.BackgroundColor3 = self.options.theme.primary end
                        btn.TextColor3 = isSel and self.options.theme.textDark or self.options.theme.text
                    end
                end
                -- Ensure internal open-state is reset so next click opens immediately
                isOpen = false
                -- Defer close by one heartbeat so click release doesn't toggle back
                menu.Visible = false
                scrollTrack.Visible = false
                TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = 0}):Play()
                callback(selected)
            end)
        end
        updateMenuCanvas()

        -- Scrollbar syncing (Funktion bereits oben definiert)
        menu:GetPropertyChangedSignal('CanvasPosition'):Connect(updateCustomScrollbar)
        menu:GetPropertyChangedSignal('AbsoluteSize'):Connect(updateCustomScrollbar)
        menu.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                updateCustomScrollbar()
            end
        end)

        -- Dragging the thumb
        local draggingThumb = false
        local dragStartY = 0
        local thumbStartY = 0
        scrollThumb.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingThumb = true
                dragStartY = input.Position.Y
                thumbStartY = scrollThumb.AbsolutePosition.Y
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingThumb and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local visibleHeight = menu.AbsoluteSize.Y
                local contentHeight = menu.CanvasSize.Y.Offset
                local trackHeight = visibleHeight
                local thumbHeight = scrollThumb.AbsoluteSize.Y
                local maxThumbY = trackHeight - thumbHeight
                local deltaY = input.Position.Y - dragStartY
                local newThumbY = math.clamp((thumbStartY - scrollTrack.AbsolutePosition.Y) + deltaY, 0, maxThumbY)
                scrollThumb.Position = UDim2.new(0, 0, 0, newThumbY)
                local maxScroll = math.max(0, contentHeight - visibleHeight)
                local newRatio = (maxThumbY > 0) and (newThumbY / maxThumbY) or 0
                menu.CanvasPosition = Vector2.new(0, newRatio * maxScroll)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingThumb = false
            end
        end)

        local function toggleMenu()
            isOpen = not isOpen
            syncMenuPlacement()
            
            -- Z-Index dynamisch erhöhen, damit obere Dropdowns untere überdecken
            if isOpen then
                self._dropdownZIndexCounter = self._dropdownZIndexCounter + 1
                menu.ZIndex = self._dropdownZIndexCounter
                scrollTrack.ZIndex = self._dropdownZIndexCounter + 150 -- Scrollbar über Menu
            end
            
            menu.Visible = isOpen
            scrollTrack.Visible = isOpen and (menu.CanvasSize.Y.Offset > menu.AbsoluteSize.Y)
            updateCustomScrollbar()
            local rotation = isOpen and 180 or 0
            TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = rotation}):Play()
            
            -- Suchleiste zurücksetzen beim Öffnen
            if isOpen and enableSearch and searchBox then
                searchBox.Text = ""
                searchText = ""
                -- Alle Optionen wieder sichtbar machen und Positionen zurücksetzen
                for i, option in ipairs(options) do
                    local optionFrame = optionFrames[option]
                    if optionFrame then
                        optionFrame.Visible = true
                        local offsetY = enableSearch and 38 or 6
                        optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + offsetY)
                    end
                end
                updateMenuCanvas()
                menu.CanvasPosition = Vector2.new(0, 0) -- Zurück zum Anfang scrollen
            end
        end

        -- Flag um doppeltes Toggle zu verhindern
        local arrowClicked = false
        
        button.MouseButton1Click:Connect(function()
            -- Prüfe ob Arrow geklickt wurde (dann ignorieren)
            if arrowClicked then
                arrowClicked = false
                return
            end
            toggleMenu()
        end)
        
        -- Arrow-Handler: Setzt Flag, damit Button-Handler nicht auch ausgelöst wird
        arrow.MouseButton1Click:Connect(function()
            arrowClicked = true
            toggleMenu()
            -- Flag nach kurzer Zeit zurücksetzen
            task.spawn(function()
                task.wait(0.1)
                arrowClicked = false
            end)
        end)

        local api = {}
        function api.SetValue(value)
            if value == nil then return end
            for _, opt in ipairs(options) do
                if tostring(opt) == tostring(value) then
                    selected = opt
                    button.Text = tostring(selected)
                    for __, o in ipairs(options) do
                        local btn = optionButtons[o]
                        if btn then
                            local isSel = (o == selected)
                            btn.BackgroundTransparency = isSel and 0 or 1
                            btn.TextColor3 = isSel and self.options.theme.textDark or self.options.theme.text
                        end
                    end
                    callback(selected)
                    break
                end
            end
        end

        function api.GetValue()
            return selected
        end

        function api.SetOptions(newOptions)
            -- Lösche alle bestehenden Option-Frames und Buttons
            for _, frame in pairs(optionFrames) do
                if frame and frame.Parent then
                    frame:Destroy()
                end
            end
            for _, btn in pairs(optionButtons) do
                if btn and btn.Parent then
                    btn.Parent:Destroy()
                end
            end
            optionButtons = {}
            optionFrames = {}
            
            -- Setze neue Optionen
            options = newOptions or {}
            
            -- Setze Standard-Auswahl (erste Option oder "Select...")
            if #options > 0 then
                selected = options[1]
                button.Text = tostring(selected)
            else
                selected = 'Select...'
                button.Text = tostring(selected)
            end
            
            -- Erstelle neue Option-Frames und Buttons
            for i, option in ipairs(options) do
                local optionFrame = Instance.new('Frame')
                optionFrame.Name = tostring(option) .. 'Option'
                optionFrame.Size = UDim2.new(1, -10, 0, optionHeight)
                local offsetY = enableSearch and 38 or 6
                optionFrame.Position = UDim2.new(0, 5, 0, (i - 1) * (optionHeight + 2) + offsetY)
                optionFrame.BackgroundTransparency = 1
                optionFrame.Parent = menu
                optionFrames[option] = optionFrame

                local optionButton = Instance.new('TextButton')
                optionButton.Name = 'Button'
                optionButton.Size = UDim2.new(1, 0, 1, 0)
                optionButton.BackgroundColor3 = self.options.theme.primary
                optionButton.BackgroundTransparency = (option == selected) and 0 or 1
                optionButton.BorderSizePixel = 0
                optionButton.AutoButtonColor = false
                optionButton.Text = tostring(option)
                optionButton.TextColor3 = (option == selected) and self.options.theme.textDark or self.options.theme.text
                optionButton.TextXAlignment = Enum.TextXAlignment.Left
                optionButton.Font = Enum.Font.Gotham
                optionButton.TextSize = 11
                optionButton.Parent = optionFrame
                optionButtons[option] = optionButton
                table.insert(self._themeRefs.dropdownOptionButtons, optionButton)

                local optionCorner = Instance.new('UICorner')
                optionCorner.CornerRadius = UDim.new(0, 3)
                optionCorner.Parent = optionButton

                local optionPadding = Instance.new('UIPadding')
                optionPadding.PaddingLeft = UDim.new(0, 8)
                optionPadding.Parent = optionButton

                optionButton.MouseButton1Click:Connect(function()
                    selected = option
                    button.Text = tostring(selected)
                    for _, opt in ipairs(options) do
                        local btn2 = optionButtons[opt]
                        if btn2 then
                            local isSel = (opt == selected)
                            btn2.BackgroundTransparency = isSel and 0 or 1
                            if isSel then btn2.BackgroundColor3 = self.options.theme.primary end
                            btn2.TextColor3 = isSel and self.options.theme.textDark or self.options.theme.text
                        end
                    end
                    -- Ensure internal open-state is reset so next click opens immediately
                    isOpen = false
                    menu.Visible = false
                    scrollTrack.Visible = false
                    TweenService:Create(arrow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Rotation = 0}):Play()
                    callback(selected)
                end)
            end
            
            -- Aktualisiere Canvas-Größe und Scrollbar
            updateMenuCanvas()
            updateCustomScrollbar()
            
            -- Suchleiste zurücksetzen, falls vorhanden
            if enableSearch and searchBox then
                searchBox.Text = ""
                searchText = ""
            end
        end
        
        -- Refresh-Methode als Alias für SetOptions (für bessere Lesbarkeit)
        function api.Refresh(newOptions)
            api.SetOptions(newOptions)
        end

        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("dropdown", tabName, windowName, text, api, callback)
        end
        
        return api
    end

    function ModernUI:_createColorPicker(window, text, default, callback)
        default = default or Color3.fromRGB(113, 118, 242)
        callback = callback or function() end

        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.floor(42 * self.mobileLayout.scale)
            spacing = math.floor(50 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            containerHeight = 32
            spacing = 40
        end
        
        local container = Instance.new('Frame')
        container.Name = 'ColorPickerContainer'
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        window._nextY = window._nextY + spacing

        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.new(1, -25, 1, 0)
        label.Position = UDim2.new(0, 25, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = self.options.theme.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Font = Enum.Font.Gotham
        label.TextSize = math.max(9, math.floor(12 * self.mobileLayout.scale)) -- Skalierte Textgröße
        label.Parent = container

        local colorPreview = Instance.new('TextButton')
        colorPreview.Name = 'ColorPreview'
        colorPreview.Size = UDim2.new(0, 18, 0, 18)
        colorPreview.Position = UDim2.new(0, 0, 0.5, -9)
        colorPreview.BackgroundColor3 = default
        colorPreview.BorderSizePixel = 0
        colorPreview.AutoButtonColor = false
        colorPreview.Text = ''
        colorPreview.Parent = container

        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = colorPreview

        -- Popup next to preview (overlay on window)
        local popup = Instance.new('Frame')
        popup.Name = 'ColorPickerPopup'
        popup.Size = UDim2.new(0, 196, 0, 238)
        popup.BackgroundColor3 = self.options.theme.surface
        popup.BorderSizePixel = 0
        popup.Visible = false
        popup.ZIndex = 120
        popup.Parent = window.frame

        local popupCorner = Instance.new('UICorner')
        popupCorner.CornerRadius = UDim.new(0, 8)
        popupCorner.Parent = popup

        local function syncPopupPlacement()
            local parentAbs = window.frame.AbsolutePosition
            local boxAbs = colorPreview.AbsolutePosition
            local xOffset = (boxAbs.X - parentAbs.X) + colorPreview.AbsoluteSize.X + 8
            local yOffset = (boxAbs.Y - parentAbs.Y) - 4
            popup.Position = UDim2.new(0, xOffset, 0, yOffset)
        end
        syncPopupPlacement()
        colorPreview:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncPopupPlacement)
        window.frame:GetPropertyChangedSignal('AbsolutePosition'):Connect(syncPopupPlacement)

        -- SV square
        local svFrame = Instance.new('Frame')
        svFrame.Name = 'SV'
        svFrame.Size = UDim2.new(0, 168, 0, 168)
        svFrame.Position = UDim2.new(0, 14, 0, 16)
        svFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        svFrame.BorderSizePixel = 0
        svFrame.ZIndex = 121
        svFrame.ClipsDescendants = true
        svFrame.Parent = popup

        local svCorner = Instance.new('UICorner')
        svCorner.CornerRadius = UDim.new(0, 6)
        svCorner.Parent = svFrame

        local svSaturationOverlay = Instance.new('Frame')
        svSaturationOverlay.Size = UDim2.new(1, 0, 1, 0)
        svSaturationOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        svSaturationOverlay.BorderSizePixel = 0
        svSaturationOverlay.ZIndex = 122
        svSaturationOverlay.Parent = svFrame
        local svSatGradient = Instance.new('UIGradient')
        svSatGradient.Rotation = 0
        svSatGradient.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
        svSatGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 0.0),
            NumberSequenceKeypoint.new(1.0, 1.0),
        })
        svSatGradient.Parent = svSaturationOverlay
        local svSatCorner = Instance.new('UICorner')
        svSatCorner.CornerRadius = UDim.new(0, 6)
        svSatCorner.Parent = svSaturationOverlay

        local svValueOverlay = Instance.new('Frame')
        svValueOverlay.Size = UDim2.new(1, 0, 1, 0)
        svValueOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        svValueOverlay.BorderSizePixel = 0
        svValueOverlay.ZIndex = 123
        svValueOverlay.Parent = svFrame
        local svValGradient = Instance.new('UIGradient')
        svValGradient.Rotation = 90
        svValGradient.Color = ColorSequence.new(Color3.fromRGB(0,0,0), Color3.fromRGB(0,0,0))
        svValGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.0, 1.0),
            NumberSequenceKeypoint.new(1.0, 0.0),
        })
        svValGradient.Parent = svValueOverlay
        local svValCorner = Instance.new('UICorner')
        svValCorner.CornerRadius = UDim.new(0, 6)
        svValCorner.Parent = svValueOverlay

        local svKnob = Instance.new('Frame')
        svKnob.Size = UDim2.new(0, 10, 0, 10)
        svKnob.AnchorPoint = Vector2.new(0.5, 0.5)
        svKnob.Position = UDim2.new(0, 0, 0, 0)
        svKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        svKnob.BorderSizePixel = 0
        svKnob.ZIndex = 124
        svKnob.Parent = svFrame
        local svKnobCorner = Instance.new('UICorner')
        svKnobCorner.CornerRadius = UDim.new(1, 0)
        svKnobCorner.Parent = svKnob

        -- Hue bar
        local hueBar = Instance.new('Frame')
        hueBar.Name = 'HueBar'
        hueBar.Size = UDim2.new(0, 168, 0, 12)
        hueBar.Position = UDim2.new(0, 14, 0, 196)
        hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hueBar.BorderSizePixel = 0
        hueBar.ZIndex = 121
        hueBar.Parent = popup

        local hueCorner = Instance.new('UICorner')
        hueCorner.CornerRadius = UDim.new(0, 6)
        hueCorner.Parent = hueBar

        local hueGradient = Instance.new('UIGradient')
        hueGradient.Rotation = 0
        hueGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.16, Color3.fromRGB(255, 165, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 255))
        })
        hueGradient.Parent = hueBar

        local hueMarker = Instance.new('Frame')
        hueMarker.Size = UDim2.new(0, 8, 0, 16)
        hueMarker.AnchorPoint = Vector2.new(0.5, 0.5)
        hueMarker.Position = UDim2.new(0, 0, 0.5, 0)
        hueMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        hueMarker.BorderSizePixel = 0
        hueMarker.ZIndex = 122
        hueMarker.Parent = hueBar
        local hueMarkerCorner = Instance.new('UICorner')
        hueMarkerCorner.CornerRadius = UDim.new(0, 2)
        hueMarkerCorner.Parent = hueMarker
        hueMarker.ClipsDescendants = true

        -- Alpha bar
        local alphaBar = Instance.new('Frame')
        alphaBar.Name = 'AlphaBar'
        alphaBar.Size = UDim2.new(0, 168, 0, 12)
        alphaBar.Position = UDim2.new(0, 14, 0, 216)
        alphaBar.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        alphaBar.BorderSizePixel = 0
        alphaBar.ZIndex = 121
        alphaBar.Parent = popup

        local alphaCorner = Instance.new('UICorner')
        alphaCorner.CornerRadius = UDim.new(0, 6)
        alphaCorner.Parent = alphaBar

        local alphaGradient = Instance.new('UIGradient')
        alphaGradient.Rotation = 0
        alphaGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 255, 255)),
        })
        alphaGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0.00, 0.0),
            NumberSequenceKeypoint.new(1.00, 1.0),
        })
        alphaGradient.Parent = alphaBar

        local alphaMarker = Instance.new('Frame')
        alphaMarker.Size = UDim2.new(0, 8, 0, 16)
        alphaMarker.AnchorPoint = Vector2.new(0.5, 0.5)
        alphaMarker.Position = UDim2.new(0, 0, 0.5, 0)
        alphaMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        alphaMarker.BorderSizePixel = 0
        alphaMarker.ZIndex = 122
        alphaMarker.Parent = alphaBar
        local alphaMarkerCorner = Instance.new('UICorner')
        alphaMarkerCorner.CornerRadius = UDim.new(0, 2)
        alphaMarkerCorner.Parent = alphaMarker

        -- Color state (HSV + A)
        local hue, saturation, value, alpha = Color3.toHSV(default)
        if hue ~= hue then hue = 0 end -- guard against NaN
        alpha = 1

        local function hsvToColor3(h, s, v)
            return Color3.fromHSV(h, s, v)
        end

        local function updatePreviewAndSV()
            svFrame.BackgroundColor3 = hsvToColor3(hue, 1, 1)
            colorPreview.BackgroundColor3 = hsvToColor3(hue, saturation, value)
            hueMarker.Position = UDim2.new(hue, 0, 0.5, 0)
            local c = colorPreview.BackgroundColor3
            alphaGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0.00, c),
                ColorSequenceKeypoint.new(1.00, c),
            })
            alphaMarker.Position = UDim2.new(alpha, 0, 0.5, 0)
            svKnob.Position = UDim2.new(saturation, 0, 1 - value, 0)
        end
        updatePreviewAndSV()

        -- Toggle popup
        colorPreview.MouseButton1Click:Connect(function()
            popup.Visible = not popup.Visible
            syncPopupPlacement()
        end)

        -- Drag hue with mobile support
        local draggingHue = false
        hueBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingHue = true
                local x = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                hue = x
                updatePreviewAndSV()
                callback(colorPreview.BackgroundColor3, alpha)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local x = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
                hue = x
                updatePreviewAndSV()
                callback(colorPreview.BackgroundColor3, alpha)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingHue = false
            end
        end)

        -- Drag alpha with mobile support
        local draggingAlpha = false
        alphaBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingAlpha = true
                local x = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
                alpha = x
                updatePreviewAndSV()
                callback(colorPreview.BackgroundColor3, alpha)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingAlpha and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local x = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
                alpha = x
                updatePreviewAndSV()
                callback(colorPreview.BackgroundColor3, alpha)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingAlpha = false
            end
        end)

        -- Drag SV with mobile support
        local draggingSV = false
        svFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSV = true
                local relX = math.clamp((input.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                local relY = math.clamp((input.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                saturation = relX
                value = 1 - relY
                updatePreviewAndSV()
                callback(colorPreview.BackgroundColor3, alpha)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local relX = math.clamp((input.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                local relY = math.clamp((input.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                saturation = relX
                value = 1 - relY
                updatePreviewAndSV()
                callback(colorPreview.BackgroundColor3, alpha)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingSV = false
            end
        end)

        local api = {}
        function api.SetValue(color, newAlpha)
            if typeof(color) == 'Color3' then
                local h, s, v = Color3.toHSV(color)
                hue, saturation, value = h, s, v
            end
            if typeof(newAlpha) == 'number' then
                alpha = math.clamp(newAlpha, 0, 1)
            end
            updatePreviewAndSV()
            callback(colorPreview.BackgroundColor3, alpha)
        end
        function api.GetValue()
            return colorPreview.BackgroundColor3
        end
        function api.GetRGBA()
            local c = colorPreview.BackgroundColor3
            return c, alpha
        end

        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("colorpicker", tabName, windowName, text, api, callback)
        end

        return api
    end

    function ModernUI:_createTextBox(window, text, placeholder, callback)
        placeholder = placeholder or "Enter text..."
        callback = callback or function() end

        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.floor(48 * self.mobileLayout.scale)
            spacing = math.floor(56 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            containerHeight = 40
            spacing = 48
        end
        
        local container = Instance.new('Frame')
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        window._nextY = window._nextY + spacing

        local background = Instance.new('Frame')
        background.Size = UDim2.new(1, 0, 1, 0)
        background.BackgroundColor3 = self.options.theme.surface
        background.BorderSizePixel = 0
        background.Parent = container

        local bgCorner = Instance.new('UICorner')
        bgCorner.CornerRadius = UDim.new(0, 5)
        bgCorner.Parent = background

        -- Underline for focus feedback (matches Radiant style)
        local underline = Instance.new('Frame')
        underline.Name = 'Underline'
        underline.Size = UDim2.new(1, -12, 0, 2)
        underline.Position = UDim2.new(0, 6, 1, -5)
        underline.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        underline.BorderSizePixel = 0
        underline.Parent = background

        local textBox = Instance.new('TextBox')
        textBox.Name = 'TextBox'
        textBox.Size = UDim2.new(1, -52, 1, -10) -- leave space for right-side icon
        textBox.Position = UDim2.new(0, 10, 0, 5)
        textBox.BackgroundTransparency = 1
        textBox.ClearTextOnFocus = false
        textBox.Text = ''
        textBox.TextColor3 = self.options.theme.text
        textBox.PlaceholderText = placeholder
        textBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 125)
        textBox.TextXAlignment = Enum.TextXAlignment.Left
        textBox.TextYAlignment = Enum.TextYAlignment.Center
        textBox.TextSize = 12
        textBox.Font = Enum.Font.Gotham
        textBox.Parent = background

        -- Right-side icon (pencil) like Radiant
        local pencilIcon = Instance.new('ImageLabel')
        pencilIcon.Name = 'Pencil'
        pencilIcon.Size = UDim2.new(0, 20, 0, 20)
        pencilIcon.AnchorPoint = Vector2.new(1, 0.5)
        pencilIcon.Position = UDim2.new(1, -10, 0.5, 0)
        pencilIcon.BackgroundTransparency = 1
        pencilIcon.Image = 'rbxassetid://96464342105694'
        pencilIcon.ImageColor3 = self.options.theme.text
        pencilIcon.Parent = background

        local function setUnderlineActive(active)
            local target = active and self.options.theme.primary or Color3.fromRGB(50, 50, 55)
            TweenService:Create(underline, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = target}):Play()
        end

        textBox.Focused:Connect(function()
            setUnderlineActive(true)
        end)

        textBox.FocusLost:Connect(function()
            setUnderlineActive(false)
            callback(textBox.Text)
        end)

        local api = {
            SetValue = function(value)
                textBox.Text = value
            end,
            GetValue = function()
                return textBox.Text
            end
        }
        
        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("textbox", tabName, windowName, text or "TextInput", api, callback)
        end
        
        return api
    end

    function ModernUI:_createKeybind(window, text, default, callback)
        default = default or "None"
        callback = callback or function() end

        -- PC: Original-Größen, Mobile: Skaliert
        local containerHeight, spacing
        if self.mobileLayout.isMobile then
            containerHeight = math.floor(58 * self.mobileLayout.scale)
            spacing = math.floor(66 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            containerHeight = 48
            spacing = 55
        end
        
        local container = Instance.new('Frame')
        container.Name = 'KeybindContainer'
        container.Size = UDim2.new(1, 0, 0, containerHeight)
        container.Position = UDim2.new(0, 0, 0, window._nextY)
        container.BackgroundTransparency = 1
        container.Parent = window.content
        window._nextY = window._nextY + spacing

        local label = Instance.new('TextLabel')
        label.Name = 'Label'
        label.Size = UDim2.new(1, -70, 0, 20)
        label.Position = UDim2.new(0, 0, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text or 'Keybind'
        label.TextColor3 = self.options.theme.text
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.Gotham
        label.TextSize = math.max(9, math.floor(12 * self.mobileLayout.scale)) -- Skalierte Textgröße
        label.Parent = container

        -- Kleine Checkbox für "Show in List"
        local showInListCheckbox = Instance.new('ImageButton')
        showInListCheckbox.Name = 'ShowInListCheckbox'
        showInListCheckbox.Size = UDim2.new(0, 16, 0, 16)
        showInListCheckbox.Position = UDim2.new(1, -60, 0, 2)
        showInListCheckbox.BackgroundColor3 = self.options.theme.surface
        showInListCheckbox.BorderSizePixel = 0
        showInListCheckbox.Image = ''
        showInListCheckbox.Parent = container

        local checkIcon = Instance.new('ImageLabel')
        checkIcon.Name = 'CheckIcon'
        checkIcon.Size = UDim2.new(0, 10, 0, 10)
        checkIcon.Position = UDim2.new(0.5, -5, 0.5, -5)
        checkIcon.BackgroundTransparency = 1
        checkIcon.Image = ''
        checkIcon.ImageColor3 = Color3.fromRGB(0, 0, 0)
        checkIcon.Parent = showInListCheckbox

        local checkboxCorner = Instance.new('UICorner')
        checkboxCorner.CornerRadius = UDim.new(0, 3)
        checkboxCorner.Parent = showInListCheckbox

        -- Label für Checkbox
        local checkboxLabel = Instance.new('TextLabel')
        checkboxLabel.Name = 'CheckboxLabel'
        checkboxLabel.Size = UDim2.new(0, 40, 0, 16)
        checkboxLabel.Position = UDim2.new(1, -40, 0, 2)
        checkboxLabel.BackgroundTransparency = 1
        checkboxLabel.Text = 'List'
        checkboxLabel.TextColor3 = self.options.theme.text
        checkboxLabel.TextXAlignment = Enum.TextXAlignment.Right
        checkboxLabel.Font = Enum.Font.Gotham
        checkboxLabel.TextSize = 10
        checkboxLabel.Parent = container

        local showInList = false

        local function updateCheckbox()
            if showInList then
                showInListCheckbox.BackgroundColor3 = self.options.theme.primary
                checkIcon.Image = 'rbxassetid://98902844787044'
            else
                showInListCheckbox.BackgroundColor3 = self.options.theme.surface
                checkIcon.Image = ''
            end
        end

        local button = Instance.new('TextButton')
        button.Name = 'KeybindButton'
        button.Size = UDim2.new(1, 0, 0, 25)
        button.Position = UDim2.new(0, 0, 0, 22)
        button.BackgroundColor3 = self.options.theme.surface
        button.BorderSizePixel = 0
        button.AutoButtonColor = false
        button.Text = 'Bind: ' .. default
        button.Font = Enum.Font.Gotham
        button.TextSize = 12
        button.TextColor3 = self.options.theme.text
        button.Parent = container

        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 5)
        corner.Parent = button

        local isBinding = false
        local currentKey = default
        
        -- Unique ID für diesen Keybind
        local keybindId = "keybind_" .. tostring(os.clock()) .. "_" .. tostring(math.random(10000, 99999))

        local function setBindVisual(active)
            local bg = active and self.options.theme.primary or self.options.theme.surface
            local txt = active and self.options.theme.textDark or self.options.theme.text
            TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = bg}):Play()
            TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {TextColor3 = txt}):Play()
        end
        
        -- Funktion zum Aktualisieren der Keybind-Registrierung
        local function updateKeybindRegistration(key)
            if key == "None" then
                -- Entferne aus aktiven Keybinds wenn auf None gesetzt
                self.activeKeybinds[keybindId] = nil
            else
                -- Registriere oder aktualisiere den Keybind
                self.activeKeybinds[keybindId] = {
                    key = key,
                    callback = callback,
                    showInList = showInList,
                    name = text or 'Keybind'
                }
            end
        end

        -- Checkbox Click-Handler
        showInListCheckbox.MouseButton1Click:Connect(function()
            showInList = not showInList
            updateCheckbox()

            -- Aktualisiere activeKeybinds
            if self.activeKeybinds[keybindId] then
                self.activeKeybinds[keybindId].showInList = showInList
            end

            -- Aktualisiere Keybindlist
            if self._keybindListVisible then
                self:_updateKeybindList()
            end
        end)

        updateCheckbox()

        -- Initiale Registrierung (wenn nicht "None")
        if currentKey ~= "None" then
            updateKeybindRegistration(currentKey)
        end

        button.MouseButton1Click:Connect(function()
            if isBinding then return end
            isBinding = true
            self._isCapturingKeybind = true
            button.Text = 'Press any key...'
            setBindVisual(true)
            
            local connection
            connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if gameProcessed then return end
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    connection:Disconnect()
                    isBinding = false
                    
                    if input.KeyCode == Enum.KeyCode.Escape then
                        currentKey = "None"
                        button.Text = 'Bind: None'
                    else
                        currentKey = input.KeyCode.Name
                        button.Text = 'Bind: ' .. currentKey
                    end
                    
                    -- Aktualisiere die Registrierung
                    updateKeybindRegistration(currentKey)
                    
                    setBindVisual(false)
                    -- Prevent immediate UI toggle on this very key press
                    self._ignoreNextToggleKeyCode = input.KeyCode
                    self._ignoreToggleUntil = os.clock() + 0.2
                    -- Defer releasing the capture flag to next frame to avoid race with other listeners
                    task.defer(function()
                        self._isCapturingKeybind = false
                    end)
                    callback(currentKey)
                end
            end)
        end)

        local api = {
            SetValue = function(key)
                currentKey = key
                button.Text = 'Bind: ' .. key
                -- Aktualisiere die Registrierung wenn der Wert programmatisch gesetzt wird
                updateKeybindRegistration(currentKey)
            end,
            GetValue = function()
                return currentKey
            end
        }
        
        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("keybind", tabName, windowName, text, api, callback)
        end
        
        return api
    end

    function ModernUI:_createDescription(window, text, wrapText)
        text = text or ""
        wrapText = wrapText ~= false -- Default: true (wraps text)

        -- PC: Original-Größen, Mobile: Skaliert
        local textSize, padding
        if self.mobileLayout.isMobile then
            textSize = math.max(9, math.floor(11 * self.mobileLayout.scale))
            padding = math.floor(8 * self.mobileLayout.scale)
        else
            -- PC: Original-Größen
            textSize = 11
            padding = 8
        end
        
        local container = Instance.new('Frame')
        container.Name = 'DescriptionContainer'
        container.Size = UDim2.new(1, 0, 0, 0) -- Start with 0 height, AutomaticSize will handle it
        container.BackgroundTransparency = 1
        container.AutomaticSize = Enum.AutomaticSize.Y -- Always use AutomaticSize for dynamic height
        container.Parent = window.content
        -- Position is automatically managed by UIListLayout in window.content
        
        -- Padding inside container (extra padding at bottom for better visibility)
        local containerPadding = Instance.new('UIPadding')
        containerPadding.PaddingTop = UDim.new(0, padding)
        containerPadding.PaddingBottom = UDim.new(0, padding + 8) -- Extra padding at bottom
        containerPadding.PaddingLeft = UDim.new(0, padding)
        containerPadding.PaddingRight = UDim.new(0, padding)
        containerPadding.Parent = container

        local descriptionLabel = Instance.new('TextLabel')
        descriptionLabel.Name = 'DescriptionLabel'
        descriptionLabel.Size = UDim2.new(1, -padding * 2, 0, 0) -- Width with padding, height auto
        descriptionLabel.Position = UDim2.new(0, 0, 0, 0)
        descriptionLabel.BackgroundTransparency = 1
        descriptionLabel.AutomaticSize = Enum.AutomaticSize.Y -- Always auto-size height based on text
        descriptionLabel.Text = text
        descriptionLabel.TextColor3 = Color3.fromRGB(150, 150, 155) -- Slightly dimmed text color for descriptions
        descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
        descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
        descriptionLabel.Font = Enum.Font.Gotham
        descriptionLabel.TextSize = textSize
        descriptionLabel.TextWrapped = wrapText
        descriptionLabel.TextTruncate = Enum.TextTruncate.None -- Never truncate, always show full text
        descriptionLabel.LineHeight = 1.2 -- Slightly increased line height for better readability
        descriptionLabel.Parent = container
        
        -- Add extra buffer frame at bottom to ensure no text is cut off
        local bufferFrame = Instance.new('Frame')
        bufferFrame.Name = 'BufferFrame'
        bufferFrame.Size = UDim2.new(1, 0, 0, 4) -- Small buffer at bottom
        bufferFrame.Position = UDim2.new(0, 0, 1, 0)
        bufferFrame.BackgroundTransparency = 1
        bufferFrame.Parent = container
        
        -- The UIListLayout in window.content will handle spacing automatically
        -- window._nextY is not needed as UIListLayout manages positions

        local api = {
            SetText = function(newText)
                descriptionLabel.Text = newText or ""
                -- AutomaticSize handles height automatically
            end,
            GetText = function()
                return descriptionLabel.Text
            end,
            SetValue = function(value)
                descriptionLabel.Text = tostring(value or "")
            end,
            GetValue = function()
                return descriptionLabel.Text
            end,
            SetColor = function(color)
                if typeof(color) == "Color3" then
                    descriptionLabel.TextColor3 = color
                end
            end,
            GetColor = function()
                return descriptionLabel.TextColor3
            end,
            SetWrapText = function(wrap)
                wrapText = wrap ~= false
                descriptionLabel.TextWrapped = wrapText
                descriptionLabel.TextTruncate = wrapText and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
                descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
                -- AutomaticSize always enabled for dynamic sizing
                container.AutomaticSize = Enum.AutomaticSize.Y
                descriptionLabel.AutomaticSize = Enum.AutomaticSize.Y
                descriptionLabel.Size = UDim2.new(1, -padding * 2, 0, 0)
            end
        }
        
        -- Element für Config System registrieren
        if window and window.library then
            local tabName = nil
            local windowName = nil
            
            for _, tab in ipairs(window.library.tabs) do
                if tab.frame and tab.frame:IsAncestorOf(window.frame) then
                    tabName = tab.frame.Name:gsub("Content", "")
                    break
                end
            end
            
            if window.frame and window.frame.Name then
                windowName = window.frame.Name:gsub("Window", "")
            end
            
            window.library:_registerElement("description", tabName, windowName, "Description", api, function() end)
        end
        
        return api
    end

    -- Apply Mobile Sizing Immediately
    function ModernUI:_applyMobileSizing()
        if not self.mobileLayout.isMobile or not self.mainFrame then return end
        
        local viewport = self.mobileLayout.viewport
        local width, height
        
        if self.mobileLayout.isLandscape then
            -- Landscape Mobile: Etwas schmaler
            width = math.min(450, viewport.X * 0.55)
            height = math.min(350, viewport.Y * 0.65)
        else
            -- Portrait Mobile: Etwas schmaler
            width = math.min(380, viewport.X * 0.65)
            height = math.min(400, viewport.Y * 0.60)
        end
        
        -- Sofort anwenden
        self.mainFrame.Size = UDim2.new(0, width, 0, height)
        self.mainFrame.Position = UDim2.new(0.5, -width/2, 0.5, -height/2 - (self.mobileLayout.isLandscape and 0 or 10))
        
        -- Update options für andere Komponenten
        self.options.size = self.mainFrame.Size
        
        -- Tab Container und Content Container neu positionieren (skaliert)
        if self.tabContainer and self.contentContainer then
            local headerHeight = math.floor(50 * self.mobileLayout.scale)
            local tabWidth = math.floor(100 * self.mobileLayout.scale)
            local tabHeight = math.floor(50 * self.mobileLayout.scale)
            local padding = math.floor(8 * self.mobileLayout.scale)
            
            if tabWidth < 70 then tabWidth = 70 end -- Mindestbreite
            
            if not self.mobileLayout.isLandscape then
                -- Portrait: Horizontale Tabs
                self.tabContainer.Size = UDim2.new(1, 0, 0, tabHeight)
                self.tabContainer.Position = UDim2.new(0, 0, 0, headerHeight)
                self.contentContainer.Size = UDim2.new(1, -padding*2, 1, -headerHeight - tabHeight - math.floor(20 * self.mobileLayout.scale))
                self.contentContainer.Position = UDim2.new(0, padding, 0, headerHeight + tabHeight)
            else
                -- Landscape: Vertikale Tabs
                self.tabContainer.Size = UDim2.new(0, tabWidth, 1, -headerHeight - math.floor(80 * self.mobileLayout.scale))
                self.tabContainer.Position = UDim2.new(0, 0, 0, headerHeight)
                self.contentContainer.Size = UDim2.new(1, -tabWidth - padding, 1, -headerHeight - math.floor(20 * self.mobileLayout.scale))
                self.contentContainer.Position = UDim2.new(0, tabWidth + padding/2, 0, headerHeight)
            end
        end
    end

    -- Mobile Orientation Support
    function ModernUI:_setupOrientationListener()
        local lastViewport = workspace.CurrentCamera.ViewportSize
        
        self._orientationConn = workspace.CurrentCamera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
            local newViewport = workspace.CurrentCamera.ViewportSize
            
            -- Check if orientation really changed
            local wasLandscape = lastViewport.X > lastViewport.Y
            local isLandscape = newViewport.X > newViewport.Y
            
            if wasLandscape ~= isLandscape then
                task.wait(0.1) -- Brief delay for smooth transition
                self:_updateMobileLayout()
                self:_applyMobileSizing() -- Neue Sizing-Funktion verwenden
            end
            
            lastViewport = newViewport
        end)
    end

    function ModernUI:_refreshMobileLayout()
        -- Re-calculate sizes for main frame only
        local viewport = self.mobileLayout.viewport
        
        -- Update main frame size and position (nur das Hauptfenster kleiner)
        if self.mainFrame then
            if self.mobileLayout.isLandscape then
                local width = math.min(450, viewport.X * 0.55)
                local height = math.min(350, viewport.Y * 0.65)
                self.mainFrame.Size = UDim2.new(0, width, 0, height)
                self.mainFrame.Position = UDim2.new(0.5, -width/2, 0.5, -height/2)
            else
                local width = math.min(380, viewport.X * 0.65)
                local height = math.min(400, viewport.Y * 0.60)
                self.mainFrame.Size = UDim2.new(0, width, 0, height)
                self.mainFrame.Position = UDim2.new(0.5, -width/2, 0.5, -height/2 - 10)
            end
            
            -- Update options size for other components
            self.options.size = self.mainFrame.Size
        end
        
        -- Refresh tab layout (normale Größen, nicht skaliert)
        for i, tabButton in ipairs(self.tabButtons) do
            if self.mobileLayout.isMobile and not self.mobileLayout.isLandscape then
                -- Portrait: Horizontal tabs
                local tabWidth = math.floor((self.tabContainer.AbsoluteSize.X - 20) / math.max(#self.tabs, 3))
                tabButton.Size = UDim2.new(0, tabWidth, 1, -10)
                tabButton.Position = UDim2.new(0, (i - 1) * (tabWidth + 5) + 10, 0, 5)
                tabButton.TextSize = 11
            else
                -- Landscape or Desktop: Vertical tabs (schmaler)
                local buttonHeight = 35
                local spacing = 10
                tabButton.Size = UDim2.new(1, -10, 0, buttonHeight)
                tabButton.Position = UDim2.new(0, 8, 0, (i - 1) * (buttonHeight + spacing) + 8)
                tabButton.TextSize = 14
            end
        end
    end

    -- Destroy GUI
    function ModernUI:Destroy()
        if self.screenGui then
            self.screenGui:Destroy()
        end
        if self._toggleConn then
            self._toggleConn:Disconnect()
            self._toggleConn = nil
        end
        if self._watermarkUpdateConn then
            self._watermarkUpdateConn:Disconnect()
            self._watermarkUpdateConn = nil
        end
        if self._orientationConn then
            self._orientationConn:Disconnect()
            self._orientationConn = nil
        end
        -- Floating Logo cleanup
        if self._floatingLogo then
            self._floatingLogo:Destroy()
            self._floatingLogo = nil
        end
    end

    -- Toggle GUI
    function ModernUI:Toggle()
        if self.mainFrame then
            self.mainFrame.Visible = not self.mainFrame.Visible
        end
    end

    -- Mobile Minimize/Restore Funktionen
    function ModernUI:MinimizeToLogo()
        if not self.mobileLayout.isMobile or not self._floatingLogo then return end
        
        -- Einfache Fade-Out Animation
        local fadeTween = TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 1
        })
        fadeTween:Play()
        
        -- Nach Fade-Out: Hauptmenü verstecken, Floating Logo zeigen
        fadeTween.Completed:Connect(function()
            self.mainFrame.Visible = false
            self._floatingLogo.Visible = true
        end)
    end

    function ModernUI:RestoreFromLogo()
        if not self.mobileLayout.isMobile or not self._floatingLogo then return end
        
        -- Floating Logo sofort verstecken, Hauptmenü zeigen
        self._floatingLogo.Visible = false
        self.mainFrame.Visible = true
        
        -- Einfache Fade-In Animation
        self.mainFrame.BackgroundTransparency = 1
        TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0
        }):Play()
    end

    -- Set Theme
    function ModernUI:SetTheme(theme)
        for k, v in pairs(theme) do
            self.options.theme[k] = v
        end
        -- Update primary-dependent elements live
        local primary = self.options.theme.primary
        if self._themeRefs then
            if self._themeRefs.sliderFills then
                for _, fill in ipairs(self._themeRefs.sliderFills) do
                    if fill and fill.Parent then fill.BackgroundColor3 = primary end
                end
            end
            if self._themeRefs.dropdownOptionButtons then
                for _, btn in ipairs(self._themeRefs.dropdownOptionButtons) do
                    if btn and btn.Parent and btn.BackgroundTransparency == 0 then
                        btn.BackgroundColor3 = primary
                    end
                end
            end
            if self._themeRefs.multiDropdownOptionButtons then
                for _, btn in ipairs(self._themeRefs.multiDropdownOptionButtons) do
                    if btn and btn.Parent and btn.BackgroundTransparency == 0 then
                        btn.BackgroundColor3 = primary
                    end
                end
            end
            if self._themeRefs.licenseLabels then
                for _, lbl in ipairs(self._themeRefs.licenseLabels) do
                    if lbl and lbl.Parent then lbl.TextColor3 = primary end
                end
            end
            if self._themeRefs.checkboxUpdaters then
                for _, fn in ipairs(self._themeRefs.checkboxUpdaters) do
                    if type(fn) == 'function' then fn() end
                end
            end
            if self._themeRefs.windowTitleGradients then
                for _, gradient in ipairs(self._themeRefs.windowTitleGradients) do
                    if gradient and gradient.Parent then
                        -- Gradient komplett neu setzen mit aktualisierter Theme Color
                        -- Breiter Gradient-Übergang: Weiß bis 30%, Übergang 30-70%, Theme Color ab 70%
                        local whiteColor = Color3.fromRGB(255, 255, 255)
                        -- Mehr Keypoints für sichtbareren Gradient-Effekt
                        local midColor1 = Color3.new(
                            whiteColor.R * 0.7 + primary.R * 0.3,
                            whiteColor.G * 0.7 + primary.G * 0.3,
                            whiteColor.B * 0.7 + primary.B * 0.3
                        )
                        local midColor2 = Color3.new(
                            whiteColor.R * 0.3 + primary.R * 0.7,
                            whiteColor.G * 0.3 + primary.G * 0.7,
                            whiteColor.B * 0.3 + primary.B * 0.7
                        )
                        
                        gradient.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0.0, whiteColor),      -- Start: Weiß
                            ColorSequenceKeypoint.new(0.3, whiteColor),      -- Weiß bis 30%
                            ColorSequenceKeypoint.new(0.4, midColor1),      -- Erste Mischung bei 40%
                            ColorSequenceKeypoint.new(0.5, Color3.new(
                                (whiteColor.R + primary.R) / 2,
                                (whiteColor.G + primary.G) / 2,
                                (whiteColor.B + primary.B) / 2
                            )),                                              -- Mitte: 50/50 Mischung
                            ColorSequenceKeypoint.new(0.6, midColor2),      -- Zweite Mischung bei 60%
                            ColorSequenceKeypoint.new(0.7, primary),        -- Theme Color ab 70%
                            ColorSequenceKeypoint.new(1.0, primary)         -- Theme Color bis Ende
                        })
                    end
                end
            end
        end
        
        -- Update watermark accent bar color
        if self._watermarkAccentBar and self._watermarkAccentBar.Parent then
            self._watermarkAccentBar.BackgroundColor3 = primary
        end

        -- Update keybindlist title color
        if self._keybindListTitleFrame and self._keybindListTitleFrame.Parent then
            self._keybindListTitleFrame.BackgroundColor3 = primary
        end
        if self._keybindListTitleMask and self._keybindListTitleMask.Parent then
            self._keybindListTitleMask.BackgroundColor3 = primary
        end

        -- Update tabs immediately
        self:_applyTabThemeColors()
        
        -- Update logos to reflect new theme color
        if self.logoIcon and self.logoIcon.Parent then
            self.logoIcon.ImageColor3 = primary
        end
        if self._floatingLogoIcon and self._floatingLogoIcon.Parent then
            self._floatingLogoIcon.ImageColor3 = primary
        end
        
        -- Update notification elements
        if self._themeRefs.notificationElements then
            for _, notifData in ipairs(self._themeRefs.notificationElements) do
                if notifData.icon and notifData.icon.Parent then
                    notifData.icon.ImageColor3 = primary
                end
                
                if notifData.stackLabel and notifData.stackLabel.Parent then
                    notifData.stackLabel.BackgroundColor3 = primary
                end
                
                if notifData.progressBar and notifData.progressBar.Parent then
                    notifData.progressBar.BackgroundColor3 = primary
                end
                
                if notifData.titleGradient and notifData.titleGradient.Parent then
                    -- EXAKT wie bei Window-Titeln: Breiter Gradient-Übergang
                    local whiteColor = Color3.fromRGB(255, 255, 255)
                    local themeColor = primary
                    
                    -- Breiter Gradient-Übergang: Weiß bis 30%, Übergang 30-70%, Theme Color ab 70%
                    -- Mehr Keypoints für sichtbareren Gradient-Effekt
                    local midColor1 = Color3.new(
                        whiteColor.R * 0.7 + themeColor.R * 0.3,
                        whiteColor.G * 0.7 + themeColor.G * 0.3,
                        whiteColor.B * 0.7 + themeColor.B * 0.3
                    )
                    local midColor2 = Color3.new(
                        whiteColor.R * 0.3 + themeColor.R * 0.7,
                        whiteColor.G * 0.3 + themeColor.G * 0.7,
                        whiteColor.B * 0.3 + themeColor.B * 0.7
                    )
                    
                    notifData.titleGradient.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0.0, whiteColor),      -- Start: Weiß
                        ColorSequenceKeypoint.new(0.3, whiteColor),      -- Weiß bis 30%
                        ColorSequenceKeypoint.new(0.4, midColor1),      -- Erste Mischung bei 40%
                        ColorSequenceKeypoint.new(0.5, Color3.new(
                            (whiteColor.R + themeColor.R) / 2,
                            (whiteColor.G + themeColor.G) / 2,
                            (whiteColor.B + themeColor.B) / 2
                        )),                                              -- Mitte: 50/50 Mischung
                        ColorSequenceKeypoint.new(0.6, midColor2),      -- Zweite Mischung bei 60%
                        ColorSequenceKeypoint.new(0.7, themeColor),     -- Theme Color ab 70%
                        ColorSequenceKeypoint.new(1.0, themeColor)       -- Theme Color bis Ende
                    })
                end
            end
        end
    end

    -- Config Manager Integration Setup
    function ModernUI:_setupConfigManagerIntegration()
        -- Automatisches Laden des Config Systems
        task.spawn(function()
            task.wait(0.01) -- Reduced from 2 seconds
            
            local success = pcall(function()
                -- Versuche Config System zu laden
                local ConfigManager = nil
                
                -- Lokales ConfigSystem bevorzugen
                local ok, module = pcall(function()
                    return require(script.Parent:WaitForChild("ConfigSystem"))
                end)
                
                if ok and module then
                    ConfigManager = module
                else
                    -- Fallback zu GitHub
                    local success, result = pcall(function()
                        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Lirum86/CDD/refs/heads/main/Conli.lua"))()
                    end)
                    
                    if success and result then
                        ConfigManager = result
                    end
                end
                
                if ConfigManager then
                    self.configManager = ConfigManager.new(self)
                    self:_addConfigManagement(self.configManager)
                end
            end)
            

        end)
    end

    -- Config Management zur bestehenden Settings Tab Integration
    function ModernUI:_addConfigManagement(configManager)
        -- Stelle ConfigManager für SettingsTab zur Verfügung
        self._configManagerForSettings = configManager
    end

    -- Element Registry Functions für Config System
    function ModernUI:_registerElement(elementType, tabName, windowName, elementName, elementAPI, originalCallback)
        self._elementCounter = self._elementCounter + 1
        local elementId = "element_" .. self._elementCounter
        
        self._elementRegistry[elementId] = {
            id = elementId,
            type = elementType,
            tabName = tabName or "Unknown",
            windowName = windowName or "Unknown", 
            elementName = elementName or "Unknown",
            api = elementAPI,
            originalCallback = originalCallback, -- Speichere die originale Callback-Funktion
            path = tabName .. "." .. windowName .. "." .. elementName
        }
        
        return elementId
    end

    function ModernUI:_getAllRegisteredElements()
        return self._elementRegistry
    end

    function ModernUI:_getElementByPath(tabName, windowName, elementName)
        local path = tabName .. "." .. windowName .. "." .. elementName
        for _, element in pairs(self._elementRegistry) do
            if element.path == path then
                return element
            end
        end
        return nil
    end

    -- Notification System
    function ModernUI:_setupNotificationSystem()
        -- Container für alle Notifications (oben links)
        self._notificationContainer = Instance.new('Frame')
        self._notificationContainer.Name = 'NotificationContainer'
        self._notificationContainer.Size = UDim2.new(0, 320, 1, -20)
        self._notificationContainer.Position = UDim2.new(0, 10, 0, 10)
        self._notificationContainer.BackgroundTransparency = 1
        self._notificationContainer.Parent = self.screenGui
        self._notificationContainer.ZIndex = 500
        
        -- UIListLayout für automatisches Stacking
        local listLayout = Instance.new('UIListLayout')
        listLayout.Padding = UDim.new(0, 8)
        listLayout.FillDirection = Enum.FillDirection.Vertical
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = self._notificationContainer
        
        -- Registry für aktive Notifications (um Duplikate zu vermeiden)
        self._activeNotifications = {}
        
        -- Registry für Theme Updates
        if not self._themeRefs.notificationElements then
            self._themeRefs.notificationElements = {}
        end
    end
    
    function ModernUI:ShowNotification(title, message, duration)
        if not self._notificationContainer then
            self:_setupNotificationSystem()
        end
        
        title = title or "Notification"
        message = message or ""
        duration = duration or 3
        
        -- Prüfe ob diese Notification bereits existiert
        local notificationKey = title .. "|" .. message
        
        if self._activeNotifications[notificationKey] then
            -- Notification existiert bereits - Stack Counter erhöhen
            local existingNotif = self._activeNotifications[notificationKey]
            existingNotif.stackCount = existingNotif.stackCount + 1
            existingNotif.stackLabel.Text = tostring(existingNotif.stackCount)
            existingNotif.stackLabel.Visible = true
            
            -- Timer zurücksetzen
            if existingNotif.timerThread then
                task.cancel(existingNotif.timerThread)
            end
            
            -- Progress Bar zurücksetzen
            existingNotif.progressBar.Size = UDim2.new(1, 0, 1, 0)
            
            -- Neuen Timer starten
            existingNotif.timerThread = task.spawn(function()
                local startTime = tick()
                local endTime = startTime + duration
                
                while tick() < endTime do
                    local remaining = endTime - tick()
                    local progress = remaining / duration
                    existingNotif.progressBar.Size = UDim2.new(progress, 0, 1, 0)
                    task.wait(0.03)
                end
                
                -- Fade out - NUR spezifische Elemente
                local frame = existingNotif.frame
                local icon = frame:FindFirstChild("Icon")
                local titleLabel = frame:FindFirstChild("Title")
                local messageLabel = frame:FindFirstChild("Message")
                local stackLabel = frame:FindFirstChild("StackCounter")
                local progressContainer = frame:FindFirstChild("ProgressContainer")
                local progressBar = existingNotif.progressBar
                
                TweenService:Create(frame, TweenInfo.new(0.3), {
                    BackgroundTransparency = 1
                }):Play()
                
                if icon then
                    TweenService:Create(icon, TweenInfo.new(0.3), {
                        ImageTransparency = 1
                    }):Play()
                end
                
                if titleLabel then
                    TweenService:Create(titleLabel, TweenInfo.new(0.3), {
                        TextTransparency = 1
                    }):Play()
                end
                
                if messageLabel then
                    TweenService:Create(messageLabel, TweenInfo.new(0.3), {
                        TextTransparency = 1
                    }):Play()
                end
                
                if stackLabel then
                    TweenService:Create(stackLabel, TweenInfo.new(0.3), {
                        BackgroundTransparency = 1,
                        TextTransparency = 1
                    }):Play()
                end
                
                if progressContainer then
                    TweenService:Create(progressContainer, TweenInfo.new(0.3), {
                        BackgroundTransparency = 1
                    }):Play()
                end
                
                if progressBar then
                    TweenService:Create(progressBar, TweenInfo.new(0.3), {
                        BackgroundTransparency = 1
                    }):Play()
                end
                
                task.wait(0.3)
                
                -- Aus Theme References entfernen
                for i, notif in ipairs(self._themeRefs.notificationElements) do
                    if notif == existingNotif then
                        table.remove(self._themeRefs.notificationElements, i)
                        break
                    end
                end
                
                frame:Destroy()
                self._activeNotifications[notificationKey] = nil
            end)
            
            return
        end
        
        -- Neue Notification erstellen
        local notifFrame = Instance.new('Frame')
        notifFrame.Name = 'Notification'
        notifFrame.Size = UDim2.new(1, 0, 0, 60)
        notifFrame.BackgroundColor3 = self.options.theme.surface
        notifFrame.BorderSizePixel = 0
        notifFrame.Parent = self._notificationContainer
        notifFrame.ZIndex = 501
        
        local notifCorner = Instance.new('UICorner')
        notifCorner.CornerRadius = UDim.new(0, 8)
        notifCorner.Parent = notifFrame
        
        -- Icon (Info Icon) - größer
        local icon = Instance.new('ImageLabel')
        icon.Name = 'Icon'
        icon.Size = UDim2.new(0, 32, 0, 32)
        icon.Position = UDim2.new(0, 10, 0, 10)
        icon.BackgroundTransparency = 1
        icon.Image = 'rbxassetid://109183916939627'
        icon.ImageColor3 = self.options.theme.primary
        icon.ZIndex = 502
        icon.Parent = notifFrame
        
        -- Title mit Gradient (EXAKT wie Window-Titel)
        local titleLabel = Instance.new('TextLabel')
        titleLabel.Name = 'Title'
        -- Größe wird dynamisch basierend auf Textlänge angepasst (wie Window-Titel)
        titleLabel.Size = UDim2.new(0, 0, 0, 16) -- Wird später angepasst
        titleLabel.Position = UDim2.new(0, 50, 0, 6)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = title
        -- WICHTIG: TextColor3 muss auf Weiß sein, damit Gradient funktioniert
        titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.TextYAlignment = Enum.TextYAlignment.Center
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 12
        titleLabel.TextTruncate = Enum.TextTruncate.None
        titleLabel.ZIndex = 502
        titleLabel.Parent = notifFrame
        
        -- Textgröße berechnen und TextLabel-Größe anpassen (für korrekten Gradient) - wie bei Window-Titel
        task.spawn(function()
            RunService.RenderStepped:Wait()
            RunService.RenderStepped:Wait()
            local textBounds = TextService:GetTextSize(
                titleLabel.Text,
                titleLabel.TextSize,
                titleLabel.Font,
                Vector2.new(10000, 16)
            )
            local textWidth = textBounds.X + 4 -- Kleines Padding
            local maxWidth = notifFrame.AbsoluteSize.X - 110 -- Platz für Icon und Stack Counter
            titleLabel.Size = UDim2.new(0, math.min(textWidth, maxWidth), 0, 16)
        end)
        
        -- Title Gradient - EXAKT wie bei Window-Titeln kopiert
        local titleGradient = Instance.new('UIGradient')
        titleGradient.Name = 'TitleGradient'
        titleGradient.Rotation = 0 -- Horizontaler Gradient (von links nach rechts)
        
        -- Transparency: Vollständig sichtbar
        titleGradient.Transparency = NumberSequence.new(0)
        
        -- Color: 50/50 Split mit breitem, sichtbarem Gradient-Übergang
        local whiteColor = Color3.fromRGB(255, 255, 255)
        local themeColor = self.options.theme.primary
        
        -- Breiter Gradient-Übergang: Weiß bis 30%, Übergang 30-70%, Theme Color ab 70%
        -- Mehr Keypoints für sichtbareren Gradient-Effekt
        local midColor1 = Color3.new(
            whiteColor.R * 0.7 + themeColor.R * 0.3,
            whiteColor.G * 0.7 + themeColor.G * 0.3,
            whiteColor.B * 0.7 + themeColor.B * 0.3
        )
        local midColor2 = Color3.new(
            whiteColor.R * 0.3 + themeColor.R * 0.7,
            whiteColor.G * 0.3 + themeColor.G * 0.7,
            whiteColor.B * 0.3 + themeColor.B * 0.7
        )
        
        titleGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.0, whiteColor),      -- Start: Weiß
            ColorSequenceKeypoint.new(0.3, whiteColor),      -- Weiß bis 30%
            ColorSequenceKeypoint.new(0.4, midColor1),      -- Erste Mischung bei 40%
            ColorSequenceKeypoint.new(0.5, Color3.new(
                (whiteColor.R + themeColor.R) / 2,
                (whiteColor.G + themeColor.G) / 2,
                (whiteColor.B + themeColor.B) / 2
            )),                                              -- Mitte: 50/50 Mischung
            ColorSequenceKeypoint.new(0.6, midColor2),      -- Zweite Mischung bei 60%
            ColorSequenceKeypoint.new(0.7, themeColor),     -- Theme Color ab 70%
            ColorSequenceKeypoint.new(1.0, themeColor)       -- Theme Color bis Ende
        })
        
        -- Gradient muss als Child des TextLabels hinzugefügt werden
        titleGradient.Parent = titleLabel
        
        -- Stack Counter (oben rechts, initial unsichtbar)
        local stackLabel = Instance.new('TextLabel')
        stackLabel.Name = 'StackCounter'
        stackLabel.Size = UDim2.new(0, 26, 0, 18)
        stackLabel.Position = UDim2.new(1, -34, 0, 6)
        stackLabel.BackgroundColor3 = self.options.theme.primary
        stackLabel.BorderSizePixel = 0
        stackLabel.Text = "1"
        stackLabel.TextColor3 = self.options.theme.textDark
        stackLabel.Font = Enum.Font.GothamBold
        stackLabel.TextSize = 11
        stackLabel.ZIndex = 502
        stackLabel.Visible = false
        stackLabel.Parent = notifFrame
        
        local stackCorner = Instance.new('UICorner')
        stackCorner.CornerRadius = UDim.new(0, 4)
        stackCorner.Parent = stackLabel
        
        -- Message Text - kompakter für kleinere Notification
        local messageLabel = Instance.new('TextLabel')
        messageLabel.Name = 'Message'
        messageLabel.Size = UDim2.new(1, -54, 0, 24)
        messageLabel.Position = UDim2.new(0, 50, 0, 24)
        messageLabel.BackgroundTransparency = 1
        messageLabel.Text = message
        messageLabel.TextColor3 = self.options.theme.text
        messageLabel.TextXAlignment = Enum.TextXAlignment.Left
        messageLabel.TextYAlignment = Enum.TextYAlignment.Top
        messageLabel.Font = Enum.Font.Gotham
        messageLabel.TextSize = 10
        messageLabel.TextWrapped = true
        messageLabel.ZIndex = 502
        messageLabel.Parent = notifFrame
        
        -- Progress Bar Container (unten)
        local progressContainer = Instance.new('Frame')
        progressContainer.Name = 'ProgressContainer'
        progressContainer.Size = UDim2.new(1, -16, 0, 2)
        progressContainer.Position = UDim2.new(0, 8, 1, -8)
        progressContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        progressContainer.BorderSizePixel = 0
        progressContainer.ZIndex = 502
        progressContainer.Parent = notifFrame
        
        local progressCorner = Instance.new('UICorner')
        progressCorner.CornerRadius = UDim.new(0, 2)
        progressCorner.Parent = progressContainer
        
        -- Progress Bar Fill
        local progressBar = Instance.new('Frame')
        progressBar.Name = 'ProgressBar'
        progressBar.Size = UDim2.new(1, 0, 1, 0)
        progressBar.BackgroundColor3 = self.options.theme.primary
        progressBar.BorderSizePixel = 0
        progressBar.ZIndex = 503
        progressBar.Parent = progressContainer
        
        local progressFillCorner = Instance.new('UICorner')
        progressFillCorner.CornerRadius = UDim.new(0, 2)
        progressFillCorner.Parent = progressBar
        
        -- Notification in Registry speichern mit Theme-Elementen
        local notifData = {
            frame = notifFrame,
            stackLabel = stackLabel,
            progressBar = progressBar,
            icon = icon,
            titleGradient = titleGradient,
            stackCount = 1,
            timerThread = nil
        }
        self._activeNotifications[notificationKey] = notifData
        
        -- Zu Theme References hinzufügen
        table.insert(self._themeRefs.notificationElements, notifData)
        
        -- Slide-in Animation
        notifFrame.Position = UDim2.new(0, -340, 0, 0)
        TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()
        
        -- Timer für Progress Bar und Auto-Close
        notifData.timerThread = task.spawn(function()
            local startTime = tick()
            local endTime = startTime + duration
            
            while tick() < endTime do
                local remaining = endTime - tick()
                local progress = remaining / duration
                progressBar.Size = UDim2.new(progress, 0, 1, 0)
                task.wait(0.03)
            end
            
            -- Fade out - NUR spezifische Elemente, nicht alle Descendants
            TweenService:Create(notifFrame, TweenInfo.new(0.3), {
                BackgroundTransparency = 1
            }):Play()
            
            TweenService:Create(icon, TweenInfo.new(0.3), {
                ImageTransparency = 1
            }):Play()
            
            TweenService:Create(titleLabel, TweenInfo.new(0.3), {
                TextTransparency = 1
            }):Play()
            
            TweenService:Create(messageLabel, TweenInfo.new(0.3), {
                TextTransparency = 1
            }):Play()
            
            TweenService:Create(stackLabel, TweenInfo.new(0.3), {
                BackgroundTransparency = 1,
                TextTransparency = 1
            }):Play()
            
            TweenService:Create(progressContainer, TweenInfo.new(0.3), {
                BackgroundTransparency = 1
            }):Play()
            
            TweenService:Create(progressBar, TweenInfo.new(0.3), {
                BackgroundTransparency = 1
            }):Play()
            
            task.wait(0.3)
            
            -- Aus Theme References entfernen
            for i, notif in ipairs(self._themeRefs.notificationElements) do
                if notif == notifData then
                    table.remove(self._themeRefs.notificationElements, i)
                    break
                end
            end
            
            notifFrame:Destroy()
            self._activeNotifications[notificationKey] = nil
        end)
    end

    return ModernUI
