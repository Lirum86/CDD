-- SettingsTab.lua
-- Builds the Settings tab content for ModernUI
-- Exports: function Build(ui, afterTab) -> returns the created tab

local SettingsTab = {}
local externalBindings = {}

local function createTabAfter(ui, title, icon, afterTab)
    -- Currently the library appends; place after is not supported directly, so create normally
    local tab = ui:CreateTab(title, icon)
    return tab
end

function SettingsTab.Build(ui, afterTab, deps)
    -- Verwende neues ConfigManager System falls verfügbar, sonst Fallback
    local ConfigSystem = nil
    
    -- Warte kurz, da ConfigManager möglicherweise noch nicht bereit ist
    local attempts = 0
    while attempts < 5 do
        if ui._configManagerForSettings then
            ConfigSystem = ui._configManagerForSettings
            break
        elseif ui.configManager then
            ConfigSystem = ui.configManager
            break
        elseif deps and deps.ConfigSystem then
            ConfigSystem = deps.ConfigSystem
            break
        else
            attempts = attempts + 1
            if attempts < 5 then
                task.wait(0.01)
            end
        end
    end
    
    if not ConfigSystem then
        -- Versuche ConfigSystem direkt zu laden
        local success = pcall(function()
            -- Lokales ConfigSystem probieren
            local ok, module = pcall(function()
                return require(script.Parent:WaitForChild("ConfigSystem"))
            end)
            
            if ok and module then
                ConfigSystem = module.new(ui)
            else
                -- GitHub Fallback
                local ConfigManagerClass = loadstring(game:HttpGet("https://raw.githubusercontent.com/Lirum86/CDD/refs/heads/main/Conli.lua"))()
                if ConfigManagerClass then
                    ConfigSystem = ConfigManagerClass.new(ui)
                end
            end
        end)
    end
    
    local tab = createTabAfter(ui, "Settings", "⚙️", afterTab)

    -- Window 1: Keybind + Watermark toggle
    local winKeys = tab:CreateWindow("UI Settings")
    winKeys:CreateKeybind("UI Toggle", "RightShift", function(key)
        ui:SetToggleKey(key)
    end)
    winKeys:CreateCheckbox("Watermark", true, function(val)
        ui:SetWatermarkVisible(val)
    end)
    winKeys:CreateColorPicker("Theme Color", (ui.options and ui.options.theme and ui.options.theme.primary) or Color3.fromRGB(110,117,243), function(color, alpha)
        ui:SetTheme({ primary = color })
    end)
    
    -- Anti AFK Checkbox (standard an)
    local antiAfkEnabled = true
    local antiAfkConnection = nil
    
    local function startAntiAfk()
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
        end
        
        local VirtualUser = game:GetService('VirtualUser')
        antiAfkConnection = game:GetService('Players').LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
    
    local function stopAntiAfk()
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
    end
    
    winKeys:CreateCheckbox("Anti AFK", true, function(val)
        antiAfkEnabled = val
        if val then
            startAntiAfk()
        else
            stopAntiAfk()
        end
    end)
    
    -- FPS Boost Button
    winKeys:CreateButton("FPS Boost", function()
        local function optimizeGame()
            local lighting = game:GetService("Lighting")
            local terrain = workspace:FindFirstChildOfClass('Terrain')
            
            lighting.GlobalShadows = false
            lighting.FogEnd = 9e9
            lighting.Brightness = 0
            
            for _, effect in pairs(lighting:GetChildren()) do
                if effect:IsA("PostEffect") then
                    effect.Enabled = false
                end
            end
            
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 0
            end
            
            settings().Rendering.QualityLevel = "Level01"
            
            for _, descendant in pairs(workspace:GetDescendants()) do
                if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                    descendant.Enabled = false
                elseif descendant:IsA("Explosion") then
                    descendant.BlastPressure = 1
                    descendant.BlastRadius = 1
                elseif descendant:IsA("Fire") or descendant:IsA("SpotLight") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") then
                    descendant.Enabled = false
                elseif descendant:IsA("MeshPart") then
                    descendant.Material = Enum.Material.Plastic
                    descendant.Reflectance = 0
                elseif descendant:IsA("Part") or descendant:IsA("UnionOperation") or descendant:IsA("CornerWedgePart") or descendant:IsA("TrussPart") then
                    descendant.Material = Enum.Material.Plastic
                    descendant.Reflectance = 0
                elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
                    descendant.Transparency = 1
                elseif descendant:IsA("PointLight") or descendant:IsA("SurfaceLight") then
                    descendant.Enabled = false
                end
            end
            
            game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function(char)
                wait(0.5)
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("Part") or part:IsA("MeshPart") then
                        part.Material = Enum.Material.Plastic
                        part.Reflectance = 0
                    end
                end
            end)
        end

        optimizeGame()

        workspace.DescendantAdded:Connect(function(descendant)
            wait()
            if descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                descendant.Enabled = false
            elseif descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") then
                descendant.Enabled = false
            elseif descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
                descendant.Enabled = false
            end
        end)
    end)
    
    -- Start Anti AFK automatically
    startAntiAfk()

    -- Window 2: Config system
    local winCfg = tab:CreateWindow("Config")

    local cfgName = ""
    local configNameBox = winCfg:CreateTextBox("Config Name", "MyConfig", function(name)
        cfgName = name
    end)

    local configsDropdown = nil
    local function refreshDropdown(selectName)
        if not configsDropdown then 
            return 
        end
        
        -- Warte bis ConfigSystem verfügbar ist
        local waitAttempts = 0
        while not ConfigSystem and waitAttempts < 5 do
            waitAttempts = waitAttempts + 1
            task.wait(0.1)
        end
        
        local list = {"Default"}
        
        if ConfigSystem then
            -- Versuche mehrere Male die Liste zu laden
            for attempt = 1, 3 do
                if ConfigSystem.getConfigList then
                    local newList = ConfigSystem:getConfigList()
                    if newList and #newList > 0 then
                        list = newList
                        break
                    end
                elseif ConfigSystem.List then
                    local newList = ConfigSystem.List()
                    if newList and #newList > 0 then
                        list = newList
                        break
                    end
                end
                
                if attempt < 3 then
                    task.wait(0.2) -- Kurz warten zwischen Versuchen
                end
            end
        end
        
        -- Default Config sicherstellen
        if not table.find(list, "Default") then
            table.insert(list, 1, "Default")
        end
        
        -- Dropdown sicher aktualisieren
        if configsDropdown.SetOptions then 
            pcall(function() 
                configsDropdown.SetOptions(list) 
            end)
        end
        
        local choose = selectName or selectedConfig or "Default"
        
        -- Prüfe ob gewählte Config in Liste existiert
        if not table.find(list, choose) then
            choose = "Default"
        end
        
        if choose and configsDropdown.SetValue then 
            local success = pcall(function() 
                configsDropdown.SetValue(choose) 
            end)
            if success then
                selectedConfig = choose
            end
        end
    end

    local createBtn = winCfg:CreateButton("Create Config", function()
        if not ConfigSystem then 
            return 
        end
        
        if cfgName == nil or cfgName == '' then 
            return 
        end
        
        -- Prüfe ob Config bereits existiert
        local alreadyExists = false
        if ConfigSystem.configExists then
            alreadyExists = ConfigSystem:configExists(cfgName)
        elseif ConfigSystem.Exists then
            alreadyExists = ConfigSystem.Exists(cfgName)
        end
        
        if alreadyExists then
            return
        end
        
        local success = false
        if ConfigSystem.createConfig then
            -- Neues ConfigManager System
            success = ConfigSystem:createConfig(cfgName)
        elseif ConfigSystem.Create then
            -- Altes ConfigSystem
            success = ConfigSystem.Create(cfgName)
        end
        
        if success then
            -- Warte kurz und aktualisiere dann das Dropdown
            task.spawn(function()
                task.wait(0.3) -- Längere Wartezeit für bessere Synchronisation
                
                -- Mehrfach versuchen bis Config sichtbar ist
                for attempt = 1, 5 do
                    refreshDropdown(cfgName)
                    
                    -- Prüfe ob Config wirklich im Dropdown ist
                    task.wait(0.1)
                    if selectedConfig == cfgName then
                        break -- Erfolgreich!
                    end
                    
                    if attempt < 5 then
                        task.wait(0.2)
                    end
                end
                
                -- Config Name Input leeren
                if configNameBox and configNameBox.SetValue then
                    configNameBox.SetValue("")
                    cfgName = ""
                end
            end)
        end
    end)

    local selectedConfig = "Default"
    local initialList = {"Default"}
    
    -- Dropdown erst erstellen, dann später aktualisieren
    configsDropdown = winCfg:CreateDropdown("Configs", initialList, selectedConfig, function(val)
        selectedConfig = val
    end)
    
    -- Dropdown-Liste asynchron laden und aktualisieren
    local function updateDropdownList()
        if not ConfigSystem then return end
        
        local list = {"Default"}
        
        if ConfigSystem.getConfigList then
            local newList = ConfigSystem:getConfigList()
            if newList and #newList > 0 then
                list = newList
            end
        elseif ConfigSystem.List then
            local newList = ConfigSystem.List()
            if newList and #newList > 0 then
                list = newList
            end
        end
        
        -- Default Config sicherstellen in Liste
        if not table.find(list, "Default") then
            table.insert(list, 1, "Default")
        end
        
        -- Dropdown aktualisieren
        if configsDropdown and configsDropdown.SetOptions then
            pcall(function() 
                configsDropdown.SetOptions(list)
                if selectedConfig and table.find(list, selectedConfig) then
                    configsDropdown.SetValue(selectedConfig)
                else
                    configsDropdown.SetValue("Default")
                    selectedConfig = "Default"
                end
            end)
        end
    end
    
    task.spawn(function()
        local attempts = 0
        while attempts < 20 do -- Mehr Versuche
            attempts = attempts + 1
            
            if ConfigSystem and (ConfigSystem.isInitialized == nil or ConfigSystem.isInitialized) then
                updateDropdownList()
                break
            else
                task.wait(0.1) -- Kürzere Wartezeit
            end
        end
        
        -- Fallback: Auch wenn nicht initialisiert, versuche zu laden
        if attempts >= 20 then
            updateDropdownList()
        end
    end)

    local function colorToTbl(c)
        if typeof(c) ~= 'Color3' then return {r=110,g=117,b=243} end
        return { r = math.floor(c.R*255+0.5), g = math.floor(c.G*255+0.5), b = math.floor(c.B*255+0.5) }
    end
    local function tblToColor(t)
        if type(t) ~= 'table' then return Color3.fromRGB(110,117,243) end
        return Color3.fromRGB(tonumber(t.r) or 110, tonumber(t.g) or 117, tonumber(t.b) or 243)
    end

    local loadBtn = winCfg:CreateButton("Load", function()
        if not ConfigSystem then 
            return 
        end
        
        if not selectedConfig then 
            return 
        end
        
        local success = false
        if ConfigSystem.loadConfig then
            -- Neues ConfigManager System
            success = ConfigSystem:loadConfig(selectedConfig)
        elseif ConfigSystem.Load then
            -- Altes ConfigSystem - Legacy-Verhalten
            local data = ConfigSystem.Load(selectedConfig)
            if type(data) == 'table' then
                if data.primary then ui:SetTheme({ primary = tblToColor(data.primary) }) end
                if data.watermark ~= nil then ui:SetWatermarkVisible(data.watermark and true or false) end
                if data.toggleKey then ui:SetToggleKey(data.toggleKey) end
                -- apply external control states
                if type(data.controls) == 'table' then
                    for key, value in pairs(data.controls) do
                        local control = externalBindings[key]
                        if control and type(control) == 'table' and type(control.SetValue) == 'function' then
                            -- color tables back to Color3
                            if type(value) == 'table' and value.__type == 'color' then
                                value = Color3.fromRGB(tonumber(value.r) or 110, tonumber(value.g) or 117, tonumber(value.b) or 243)
                            end
                            pcall(function() control.SetValue(value) end)
                        end
                    end
                end
                success = true
            end
        end
    end)
    
    local saveBtn = winCfg:CreateButton("Save", function()
        if not ConfigSystem then 
            return 
        end
        
        if not selectedConfig then 
            return 
        end
        
        local success = false
        if ConfigSystem.saveConfig then
            -- Neues ConfigManager System - automatische Datensammlung
            success = ConfigSystem:saveConfig(selectedConfig)
        elseif ConfigSystem.Save then
            -- Altes ConfigSystem - manuelle Datensammlung
            local theme = ui.options and ui.options.theme or { primary = Color3.fromRGB(110,117,243) }
            local data = {
                primary = colorToTbl(theme.primary),
                watermark = (ui._watermarkVisible ~= false),
                toggleKey = (ui:GetToggleKey() and ui:GetToggleKey().Name) or "RightShift",
            }
            -- capture external control states
            local controls = {}
            for key, control in pairs(externalBindings) do
                if type(control) == 'table' and type(control.GetValue) == 'function' then
                    local ok, val = pcall(function() return control.GetValue() end)
                    if ok then
                        if typeof(val) == 'Color3' then
                            controls[key] = { __type = 'color', r = math.floor(val.R*255+0.5), g = math.floor(val.G*255+0.5), b = math.floor(val.B*255+0.5) }
                        else
                            controls[key] = val
                        end
                    end
                end
            end
            data.controls = controls
            local ok, err = ConfigSystem.Save(selectedConfig, data)
            success = ok
        end
        
        if success then
            -- nach Speichern Dropdown-Liste aktualisieren, Auswahl beibehalten
            task.defer(function() refreshDropdown(selectedConfig) end)
        end
    end)

    local deleteBtn = winCfg:CreateButton("Delete", function()
        if not ConfigSystem then 
            return 
        end
        
        if not selectedConfig then 
            return 
        end
        
        if selectedConfig and (string.lower(selectedConfig) == "default") then
            return
        end
        
        local success = false
        if ConfigSystem.deleteConfig then
            -- Neues ConfigManager System
            success = ConfigSystem:deleteConfig(selectedConfig)
        elseif ConfigSystem.Delete then
            -- Altes ConfigSystem
            success = ConfigSystem.Delete(selectedConfig)
        end
        
        if success then
            local deletedConfig = selectedConfig
            selectedConfig = nil
            
            task.defer(function()
                -- Config-Liste aktualisieren
                local list = {"Default"}
                if ConfigSystem.getConfigList then
                    list = ConfigSystem:getConfigList()
                elseif ConfigSystem.List then
                    list = ConfigSystem.List()
                end
                
                if configsDropdown then
                    configsDropdown.SetOptions(list)
                    configsDropdown.SetValue(list[1])
                    selectedConfig = list[1]
                end
            end)
        end
    end)

    -- AutoLoad Checkbox mit korrektem State
    local autoLoadCheckbox = winCfg:CreateCheckbox("Auto Load Config", false, function(val)
        if ConfigSystem then
            if ConfigSystem.setAutoLoad then
                -- Neues ConfigManager System
                ConfigSystem:setAutoLoad(val and selectedConfig or nil)
            elseif ConfigSystem.SetAutoLoad then
                -- Altes ConfigSystem
                ConfigSystem.SetAutoLoad(val and selectedConfig or nil)
            end
        end
    end)

    -- Ensure default exists and auto refresh list on build
    if ConfigSystem then
        -- Warte bis ConfigSystem bereit ist
        task.spawn(function()
            local attempts = 0
            while attempts < 15 do -- Mehr Versuche
                attempts = attempts + 1
                
                if ConfigSystem.isInitialized == nil or ConfigSystem.isInitialized then
                    -- Default Config sicherstellen
                    local defaultExists = false
                    if ConfigSystem.configExists then
                        defaultExists = ConfigSystem:configExists('Default')
                    elseif ConfigSystem.Exists then
                        defaultExists = ConfigSystem.Exists('Default')
                    end
                    
                    if not defaultExists then
                        -- Mehrfach versuchen Default Config zu erstellen
                        for createAttempt = 1, 3 do
                            local success = false
                            if ConfigSystem.createConfig then
                                success = ConfigSystem:createConfig('Default')
                            elseif ConfigSystem.Create then
                                success = ConfigSystem.Create('Default')
                            end
                            
                            if success then
                                task.wait(0.2)
                                if ConfigSystem:configExists('Default') then
                                    break
                                end
                            end
                            
                            if createAttempt < 3 then
                                task.wait(0.3)
                            end
                        end
                    end
                    
                    -- Dropdown mit aktueller Liste refreshen (mehrfach versuchen)
                    for refreshAttempt = 1, 3 do
                        refreshDropdown('Default')
                        task.wait(0.2)
                        
                        if selectedConfig == 'Default' then
                            break
                        end
                    end
                    
                    break
                else
                    task.wait(0.1) -- Kürzere Wartezeit
                end
            end
        end)
        
        -- AutoLoad Status beim Start anzeigen (aber nur visuell, nicht automatisch ändern)
        task.spawn(function()
            task.wait(0.01)
            
            local auto = nil
            if ConfigSystem.getAutoLoad then
                auto = ConfigSystem:getAutoLoad()
            elseif ConfigSystem.GetAutoLoad then
                auto = ConfigSystem.GetAutoLoad()
            end
            
            if auto and auto ~= "" then
                -- Config im Dropdown setzen
                pcall(function() 
                    if configsDropdown and configsDropdown.SetValue then 
                        configsDropdown.SetValue(auto) 
                    end 
                end)
                selectedConfig = auto
                
                -- Checkbox visuell auf den korrekten Status setzen (nur beim Start)
                pcall(function()
                    if autoLoadCheckbox and autoLoadCheckbox.SetValue then
                        autoLoadCheckbox.SetValue(true)
                    end
                end)
            else
                -- Checkbox visuell auf false setzen (nur beim Start)
                pcall(function()
                    if autoLoadCheckbox and autoLoadCheckbox.SetValue then
                        autoLoadCheckbox.SetValue(false)
                    end
                end)
            end
        end)
    end

    return tab
end

-- Register external controls from Example.lua
function SettingsTab.RegisterBindings(map)
    if type(map) ~= 'table' then return end
    for k, v in pairs(map) do
        if type(k) == 'string' and type(v) == 'table' then
            externalBindings[k] = v
        end
    end
end

return SettingsTab
