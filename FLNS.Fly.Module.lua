local FlyModule = {}

local Players
local UserInputService
local RunService
local LocalPlayer
local Config
local Fn
local getRoot
local notifyFn
local IsMobile
local State

function FlyModule.Mount(opts)
    opts = opts or {}
    Players          = opts.Players
    UserInputService = opts.UserInputService
    RunService       = opts.RunService
    LocalPlayer      = opts.LocalPlayer
    Config           = opts.Config
    Fn               = opts.Fn
    getRoot          = opts.getRoot
    notifyFn         = opts.notify
    IsMobile         = opts.IsMobile == nil and false or opts.IsMobile

    if not (Players and UserInputService and RunService
            and LocalPlayer and Config and Fn and getRoot) then
        warn("[FALLENS] Fly module: missing required dependencies - aborting Mount")
        return false
    end

    if type(Config.Fly) ~= "table" then
        Config.Fly = {
            Enabled      = false,
            VehicleFly   = false,
            Speed        = 1,
            QEFly        = true,
            MobileButton = false,
            ShowButton   = false,
            Keybind      = "None",
        }
    end
    if type(Config.Fly.State) ~= "table" then
        Config.Fly.State = {}
    end
    State = Config.Fly.State

    if State.iyflyspeed         == nil then State.iyflyspeed         = 50  end
    if State.vehicleflyspeed    == nil then State.vehicleflyspeed    = 100 end
    if State.QEfly              == nil then State.QEfly              = true end
    if State.FLYING             == nil then State.FLYING             = false end
    if State.velocityHandlerName == nil then State.velocityHandlerName = "iyfly_velocity" end
    if State.gyroHandlerName    == nil then State.gyroHandlerName    = "iyfly_gyro" end

    local function sFLY(vfly)
        local plr = LocalPlayer
        local char = plr.Character or plr.CharacterAdded:Wait()
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            repeat task.wait() until char:FindFirstChildOfClass("Humanoid")
            humanoid = char:FindFirstChildOfClass("Humanoid")
        end
        if State.flyKeyDown or State.flyKeyUp then
            if State.flyKeyDown then State.flyKeyDown:Disconnect() State.flyKeyDown = nil end
            if State.flyKeyUp   then State.flyKeyUp:Disconnect()   State.flyKeyUp   = nil end
        end
        local T = getRoot(char)
        local CONTROL  = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
        local lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
        local SPEED = 0
        local function FLY()
            State.FLYING = true
            local BG = Instance.new('BodyGyro')
            local BV = Instance.new('BodyVelocity')
            BG.P = 9e4
            BG.Parent = T
            BV.Parent = T
            BG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            BG.CFrame = T.CFrame
            BV.Velocity = Vector3.new(0, 0, 0)
            BV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            task.spawn(function()
                repeat task.wait()
                    local camera = workspace.CurrentCamera
                    if not vfly and humanoid then
                        humanoid.PlatformStand = true
                    end
                    if CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0 then
                        SPEED = 50
                    elseif not (CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0) and SPEED ~= 0 then
                        SPEED = 0
                    end
                    if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
                        BV.Velocity = ((camera.CFrame.LookVector * (CONTROL.F + CONTROL.B)) + ((camera.CFrame * CFrame.new(CONTROL.L + CONTROL.R, (CONTROL.F + CONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p) - camera.CFrame.p)) * SPEED
                        lCONTROL = {F = CONTROL.F, B = CONTROL.B, L = CONTROL.L, R = CONTROL.R}
                    elseif (CONTROL.L + CONTROL.R) == 0 and (CONTROL.F + CONTROL.B) == 0 and (CONTROL.Q + CONTROL.E) == 0 and SPEED ~= 0 then
                        BV.Velocity = ((camera.CFrame.LookVector * (lCONTROL.F + lCONTROL.B)) + ((camera.CFrame * CFrame.new(lCONTROL.L + lCONTROL.R, (lCONTROL.F + lCONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0).p) - camera.CFrame.p)) * SPEED
                    else
                        BV.Velocity = Vector3.new(0, 0, 0)
                    end
                    BG.CFrame = camera.CFrame
                until not State.FLYING
                CONTROL  = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
                lCONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
                SPEED = 0
                BG:Destroy()
                BV:Destroy()
                if humanoid then humanoid.PlatformStand = false end
            end)
        end
        local iySpeed  = State.iyflyspeed
        local vehSpeed = State.vehicleflyspeed
        State.flyKeyDown = UserInputService.InputBegan:Connect(function(input, processed)
            if processed then return end
            if input.KeyCode == Enum.KeyCode.W then
                CONTROL.F =  (vfly and vehSpeed or iySpeed)
            elseif input.KeyCode == Enum.KeyCode.S then
                CONTROL.B = -(vfly and vehSpeed or iySpeed)
            elseif input.KeyCode == Enum.KeyCode.A then
                CONTROL.L = -(vfly and vehSpeed or iySpeed)
            elseif input.KeyCode == Enum.KeyCode.D then
                CONTROL.R =  (vfly and vehSpeed or iySpeed)
            elseif input.KeyCode == Enum.KeyCode.E and State.QEfly then
                CONTROL.Q =  (vfly and vehSpeed or iySpeed) * 2
            elseif input.KeyCode == Enum.KeyCode.Q and State.QEfly then
                CONTROL.E = -(vfly and vehSpeed or iySpeed) * 2
            end
            pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Track end)
        end)
        State.flyKeyUp = UserInputService.InputEnded:Connect(function(input, processed)
            if processed then return end
            if     input.KeyCode == Enum.KeyCode.W then CONTROL.F = 0
            elseif input.KeyCode == Enum.KeyCode.S then CONTROL.B = 0
            elseif input.KeyCode == Enum.KeyCode.A then CONTROL.L = 0
            elseif input.KeyCode == Enum.KeyCode.D then CONTROL.R = 0
            elseif input.KeyCode == Enum.KeyCode.E then CONTROL.Q = 0
            elseif input.KeyCode == Enum.KeyCode.Q then CONTROL.E = 0
            end
        end)
        FLY()
    end

    local function NOFLY()
        State.FLYING = false
        if State.flyKeyDown then State.flyKeyDown:Disconnect() State.flyKeyDown = nil end
        if State.flyKeyUp   then State.flyKeyUp:Disconnect()   State.flyKeyUp   = nil end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass('Humanoid') then
            LocalPlayer.Character:FindFirstChildOfClass('Humanoid').PlatformStand = false
        end
        pcall(function() workspace.CurrentCamera.CameraType = Enum.CameraType.Custom end)
    end

    local function unmobilefly(speaker)
        pcall(function()
            State.FLYING = false
            local root = getRoot(speaker.Character)
            if root then
                local v = root:FindFirstChild(State.velocityHandlerName)
                local g = root:FindFirstChild(State.gyroHandlerName)
                if v then v:Destroy() end
                if g then g:Destroy() end
            end
            local hum = speaker.Character and speaker.Character:FindFirstChildWhichIsA("Humanoid")
            if hum then hum.PlatformStand = false end
            State._cachedMobileHum = nil
            State._cachedMobileBV  = nil
            State._cachedMobileBG  = nil
            if State.mfly1 then State.mfly1:Disconnect() State.mfly1 = nil end
            if State.mfly2 then State.mfly2:Disconnect() State.mfly2 = nil end
        end)
    end

    local function mobilefly(speaker, vfly)
        unmobilefly(speaker)
        State.FLYING = true
        local root = getRoot(speaker.Character)
        local camera = workspace.CurrentCamera
        local v3none = Vector3.new()
        local v3zero = Vector3.new(0, 0, 0)
        local v3inf  = Vector3.new(9e9, 9e9, 9e9)
        local controlModule = require(speaker.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
        local bv = Instance.new("BodyVelocity")
        bv.Name = State.velocityHandlerName
        bv.Parent = root
        bv.MaxForce = v3zero
        bv.Velocity = v3zero
        local bg = Instance.new("BodyGyro")
        bg.Name = State.gyroHandlerName
        bg.Parent = root
        bg.MaxTorque = v3inf
        bg.P = 1000
        bg.D = 50
        State._cachedMobileHum = nil
        State._cachedMobileBV  = bv
        State._cachedMobileBG  = bg
        State.mfly1 = speaker.CharacterAdded:Connect(function()
            local newRoot = getRoot(speaker.Character)
            if not newRoot then return end
            local nbv = Instance.new("BodyVelocity")
            nbv.Name = State.velocityHandlerName
            nbv.Parent = newRoot
            nbv.MaxForce = v3zero
            nbv.Velocity = v3zero
            local nbg = Instance.new("BodyGyro")
            nbg.Name = State.gyroHandlerName
            nbg.Parent = newRoot
            nbg.MaxTorque = v3inf
            nbg.P = 1000
            nbg.D = 50
            State._cachedMobileHum = nil
            State._cachedMobileBV  = nbv
            State._cachedMobileBG  = nbg
        end)
        State.mfly2 = RunService.RenderStepped:Connect(function()
            root = getRoot(speaker.Character)
            camera = workspace.CurrentCamera
            local hum           = State._cachedMobileHum
            local VelocityHandler = State._cachedMobileBV
            local GyroHandler     = State._cachedMobileBG
            if not (hum and hum.Parent) then
                hum = speaker.Character and speaker.Character:FindFirstChildWhichIsA("Humanoid")
                State._cachedMobileHum = hum
            end
            if not (VelocityHandler and VelocityHandler.Parent) then
                VelocityHandler = root and root:FindFirstChild(State.velocityHandlerName)
                State._cachedMobileBV = VelocityHandler
            end
            if not (GyroHandler and GyroHandler.Parent) then
                GyroHandler = root and root:FindFirstChild(State.gyroHandlerName)
                State._cachedMobileBG = GyroHandler
            end
            if speaker.Character and hum and root and VelocityHandler and GyroHandler then
                if VelocityHandler.MaxForce ~= v3inf then VelocityHandler.MaxForce = v3inf end
                if GyroHandler.MaxTorque ~= v3inf  then GyroHandler.MaxTorque = v3inf end
                if not vfly and not hum.PlatformStand then hum.PlatformStand = true end
                GyroHandler.CFrame = camera.CoordinateFrame
                VelocityHandler.Velocity = v3none
                local direction = controlModule:GetMoveVector()
                local speedFactor = (vfly and State.vehicleflyspeed or State.iyflyspeed) * 50
                if direction.X ~= 0 then
                    VelocityHandler.Velocity = VelocityHandler.Velocity + camera.CFrame.RightVector * (direction.X * speedFactor)
                end
                if direction.Z ~= 0 then
                    VelocityHandler.Velocity = VelocityHandler.Velocity - camera.CFrame.LookVector * (direction.Z * speedFactor)
                end
            end
        end)
    end

    function Fn.setFly(enabled)
        Config.Fly.Enabled = enabled
        if enabled then
            if IsMobile then
                mobilefly(LocalPlayer, Config.Fly.VehicleFly)
            else
                sFLY(Config.Fly.VehicleFly)
            end
            if notifyFn then notifyFn("Fly", "Fly enabled", 2) end
        else
            if IsMobile then
                unmobilefly(LocalPlayer)
            else
                NOFLY()
            end
            if notifyFn then notifyFn("Fly", "Fly disabled", 2) end
        end
    end

    function Fn.setFlySpeed(value)
        State.iyflyspeed = tonumber(value) or 50
        Config.Fly.Speed = State.iyflyspeed
    end

    function Fn.setQEFly(enabled)
        State.QEfly     = enabled
        Config.Fly.QEFly = enabled
    end

    FlyModule._mounted = true
    return true
end

function FlyModule.Unload(_config)
    if not State then return end
    State.FLYING = false
    if State.flyKeyDown then State.flyKeyDown:Disconnect() State.flyKeyDown = nil end
    if State.flyKeyUp   then State.flyKeyUp:Disconnect()   State.flyKeyUp   = nil end
    if State.mfly1      then State.mfly1:Disconnect()      State.mfly1      = nil end
    if State.mfly2      then State.mfly2:Disconnect()      State.mfly2      = nil end
    State._cachedMobileHum = nil
    State._cachedMobileBV  = nil
    State._cachedMobileBG  = nil
end

return FlyModule