local M = {}
local _Fn
local _Config
function M.Mount(env)
    env = env or {}

    local Config      = env.Config
    local Fn          = env.Fn
    local Toggles     = env.Toggles
    local Options     = env.Options
    local Library     = env.Library
    local UIS         = env.UserInputService
    local PlayerGui   = env.PlayerGui
    local getProtectedGui = env.getProtectedGui
    local randomString    = env.randomString
    local notify          = env.notify
    local ToFV2_RefreshTargetButtons = env.ToFV2_RefreshTargetButtons

    local safeCall = env.safeCall
    if type(safeCall) ~= "function" then
        safeCall = function(label, fn, ...)
            local ok, err = pcall(fn, ...)
            if not ok then warn("[FALLENS] " .. tostring(label) .. ": " .. tostring(err)) end
            return ok, err
        end
    end

    _Fn     = Fn
    _Config = Config

    if type(Config) ~= "table" then
        warn("[FALLENS] ToggleIcons module: env.Config is missing; aborting Mount")
        return M
    end
    if type(Fn) ~= "table" then
        warn("[FALLENS] ToggleIcons module: env.Fn is missing; aborting Mount")
        return M
    end

    if type(Config.ToggleIcons) ~= "table" then
        Config.ToggleIcons = {
            Draggable   = true,
            IconSize    = 48,
            Gap         = 8,
            AnchorXOffset = -10,
            AnchorYOffset = 180,
            Positions   = {},
            _gui        = nil,
            _icons      = {},
            _stackCount = 0,
            _uisConn    = nil,
            _uisEndConn = nil,
            _activeDrag = nil,
            _dragStart  = nil,
            _dragStartPos = nil,
        }
    end

    if type(Config.ToggleIcons._icons)    ~= "table" then Config.ToggleIcons._icons    = {} end
    if type(Config.ToggleIcons.Positions) ~= "table" then Config.ToggleIcons.Positions = {} end

    if type(Config.TargetIconShared) ~= "table" then
        Config.TargetIconShared = {
            ModeList = { "Killer", "Survivor", "SCP" },
            Labels   = { Killer = "K", Survivor = "S", SCP = "SCP" },
            Colors   = {
                Killer   = Color3.fromRGB(255, 60, 60),
                Survivor = Color3.fromRGB(80, 220, 255),
                SCP      = Color3.fromRGB(255, 0, 0),
            },
        }
    end
    if type(Config.State) ~= "table" then Config.State = {} end

    local function NextStackPosition()
        local cfg   = Config.ToggleIcons
        local size  = cfg.IconSize
        local gap   = cfg.Gap
        local idx   = cfg._stackCount
        cfg._stackCount = idx + 1
        local xOff = -cfg.AnchorXOffset - size
        local yOff = cfg.AnchorYOffset + idx * (size + gap)
        return UDim2.new(1, xOff, 0, yOff)
    end

    local function EnsureGui()
        local cfg = Config.ToggleIcons
        if cfg._gui and cfg._gui.Parent then return cfg._gui end
        local SG = Instance.new("ScreenGui")
        SG.Name = "FLNS_ToggleIcons"
        SG.ResetOnSpawn = false
        SG.IgnoreGuiInset = true
        SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        pcall(function() SG.Parent = getProtectedGui() end)
        if not SG.Parent then SG.Parent = PlayerGui end
        cfg._gui = SG
        Config.State.ToggleIconsGui = SG
        if not cfg._uisConn then
            cfg._uisConn = UIS.InputChanged:Connect(function(input, gp)
                if not cfg._activeDrag then return end
                if not cfg.Draggable then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                and input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                local data = cfg._icons[cfg._activeDrag]
                if not data or not data.root then return end
                local delta = input.Position - cfg._dragStart
                data.root.Position = UDim2.new(
                    cfg._dragStartPos.X.Scale, cfg._dragStartPos.X.Offset + delta.X,
                    cfg._dragStartPos.Y.Scale, cfg._dragStartPos.Y.Offset + delta.Y
                )
            end)
        end
        if not cfg._uisEndConn then
            cfg._uisEndConn = UIS.InputEnded:Connect(function(input, gp)
                if not cfg._activeDrag then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    local key = cfg._activeDrag
                    local data = cfg._icons[key]
                    if data and data.root then
                        cfg.Positions[key] = data.root.Position
                    end
                    cfg._activeDrag = nil
                    cfg._dragStart = nil
                    cfg._dragStartPos = nil
                end
            end)
        end
        return SG
    end

    local function RestackDefaults()
        local cfg = Config.ToggleIcons
        cfg._stackCount = 0
        local needSlot = {}
        for key, data in pairs(cfg._icons) do
            if not cfg.Positions[key] then
                table.insert(needSlot, { key = key, data = data })
            end
        end
        table.sort(needSlot, function(a, b)
            local sa = a.data.SortIndex or 0
            local sb = b.data.SortIndex or 0
            if sa ~= sb then return sa < sb end
            return a.key < b.key
        end)
        for _, entry in ipairs(needSlot) do
            local pos = NextStackPosition()
            if entry.data.root then
                entry.data.root.Position = pos
            end
        end
    end

    function Fn.updateToggleIconVisual(key)
        local cfg = Config.ToggleIcons
        local data = cfg._icons[key]
        if not data or not data.root then return end
        local isOn = false
        if type(data.GetState) == "function" then
            local ok, val = pcall(data.GetState)
            if ok then isOn = val and true or false end
        end
        local onColor  = data.ColorOn or Color3.fromRGB(80, 255, 120)
        local offColor = data.ColorOff or Color3.fromRGB(255, 255, 255)
        if data.stroke then
            data.stroke.Color = isOn and onColor or offColor
            data.stroke.Transparency = isOn and 0.1 or 0.6
        end
        if data.IsImage and data.image then
            data.image.ImageColor3 = isOn and onColor or Color3.fromRGB(235, 235, 240)
            data.image.ImageTransparency = isOn and 0 or 0.15
        elseif data.label then
            data.label.TextColor3 = isOn and onColor or Color3.fromRGB(235, 235, 240)
        end
        if data.root then
            data.root.BackgroundTransparency = isOn and 0.05 or 0.25
        end
    end

    function Fn.createToggleIcon(options)
        options = options or {}
        local key = options.Key
        if not key then return end
        local cfg = Config.ToggleIcons
        if cfg._icons[key] then
            safeCall("ToggleIcon:RemoveExisting:"..key, function()
                local data = cfg._icons[key]
                if data.root then data.root:Destroy() end
                for _, c in ipairs(data.conns or {}) do
                    pcall(function() c:Disconnect() end)
                end
            end)
            cfg._icons[key] = nil
        end
        local SG = EnsureGui()
        local iconSize = cfg.IconSize
        local bgColor  = Color3.fromRGB(20, 22, 27)
        local cornerRadius = UDim.new(0, math.floor(iconSize * 0.28))
        local IconRoot = Instance.new("Frame")
        IconRoot.Name = randomString()
        IconRoot.Parent = SG
        IconRoot.AnchorPoint = Vector2.new(1, 0)
        IconRoot.BackgroundColor3 = bgColor
        IconRoot.BackgroundTransparency = 0.25
        IconRoot.BorderSizePixel = 0
        IconRoot.Size = UDim2.fromOffset(iconSize, iconSize)
        IconRoot.ZIndex = 20
        IconRoot.ClipsDescendants = false
        local UICornerIcon = Instance.new("UICorner")
        UICornerIcon.CornerRadius = cornerRadius
        UICornerIcon.Parent = IconRoot
        local UIStrokeIcon = Instance.new("UIStroke")
        UIStrokeIcon.Color = options.ColorOff or Color3.fromRGB(255, 255, 255)
        UIStrokeIcon.Thickness = 1.5
        UIStrokeIcon.Transparency = 0.6
        UIStrokeIcon.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStrokeIcon.Parent = IconRoot
        local IconLabel
        local IconImage
        if options.Image then
            IconImage = Instance.new("ImageLabel")
            IconImage.Name = randomString()
            IconImage.Parent = IconRoot
            IconImage.AnchorPoint = Vector2.new(0.5, 0.5)
            IconImage.BackgroundTransparency = 1
            IconImage.BorderSizePixel = 0
            IconImage.Position = UDim2.fromScale(0.5, 0.5)
            IconImage.Size = UDim2.fromScale(options.ImageScale or 0.7, options.ImageScale or 0.7)
            IconImage.ZIndex = 21
            IconImage.Image = options.Image
            IconImage.ImageColor3 = Color3.fromRGB(235, 235, 240)
            IconImage.ImageTransparency = 0
            IconImage.ScaleType = Enum.ScaleType.Fit
            IconImage.ResampleMode = Enum.ResamplerMode.Bilinear
        else
            IconLabel = Instance.new("TextLabel")
            IconLabel.Name = randomString()
            IconLabel.Parent = IconRoot
            IconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
            IconLabel.BackgroundTransparency = 1
            IconLabel.BorderSizePixel = 0
            IconLabel.Position = UDim2.fromScale(0.5, 0.5)
            IconLabel.Size = UDim2.fromScale(0.85, 0.85)
            IconLabel.ZIndex = 21
            IconLabel.Font = Enum.Font.GothamBold
            IconLabel.Text = options.Text or key:sub(1, 4):upper()
            IconLabel.TextScaled = true
            IconLabel.TextWrapped = true
            IconLabel.TextTransparency = 0
            IconLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
        end
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Name = "ClickBtn"
        ClickBtn.Size = UDim2.fromScale(1, 1)
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""
        ClickBtn.ZIndex = 22
        ClickBtn.Parent = IconRoot
        local data = {
            root    = IconRoot,
            stroke  = UIStrokeIcon,
            label   = IconLabel,
            image   = IconImage,
            btn     = ClickBtn,
            conns   = {},
            GetState = options.GetState,
            ColorOn  = options.ColorOn,
            ColorOff = options.ColorOff,
            SortIndex = options.SortIndex or 0,
            IsImage  = options.Image ~= nil,
        }
        cfg._icons[key] = data
        local clickConn
        clickConn = ClickBtn.MouseButton1Click:Connect(function()
            local current = false
            if type(data.GetState) == "function" then
                local ok, val = pcall(data.GetState)
                if ok then current = val and true or false end
            end
            local newVal = not current
            if type(options.OnToggle) == "function" then
                safeCall("ToggleIcon:OnClick:"..key, function() options.OnToggle(newVal) end)
            end
            task.defer(function()
                Fn.updateToggleIconVisual(key)
            end)
        end)
        table.insert(data.conns, clickConn)
        local pressConn
        pressConn = ClickBtn.InputBegan:Connect(function(input)
            if not cfg.Draggable then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                cfg._activeDrag   = key
                cfg._dragStart    = input.Position
                cfg._dragStartPos = IconRoot.Position
            end
        end)
        table.insert(data.conns, pressConn)
        local releaseConn
        releaseConn = ClickBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                if cfg._activeDrag == key then
                    local data2 = cfg._icons[key]
                    if data2 and data2.root then
                        cfg.Positions[key] = data2.root.Position
                    end
                    cfg._activeDrag = nil
                    cfg._dragStart = nil
                    cfg._dragStartPos = nil
                end
            end
        end)
        table.insert(data.conns, releaseConn)
        if cfg.Positions[key] then
            IconRoot.Position = cfg.Positions[key]
        else
            IconRoot.Position = UDim2.new(1, -cfg.AnchorXOffset - iconSize, 0, cfg.AnchorYOffset)
        end
        RestackDefaults()
        Fn.updateToggleIconVisual(key)
        return data
    end

    function Fn.removeToggleIcon(key)
        local cfg = Config.ToggleIcons
        local data = cfg._icons[key]
        if not data then return end
        if cfg._activeDrag == key then
            cfg._activeDrag = nil
            cfg._dragStart = nil
            cfg._dragStartPos = nil
        end
        safeCall("ToggleIcon:Remove:"..key, function()
            if data.root then data.root:Destroy() end
            for _, c in ipairs(data.conns or {}) do
                pcall(function() c:Disconnect() end)
            end
        end)
        cfg._icons[key] = nil
        RestackDefaults()
        local empty = true
        for _ in pairs(cfg._icons) do empty = false; break end
        if empty then
            if cfg._uisConn then
                pcall(function() cfg._uisConn:Disconnect() end)
                cfg._uisConn = nil
            end
            if cfg._uisEndConn then
                pcall(function() cfg._uisEndConn:Disconnect() end)
                cfg._uisEndConn = nil
            end
            if cfg._gui then
                pcall(function() cfg._gui:Destroy() end)
                cfg._gui = nil
            end
            Config.State.ToggleIconsGui = nil
            cfg._stackCount = 0
        end
    end

    function Fn.setToggleIconsDraggable(enabled)
        Config.ToggleIcons.Draggable = enabled and true or false
    end

    function Fn.createTargetIcon(opts)
        opts = opts or {}
        local key = opts.Key
        if not key then return end
        local cfg = Config.ToggleIcons
        if cfg._icons[key] then
            safeCall("TargetIcon:RemoveExisting:"..key, function()
                local data = cfg._icons[key]
                if data.root then data.root:Destroy() end
                for _, c in ipairs(data.conns or {}) do
                    pcall(function() c:Disconnect() end)
                end
            end)
            cfg._icons[key] = nil
        end
        local SG = EnsureGui()
        local iconSize = cfg.IconSize
        local bgColor  = Color3.fromRGB(20, 22, 27)
        local cornerRadius = UDim.new(0, math.floor(iconSize * 0.28))
        local IconRoot = Instance.new("Frame")
        IconRoot.Name = randomString()
        IconRoot.Parent = SG
        IconRoot.AnchorPoint = Vector2.new(1, 0)
        IconRoot.BackgroundColor3 = bgColor
        IconRoot.BackgroundTransparency = 0.20
        IconRoot.BorderSizePixel = 0
        IconRoot.Size = UDim2.fromOffset(iconSize, iconSize)
        IconRoot.ZIndex = 20
        IconRoot.ClipsDescendants = false
        local UICornerIcon = Instance.new("UICorner")
        UICornerIcon.CornerRadius = cornerRadius
        UICornerIcon.Parent = IconRoot
        local UIStrokeIcon = Instance.new("UIStroke")
        UIStrokeIcon.Color = Color3.fromRGB(255, 255, 255)
        UIStrokeIcon.Thickness = 1.5
        UIStrokeIcon.Transparency = 0.4
        UIStrokeIcon.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        UIStrokeIcon.Parent = IconRoot
        local IconLabel = Instance.new("TextLabel")
        IconLabel.Name = randomString()
        IconLabel.Parent = IconRoot
        IconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        IconLabel.BackgroundTransparency = 1
        IconLabel.BorderSizePixel = 0
        IconLabel.Position = UDim2.fromScale(0.5, 0.5)
        IconLabel.Size = UDim2.fromScale(0.85, 0.85)
        IconLabel.ZIndex = 21
        IconLabel.Font = Enum.Font.GothamBold
        IconLabel.Text = "?"
        IconLabel.TextScaled = true
        IconLabel.TextWrapped = true
        IconLabel.TextTransparency = 0
        IconLabel.TextColor3 = Color3.fromRGB(235, 235, 240)
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Name = "ClickBtn"
        ClickBtn.Size = UDim2.fromScale(1, 1)
        ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""
        ClickBtn.ZIndex = 22
        ClickBtn.Parent = IconRoot
        local data = {
            root    = IconRoot,
            stroke  = UIStrokeIcon,
            label   = IconLabel,
            btn     = ClickBtn,
            conns   = {},
            GetMode = opts.GetMode,
            SetMode = opts.SetMode,
            SortIndex = opts.SortIndex or 100,
        }
        cfg._icons[key] = data
        local clickConn
        clickConn = ClickBtn.MouseButton1Click:Connect(function()
            if type(data.SetMode) ~= "function" then return end
            local shared = Config.TargetIconShared
            local current = "?"
            if type(data.GetMode) == "function" then
                local ok, cur = pcall(data.GetMode); if ok then current = cur end
            end
            local idx = 1
            for i, v in ipairs(shared.ModeList) do
                if v == current then idx = i; break end
            end
            local nextIdx = (idx % #shared.ModeList) + 1
            local nextMode = shared.ModeList[nextIdx]
            safeCall("TargetIcon:Cycle:"..key, function()
                data.SetMode(nextMode)
            end)
            task.defer(function()
                Fn.updateTargetIconVisual(key)
            end)
        end)
        table.insert(data.conns, clickConn)
        local pressConn
        pressConn = ClickBtn.InputBegan:Connect(function(input)
            if not cfg.Draggable then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                cfg._activeDrag = key
                cfg._dragStart = input.Position
                cfg._dragStartPos = IconRoot.Position
            end
        end)
        table.insert(data.conns, pressConn)
        local releaseConn
        releaseConn = ClickBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                if cfg._activeDrag == key then
                    local data2 = cfg._icons[key]
                    if data2 and data2.root then
                        cfg.Positions[key] = data2.root.Position
                    end
                    cfg._activeDrag = nil
                    cfg._dragStart = nil
                    cfg._dragStartPos = nil
                end
            end
        end)
        table.insert(data.conns, releaseConn)
        if cfg.Positions[key] then
            IconRoot.Position = cfg.Positions[key]
        else
            IconRoot.Position = UDim2.new(1, -cfg.AnchorXOffset - iconSize, 0, cfg.AnchorYOffset)
        end
        RestackDefaults()
        Fn.updateTargetIconVisual(key)
        return data
    end

    function Fn.updateTargetIconVisual(key)
        local cfg = Config.ToggleIcons
        local data = cfg._icons[key]
        if not data or not data.root then return end
        if type(data.GetMode) ~= "function" then return end
        local shared = Config.TargetIconShared
        local mode = "?"
        local ok, m = pcall(data.GetMode); if ok then mode = m end
        local label = shared.Labels[mode] or (mode and mode:sub(1, 1)) or "?"
        local color = shared.Colors[mode] or Color3.fromRGB(255, 255, 255)
        if data.label then
            data.label.Text = label
            data.label.TextColor3 = color
        end
        if data.stroke then
            data.stroke.Color = color
            data.stroke.Transparency = 0.2
        end
        if data.root then
            data.root.BackgroundTransparency = 0.15
        end
    end

    function Fn.createGunAimTargetIcon()
        return Fn.createTargetIcon({
            Key = "GunAimTargetIcon",
            SortIndex = 100,
            GetMode = function() return Config.GunAim.TargetMode end,
            SetMode = function(mode)
                Config.GunAim.TargetMode = mode
                pcall(function()
                    if Library and Library.SetDropdownValue then
                        Options.GunAimTarget:SetValue(mode)
                    end
                end)
            end,
        })
    end

    function Fn.createToFAimV2TargetIcon()
        return Fn.createTargetIcon({
            Key = "ToFAimV2TargetIcon",
            SortIndex = 101,
            GetMode = function()
                local m = Config.ToFAimV2.TargetMode
                return m == "Survivors" and "Survivor" or m
            end,
            SetMode = function(mode)
                local tofMode = mode == "Survivor" and "Survivors" or mode
                Config.ToFAimV2.TargetMode = tofMode
                Config.ToFAimV1.TargetMode = tofMode
                local iconMode = tofMode == "Survivors" and "Survivor" or tofMode
                Config.GunAim.TargetMode = iconMode
                if ToFV2_RefreshTargetButtons then ToFV2_RefreshTargetButtons() end
                pcall(function()
                    if Library and Library.SetDropdownValue then
                        Options.ToFAimV2Target:SetValue(tofMode)
                    end
                end)
                pcall(function()
                    if Options and Options.ToFAimV1Target then
                        Options.ToFAimV1Target:SetValue(tofMode)
                    end
                end)
                Fn.updateTargetIconVisual("ToFAimV1TargetIcon")
            end,
        })
    end

    function Fn.createToFAimV1TargetIcon()
        return Fn.createTargetIcon({
            Key = "ToFAimV1TargetIcon",
            SortIndex = 102,
            GetMode = function()
                local m = Config.ToFAimV1.TargetMode
                return m == "Survivors" and "Survivor" or m
            end,
            SetMode = function(mode)
                local tofMode = mode == "Survivor" and "Survivors" or mode
                Config.ToFAimV1.TargetMode = tofMode
                Config.ToFAimV2.TargetMode = tofMode
                local iconMode = tofMode == "Survivors" and "Survivor" or tofMode
                Config.GunAim.TargetMode = iconMode
                if ToFV2_RefreshTargetButtons then ToFV2_RefreshTargetButtons() end
                pcall(function()
                    if Options and Options.ToFAimV1Target then
                        Options.ToFAimV1Target:SetValue(tofMode)
                    end
                end)
                pcall(function()
                    if Library and Library.SetDropdownValue and Options and Options.ToFAimV2Target then
                        Options.ToFAimV2Target:SetValue(tofMode)
                    end
                end)
                Fn.updateTargetIconVisual("ToFAimV2TargetIcon")
            end,
        })
    end

    function Fn.CycleToFTargetModeSync()
        local shared = Config.TargetIconShared
        local current = Config.ToFAimV1.TargetMode or "Killer"
        local idx = 1
        for i, v in ipairs(shared.ModeList) do
            local cur = current
            if cur == "Survivors" then cur = "Survivor" end
            if v == cur then idx = i; break end
        end
        local nextIdx = (idx % #shared.ModeList) + 1
        local nextMode = shared.ModeList[nextIdx]
        local tofMode = nextMode == "Survivor" and "Survivors" or nextMode
        Config.ToFAimV1.TargetMode = tofMode
        Config.ToFAimV2.TargetMode = tofMode
        local iconMode = tofMode == "Survivors" and "Survivor" or tofMode
        Config.GunAim.TargetMode = iconMode
        if ToFV2_RefreshTargetButtons then ToFV2_RefreshTargetButtons() end
        pcall(function()
            if Options and Options.ToFAimV1Target then
                Options.ToFAimV1Target:SetValue(tofMode)
            end
        end)
        pcall(function()
            if Options and Options.ToFAimV2Target then
                Options.ToFAimV2Target:SetValue(tofMode)
            end
        end)
        Fn.updateTargetIconVisual("ToFAimV1TargetIcon")
        Fn.updateTargetIconVisual("ToFAimV2TargetIcon")
        Fn.updateTargetIconVisual("GunAimTargetIcon")
        if notify then notify("ToF Target Sync", "Target: " .. tofMode, 1.5) end
    end

    function Fn.SetupToFTargetCycleKeybind(keybindValue)
        if Config.State.ToFTargetCycleKeybindConn then
            pcall(function() Config.State.ToFTargetCycleKeybindConn:Disconnect() end)
            Config.State.ToFTargetCycleKeybindConn = nil
        end
        if not keybindValue or keybindValue == "None" then
            return
        end
        local keyCode = keybindValue
        if type(keyCode) == "string" then
            keyCode = Enum.KeyCode[keyCode]
        end
        if not keyCode then return end
        Config.State.ToFTargetCycleKeybindConn = UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == keyCode then
                safeCall("ToF Target Cycle Keybind", function()
                    Fn.CycleToFTargetModeSync()
                end)
            end
        end)
    end

    function Fn.createFlowstateToggleButton()
        Fn.createToggleIcon({
            Key       = "Flowstate",
            Text      = "FLOW",
            ColorOn   = Color3.fromRGB(255, 180, 60),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 1,
            GetState  = function() return Config.Flowstate.Enabled end,
            OnToggle  = function(v)
                Config.Flowstate.Enabled = v
                if v then Fn.startFlowstate() else Fn.stopFlowstate() end
                pcall(function() Toggles.FlowstateToggle:SetValue(v) end)
                if notify then notify("Flowstate", v and "Enabled" or "Disabled", 2) end
            end,
        })
        Config.State.FlowstateToggleButton = Config.ToggleIcons._icons.Flowstate and Config.ToggleIcons._icons.Flowstate.root or nil
    end
    function Fn.removeFlowstateToggleButton()
        Fn.removeToggleIcon("Flowstate")
        Config.State.FlowstateToggleButton = nil
    end

    function Fn.createSpeedBoostToggleButton()
        Fn.createToggleIcon({
            Key       = "SpeedBoost",
            Text      = "SPD",
            ColorOn   = Color3.fromRGB(80, 220, 255),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 2,
            GetState  = function() return Config.Movement.SpeedBoost.Enabled end,
            OnToggle  = function(v)
                Config.Movement.SpeedBoost.Enabled = v
                if v then Fn.applySpeedBoost() else Fn.disableSpeedBoost() end
                pcall(function() Toggles.SpeedBoostToggle:SetValue(v) end)
                if notify then notify("Speed Boost", v and "Enabled" or "Disabled", 2) end
            end,
        })
        Config.State.SpeedBoostToggleButton = Config.ToggleIcons._icons.SpeedBoost and Config.ToggleIcons._icons.SpeedBoost.root or nil
    end
    function Fn.removeSpeedBoostToggleButton()
        Fn.removeToggleIcon("SpeedBoost")
        Config.State.SpeedBoostToggleButton = nil
    end

    function Fn.createNoclipToggleButton()
        Fn.createToggleIcon({
            Key       = "Noclip",
            Text      = "CLIP",
            ColorOn   = Color3.fromRGB(255, 80, 120),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 3,
            GetState  = function() return Config.Noclip.Enabled end,
            OnToggle  = function(v)
                Fn.setNoclip(v)
                pcall(function() Toggles.NoclipToggle:SetValue(v) end)
            end,
        })
        Config.State.NoclipToggleButton = Config.ToggleIcons._icons.Noclip and Config.ToggleIcons._icons.Noclip.root or nil
    end
    function Fn.removeNoclipToggleButton()
        Fn.removeToggleIcon("Noclip")
        Config.State.NoclipToggleButton = nil
    end

    function Fn.createInvisibleToggleButton()
        Fn.createToggleIcon({
            Key       = "Invisible",
            Text      = "INVIS",
            ColorOn   = Color3.fromRGB(80, 180, 255),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 8,
            GetState  = function() return Config.Invisible.Enabled end,
            OnToggle  = function(v)
                local ok = pcall(function() Toggles.InvisibleToggle:SetValue(v) end)
                if not ok then Fn.setInvisible(v) end
            end,
        })
        Config.State.InvisibleToggleButton = Config.ToggleIcons._icons.Invisible and Config.ToggleIcons._icons.Invisible.root or nil
    end
    function Fn.removeInvisibleToggleButton()
        Fn.removeToggleIcon("Invisible")
        Config.State.InvisibleToggleButton = nil
    end

    function Fn.createFlyToggleButton()
        Fn.createToggleIcon({
            Key       = "Fly",
            Text      = "FLY",
            ColorOn   = Color3.fromRGB(120, 255, 120),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 4,
            GetState  = function() return Config.Fly.Enabled end,
            OnToggle  = function(v)
                Fn.setFly(v)
                pcall(function() Toggles.FlyEnabled:SetValue(v) end)
            end,
        })
        Config.State.FlyToggleButton = Config.ToggleIcons._icons.Fly and Config.ToggleIcons._icons.Fly.root or nil
    end
    function Fn.removeFlyToggleButton()
        Fn.removeToggleIcon("Fly")
        Config.State.FlyToggleButton = nil
    end

    function Fn.createFleeToggleButton()
        Fn.createToggleIcon({
            Key       = "Flee",
            Text      = "FLEE",
            ColorOn   = Color3.fromRGB(255, 120, 80),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 5,
            GetState  = function() return Config.Auto.Flee.Enabled end,
            OnToggle  = function(v)
                Config.Auto.Flee.Enabled = v
                pcall(function() Toggles.AutoFleeKiller:SetValue(v) end)
                if notify then notify("Auto Flee Killer", v and "Enabled" or "Disabled", 2) end
            end,
        })
        Config.State.FleeToggleButton = Config.ToggleIcons._icons.Flee and Config.ToggleIcons._icons.Flee.root or nil
    end
    function Fn.removeFleeToggleButton()
        Fn.removeToggleIcon("Flee")
        Config.State.FleeToggleButton = nil
    end

    function Fn.createAutoParryToggleButton()
        Fn.createToggleIcon({
            Key       = "AutoParry",
            Text      = "PARRY",
            ColorOn   = Color3.fromRGB(255, 215, 80),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 6,
            GetState  = function() return Config.Auto.Parry end,
            OnToggle  = function(v)
                Config.Auto.Parry = v
                if not v then
                    if Config.State.ParryCircle then
                        Config.State.ParryCircle:Destroy()
                        Config.State.ParryCircle = nil
                    end
                    Config.Auto.ParryVisual.Enabled = false
                    pcall(function() Toggles.ShowParryRange:SetValue(false) end)
                end
                pcall(function() Toggles.AutoParry:SetValue(v) end)
                if notify then notify("Auto Parry", v and "Enabled" or "Disabled", 2) end
            end,
        })
        Config.State.AutoParryToggleButton = Config.ToggleIcons._icons.AutoParry and Config.ToggleIcons._icons.AutoParry.root or nil
    end
    function Fn.removeAutoParryToggleButton()
        Fn.removeToggleIcon("AutoParry")
        Config.State.AutoParryToggleButton = nil
    end

    function Fn.createInstantEscapeToggleButton()
        Fn.createToggleIcon({
            Key       = "InstantEscape",
            Text      = "ESC",
            ColorOn   = Color3.fromRGB(120, 255, 180),
            ColorOff  = Color3.fromRGB(255, 255, 255),
            SortIndex = 7,
            GetState  = function() return false end,
            OnToggle  = function(_v)
                task.defer(function() Fn.updateToggleIconVisual("InstantEscape") end)
                safeCall("InstantEscape Icon", function()
                    Fn.teleportToFinishLine()
                    if notify then notify("Instant Escape", "Teleported to finish line", 2) end
                end)
            end,
        })
        Config.State.InstantEscapeToggleButton = Config.ToggleIcons._icons.InstantEscape and Config.ToggleIcons._icons.InstantEscape.root or nil
    end
    function Fn.removeInstantEscapeToggleButton()
        Fn.removeToggleIcon("InstantEscape")
        Config.State.InstantEscapeToggleButton = nil
    end

    local function resolveMenuIconAsset()
        if Config and Config.MenuToggle then
            local a = Config.MenuToggle.IconAsset
            if type(a) == "string" and a ~= "" then return a end
            if type(a) == "number" then return "rbxassetid://" .. tostring(a) end
            if type(Config.MenuToggle.IconImage) == "string" and Config.MenuToggle.IconImage ~= "" then
                return Config.MenuToggle.IconImage
            end
        end

        local libIcon
        pcall(function()
            if Library and Library.Window and Library.Window.Icon ~= nil then
                libIcon = Library.Window.Icon
            end
        end)
        if type(libIcon) == "string" and libIcon ~= "" then return libIcon end
        if type(libIcon) == "number" then return "rbxassetid://" .. tostring(libIcon) end
        return "rbxassetid://91112706169806"
    end

    function Fn.toggleMenu(state)
        if state == nil then
            if Library and Library.Toggled ~= nil then
                state = not Library.Toggled
            else
                state = true
            end
        end
        local applied = false
        pcall(function()
            if Library and type(Library.Toggle) == "function" then
                Library:Toggle(state)
                applied = true
                return
            end
        end)
        if not applied then
            pcall(function()
                if Library and type(Library.SetToggle) == "function" then
                    Library:SetToggle(state)
                    applied = true
                    return
                end
            end)
        end
        if not applied then
            pcall(function()
                if Library and type(Library.SetVisible) == "function" then
                    Library:SetVisible(state)
                    applied = true
                    return
                end
            end)
        end
        if not applied then
            pcall(function()
                if Library then
                    local target = Library.ScreenGui
                        or Library.MainGui
                        or Library.Gui
                        or (Library.Window and Library.Window.ScreenGui)
                        or (Library.Window and Library.Window.Parent)
                    if target then
                        target.Enabled = state
                        if Library.Toggled ~= nil then Library.Toggled = state end
                        applied = true
                    end
                end
            end)
        end
        if not applied and Library then
            pcall(function() Library.Toggled = state end)
        end
        task.defer(function()
            pcall(function() Fn.updateToggleIconVisual("MenuToggle") end)
        end)
        return applied
    end

    function Fn.createMenuToggleButton()
        local iconAsset = resolveMenuIconAsset()
        Fn.createToggleIcon({
            Key        = "MenuToggle",
            Image      = iconAsset,
            ImageScale = 0.72,
            ColorOn    = Color3.fromRGB(51, 124, 255),
            ColorOff   = Color3.fromRGB(235, 235, 240),
            SortIndex  = 0,
            GetState   = function()
                if Library and Library.Toggled ~= nil then
                    return Library.Toggled and true or false
                end
                return true
            end,
            OnToggle   = function(v)
                Fn.toggleMenu(v)
                if notify then
                    notify("FALLENS Menu", v and "Menu shown" or "Menu hidden", 1.5)
                end
            end,
        })
        Config.State.MenuToggleButton = Config.ToggleIcons._icons.MenuToggle
            and Config.ToggleIcons._icons.MenuToggle.root or nil
    end
    function Fn.removeMenuToggleButton()
        Fn.removeToggleIcon("MenuToggle")
        Config.State.MenuToggleButton = nil
    end

    do
        local lastSeen = nil
        local conn
        pcall(function()
            if RunService and RunService.Heartbeat then
                conn = RunService.Heartbeat:Connect(function()
                    if not Config.ToggleIcons._icons.MenuToggle then return end
                    local cur = Library and Library.Toggled ~= nil and Library.Toggled or true
                    if cur ~= lastSeen then
                        lastSeen = cur
                        pcall(function() Fn.updateToggleIconVisual("MenuToggle") end)
                    end
                end)
                if Config.State then
                    Config.State.MenuToggleSyncConn = conn
                end
            end
        end)
    end

    return M
end

function M.Unload(Config)
    Config = Config or _Config
    if type(Config) ~= "table" then return end
    if not _Fn then return end

    pcall(function() _Fn.removeFlowstateToggleButton() end)
    pcall(function() _Fn.removeSpeedBoostToggleButton() end)
    pcall(function() _Fn.removeNoclipToggleButton() end)
    pcall(function() _Fn.removeFlyToggleButton() end)
    pcall(function() _Fn.removeFleeToggleButton() end)
    pcall(function() _Fn.removeAutoParryToggleButton() end)
    pcall(function() _Fn.removeInstantEscapeToggleButton() end)
    pcall(function() _Fn.removeToggleIcon("GunAimTargetIcon") end)
    pcall(function() _Fn.removeToggleIcon("ToFAimV2TargetIcon") end)
    pcall(function() _Fn.removeToggleIcon("ToFAimV1TargetIcon") end)
    pcall(function() _Fn.removeMenuToggleButton() end)

    if Config.State and Config.State.ToFTargetCycleKeybindConn then
        pcall(function() Config.State.ToFTargetCycleKeybindConn:Disconnect() end)
        Config.State.ToFTargetCycleKeybindConn = nil
    end
    if Config.State and Config.State.MenuToggleSyncConn then
        pcall(function() Config.State.MenuToggleSyncConn:Disconnect() end)
        Config.State.MenuToggleSyncConn = nil
    end

    local cfg = Config.ToggleIcons
    if cfg then
        if cfg._uisConn then
            pcall(function() cfg._uisConn:Disconnect() end)
            cfg._uisConn = nil
        end
        if cfg._uisEndConn then
            pcall(function() cfg._uisEndConn:Disconnect() end)
            cfg._uisEndConn = nil
        end
        if cfg._gui then
            pcall(function() cfg._gui:Destroy() end)
            cfg._gui = nil
        end
        if type(cfg._icons) == "table" then
            for k in pairs(cfg._icons) do cfg._icons[k] = nil end
        end
        if type(cfg.Positions) == "table" then
            for k in pairs(cfg.Positions) do cfg.Positions[k] = nil end
        end
        cfg._stackCount   = 0
        cfg._activeDrag   = nil
        cfg._dragStart    = nil
        cfg._dragStartPos = nil
    end
    if Config.State then
        Config.State.ToggleIconsGui = nil
        Config.State.MenuToggleButton = nil
    end
end

return M
