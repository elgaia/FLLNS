local M = {}

local _Config
local _Players
local _RunService
local _LocalPlayer

function M.Mount(env)
    env = env or {}

    local UI       = env.UI
    local Options  = env.Options
    local Config   = env.Config
    local Library  = env.Library
    local Players  = env.Players or game:GetService("Players")
    local RunService = env.RunService or game:GetService("RunService")
    local LocalPlayer = env.LocalPlayer or Players.LocalPlayer

    _Config      = Config
    _Players     = Players
    _RunService  = RunService
    _LocalPlayer = LocalPlayer

    if type(Config) ~= "table" then
        warn("[FALLENS] AvatarChanger module: env.Config is missing; aborting Mount")
        return M
    end
    if type(UI) ~= "table" or not UI.AvatarChangerBox then
        warn("[FALLENS] AvatarChanger module: env.UI.AvatarChangerBox is missing; aborting Mount")
        return M
    end

    local function AttachAccessoryLocal(char, accessory)
        if not char or not accessory then return false end
        if not (accessory:IsA("Accessory") or accessory:IsA("Hat")) then return false end
        local handle = accessory:FindFirstChild("Handle")
        if not handle then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local ok, err = pcall(function() hum:AddAccessory(accessory) end)
            if ok then
                local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
                if weld then return true end
            end
        end
        accessory.Parent = char
        local handleAtt = handle:FindFirstChildOfClass("Attachment")
        if not handleAtt then return false end
        local targetAtt = nil
        local targetPart = nil
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                local att = part:FindFirstChild(handleAtt.Name)
                if att and att:IsA("Attachment") then
                    targetAtt = att
                    targetPart = part
                    break
                end
            end
        end
        if targetAtt and targetPart then
            local oldWeld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
            if oldWeld then oldWeld:Destroy() end
            local weld = Instance.new("Weld")
            weld.Name = "AccessoryWeld"
            weld.Part0 = targetPart
            weld.Part1 = handle
            weld.C0 = targetAtt.CFrame
            weld.C1 = handleAtt.CFrame
            weld.Parent = handle
            handle.Anchored = false
            handle.CanCollide = false
            return true
        end
        pcall(function()
            accessory.Parent = char
            local oldWeld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
            if oldWeld then oldWeld:Destroy() end
            local accType = accessory.AccessoryType
            local isHeadAcc = (
                accType == Enum.AccessoryType.Hat or
                accType == Enum.AccessoryType.Hair or
                accType == Enum.AccessoryType.Face or
                accType == Enum.AccessoryType.Unknown
            )
            local anchorName = isHeadAcc and "Head" or "HumanoidRootPart"
            local anchorPart = char:FindFirstChild(anchorName) or char:FindFirstChild("HumanoidRootPart")
            if not anchorPart then return end
            local offsetCF = anchorPart.CFrame:ToObjectSpace(handle.CFrame)
            local weld = Instance.new("Weld")
            weld.Name = "AccessoryWeld"
            weld.Part0 = anchorPart
            weld.Part1 = handle
            weld.C0 = offsetCF
            weld.C1 = CFrame.new()
            weld.Parent = handle
            handle.Anchored = false
            handle.CanCollide = false
        end)
        return true
    end

    local function makeUniqueAccName(char, accessory)
        local baseName = accessory.Name
        baseName = baseName:gsub("_FLNS%d+$", "")
        accessory.Name = baseName
        local idx = 1
        local used = {}
        for _, obj in ipairs(char:GetChildren()) do
            if (obj:IsA("Accessory") or obj:IsA("Hat")) and obj ~= accessory then
                used[obj.Name] = true
            end
        end
        while used[accessory.Name] do
            idx = idx + 1
            accessory.Name = baseName .. "_FLNS" .. idx
        end
    end

    local RANDOM_IDS = {978663613,5261700291,1846241644,4993456331,424866237,4312175249,176548116,2270483006,1387071394,2705922253,10115152913,254675749,5282085572,2819144629,2342272463,3877709773,3641789924,5023103942,2298753899,5022264302,66372478,1059023987,2530406197,1992137495,402058769,1208673935,1735121788,3236271187,4797655515,8820259986,1538346377,7081300715,1648676291,2818915354,263336582,1510381464,683993767,1033636351,4004052767,7709627778,5196381745,4983064295,937392108,974086214,6004535943,744532329,2216132529,797871247,442581442,7927897698,4344692203,113408119,4439685307,670917583,5158458988,373349,2994206407,596318021,2574020621,7757117305,1780106970,3872493784,382383327,1921058820,1817915221,2799348313,189511979}

    local AC_CURRENT_AVATAR  = nil
    local AC_MORPH_SNAPSHOT  = nil
    local ac_statusLabel     = nil

    local AC = {}
    function AC.setStatus(text, color)
        if ac_statusLabel then
            pcall(function() ac_statusLabel:SetText("Status: " .. tostring(text)) end)
        end
    end

    local FLNS = {}
    FLNS.phantomModel       = nil
    FLNS.phantomConnections = {}
    FLNS.phantomReapplyConn = nil
    FLNS.phantomDestroying  = false
    FLNS.respawnHideConn    = nil

    function FLNS.getFloorOffset(char)
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return 0 end
        local hipH = hum.HipHeight
        if hipH <= 0 then hipH = 2 end
        return hipH + hrp.Size.Y * 0.5
    end

    FLNS.isItemPart = function(v)
        if v:FindFirstAncestorOfClass("Tool") then return true end
        if Config and Config.ESPItems then
            local cur = v
            while cur do
                if Config.ESPItems[cur.Name] then return true end
                cur = cur.Parent
            end
        end
        return false
    end

    function FLNS.hideChar(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if not char:GetAttribute("FLNS_HRPHideApplied") then
                char:SetAttribute("FLNS_HRPHideApplied", true)
                char:SetAttribute("FLNS_OrigDDT", hum.DisplayDistanceType.Name)
                char:SetAttribute("FLNS_OrigNDD", hum.NameDisplayDistance)
                char:SetAttribute("FLNS_OrigHDD", hum.HealthDisplayDistance)
            end
            hum.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance   = 0
            hum.HealthDisplayDistance = 0
        end
        for _, v in ipairs(char:GetDescendants()) do
            if FLNS.isItemPart(v) then continue end
            if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                if v.Name ~= "HumanoidRootPart" then
                    if not v:GetAttribute("FLNS_Hidden") then
                        v:SetAttribute("FLNS_Hidden", true)
                        v:SetAttribute("FLNS_OrigT", v.Transparency)
                        if v:IsA("BasePart") then
                            v:SetAttribute("FLNS_OrigCS", v.CastShadow)
                        end
                    end
                    pcall(function() v.Transparency = 1 end)
                    if v:IsA("BasePart") then
                        pcall(function() v.CastShadow = false end)
                    end
                end
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                if not v:GetAttribute("FLNS_Hidden") then
                    v:SetAttribute("FLNS_Hidden", true)
                    v:SetAttribute("FLNS_OrigE", v.Enabled)
                end
                pcall(function() v.Enabled = false end)
            end
        end
    end

    function FLNS.rehideMarked(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and char:GetAttribute("FLNS_HRPHideApplied") then
            hum.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance   = 0
            hum.HealthDisplayDistance = 0
        end
        for _, v in ipairs(char:GetDescendants()) do
            if v:GetAttribute("FLNS_Hidden") then
                if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                    if v.Name ~= "HumanoidRootPart" then
                        pcall(function() v.Transparency = 1 end)
                        if v:IsA("BasePart") then
                            pcall(function() v.CastShadow = false end)
                        end
                    end
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                    pcall(function() v.Enabled = false end)
                end
            end
        end
    end

    function FLNS.connectHideConn(char)
        if FLNS.respawnHideConn then
            pcall(function() FLNS.respawnHideConn:Disconnect() end)
            FLNS.respawnHideConn = nil
        end
        FLNS.respawnHideConn = char.DescendantAdded:Connect(function(v)
            if FLNS.isItemPart(v) then return end
            if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                if v.Name ~= "HumanoidRootPart" then
                    if not v:GetAttribute("FLNS_Hidden") then
                        v:SetAttribute("FLNS_Hidden", true)
                        v:SetAttribute("FLNS_OrigT", v.Transparency)
                        if v:IsA("BasePart") then
                            v:SetAttribute("FLNS_OrigCS", v.CastShadow)
                        end
                    end
                    pcall(function() v.Transparency = 1 end)
                    if v:IsA("BasePart") then
                        pcall(function() v.CastShadow = false end)
                    end
                end
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                if not v:GetAttribute("FLNS_Hidden") then
                    v:SetAttribute("FLNS_Hidden", true)
                    v:SetAttribute("FLNS_OrigE", v.Enabled)
                end
                pcall(function() v.Enabled = false end)
            end
        end)
        return FLNS.respawnHideConn
    end

    function FLNS.showChar(char)
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            local ddtName = char:GetAttribute("FLNS_OrigDDT")
            if ddtName then
                pcall(function()
                    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType[ddtName]
                        or Enum.HumanoidDisplayDistanceType.Subject
                end)
                hum.NameDisplayDistance   = char:GetAttribute("FLNS_OrigNDD") or 100
                hum.HealthDisplayDistance = char:GetAttribute("FLNS_OrigHDD") or 100
                char:SetAttribute("FLNS_OrigDDT", nil)
                char:SetAttribute("FLNS_OrigNDD", nil)
                char:SetAttribute("FLNS_OrigHDD", nil)
                char:SetAttribute("FLNS_HRPHideApplied", nil)
            else
                hum.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.Subject
                hum.NameDisplayDistance   = 100
                hum.HealthDisplayDistance = 100
            end
        end
        for _, v in ipairs(char:GetDescendants()) do
            if v:GetAttribute("FLNS_Hidden") then
                if v:IsA("BasePart") or v:IsA("Decal") or v:IsA("Texture") then
                    local origT = v:GetAttribute("FLNS_OrigT")
                    pcall(function() v.Transparency = (origT ~= nil) and origT or 0 end)
                    if v:IsA("BasePart") then
                        local origCS = v:GetAttribute("FLNS_OrigCS")
                        if origCS ~= nil then
                            pcall(function() v.CastShadow = origCS end)
                        else
                            pcall(function() v.CastShadow = true end)
                        end
                    end
                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                    local origE = v:GetAttribute("FLNS_OrigE")
                    pcall(function() v.Enabled = origE end)
                end
                v:SetAttribute("FLNS_Hidden", nil)
                v:SetAttribute("FLNS_OrigT", nil)
                v:SetAttribute("FLNS_OrigCS", nil)
                v:SetAttribute("FLNS_OrigE", nil)
            end
        end
    end

    FLNS.motorMap = {}
    function FLNS.buildMotorMap(realChar, phantomChar)
        FLNS.motorMap = {}
        if not realChar or not phantomChar then return end
        local phantomMotors = {}
        for _, m in ipairs(phantomChar:GetDescendants()) do
            if m:IsA("Motor6D") and m.Part0 and m.Part1 then
                local key = m.Part0.Name .. "\0" .. m.Part1.Name
                phantomMotors[key] = m
                if m.Name and m.Name ~= "" then
                    phantomMotors["n:" .. m.Name] = phantomMotors["n:" .. m.Name] or m
                end
            end
        end
        for _, m in ipairs(realChar:GetDescendants()) do
            if m:IsA("Motor6D") and m.Part0 and m.Part1 then
                local key = m.Part0.Name .. "\0" .. m.Part1.Name
                local pm = phantomMotors[key]
                if not pm and m.Name and m.Name ~= "" then
                    pm = phantomMotors["n:" .. m.Name]
                end
                if pm then
                    table.insert(FLNS.motorMap, { real = m, phantom = pm })
                end
            end
        end
    end

    function FLNS.preparePhantom(phantomChar)
        local hum = phantomChar:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.DisplayDistanceType   = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance   = 0
            hum.HealthDisplayDistance = 0
            hum.AutoJumpEnabled       = false
            pcall(function()
                hum.WalkSpeed = 0
                hum.JumpPower = 0
                hum.JumpHeight = 0
                hum.AutoRotate = false
                hum.PlatformStand = true
                hum.MaxHealth = 1e9
                hum.Health = 1e9
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            end)
            if not hum:FindFirstChildOfClass("Animator") then
                Instance.new("Animator", hum)
            end
        end
        for _, v in ipairs(phantomChar:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
                v.Massless   = true
                v.CanTouch   = false
                v.CanQuery   = false
                if v.Name == "HumanoidRootPart" then
                    v.Anchored = true
                else
                    v.Anchored = false
                end
                pcall(function()
                    v.AssemblyLinearVelocity = Vector3.zero
                    v.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
        for _, v in ipairs(phantomChar:GetDescendants()) do
            if v:IsA("Script") or v:IsA("LocalScript") then
                pcall(function() v:Destroy() end)
            end
        end
    end

    function FLNS.destroyPhantom(keepHidden)
        pcall(function() RunService:UnbindFromRenderStep("FLNS_PhantomSync") end)
        if FLNS.respawnHideConn then
            pcall(function() FLNS.respawnHideConn:Disconnect() end)
            FLNS.respawnHideConn = nil
        end
        FLNS.motorMap = {}
        FLNS.phantomDestroying = true
        if FLNS.phantomModel then
            pcall(function() FLNS.phantomModel:Destroy() end)
            FLNS.phantomModel = nil
        end
        FLNS.phantomDestroying = false
        for _, conn in ipairs(FLNS.phantomConnections) do
            pcall(function() conn:Disconnect() end)
        end
        FLNS.phantomConnections = {}
        local char = LocalPlayer.Character
        if char then
            if not keepHidden then
                FLNS.showChar(char)
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            local cam = workspace.CurrentCamera
            if cam and hum then
                cam.CameraSubject = hum
            end
        end
    end

    function FLNS.buildPhantom(desc, displayName)
        local char = LocalPlayer.Character
        if not char then return false, "No character" end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return false, "No humanoid" end
        FLNS.hideChar(char)
        local hiddenChar = char
        local rigType = hum.RigType
        local ok, phantomChar = pcall(function()
            return Players:CreateHumanoidModelFromDescription(desc, rigType)
        end)
        if not ok or not phantomChar then
            if not FLNS.phantomModel then
                FLNS.showChar(char)
            end
            return false, "CreateHumanoidModelFromDescription failed"
        end
        phantomChar.Name = "FLNS_Phantom_" .. (displayName or "Avatar")
        FLNS.preparePhantom(phantomChar)
        FLNS.destroyPhantom(true)
        char = LocalPlayer.Character
        if not char then
            pcall(function() phantomChar:Destroy() end)
            pcall(function() FLNS.showChar(hiddenChar) end)
            return false, "No character"
        end
        hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then
            pcall(function() phantomChar:Destroy() end)
            pcall(function() FLNS.showChar(hiddenChar) end)
            return false, "No humanoid"
        end
        FLNS.hideChar(char)
        FLNS.connectHideConn(char)
        phantomChar.Parent = workspace
        FLNS.phantomModel   = phantomChar
        FLNS.buildMotorMap(char, phantomChar)
        do
            local cam = workspace.CurrentCamera
            if cam and hum then cam.CameraSubject = hum end
        end
        do
            local realHRP    = char:FindFirstChild("HumanoidRootPart")
            local phantomHRP = phantomChar:FindFirstChild("HumanoidRootPart")
            if realHRP and phantomHRP then
                local realFloor    = FLNS.getFloorOffset(char)
                local phantomFloor = FLNS.getFloorOffset(phantomChar)
                local realBaseY    = realHRP.Position.Y - realFloor
                phantomHRP.CFrame  = CFrame.new(
                    realHRP.Position.X,
                    realBaseY + phantomFloor,
                    realHRP.Position.Z
                ) * (realHRP.CFrame - realHRP.CFrame.Position)
            end
        end
        local phantomHum = phantomChar:FindFirstChildOfClass("Humanoid")
        if phantomHum then
            pcall(function()
                phantomHum.PlatformStand = true
                phantomHum.WalkSpeed = 0
                phantomHum.AutoRotate = false
            end)
        end
        local phantomVisualParts = {}
        local phantomBaseParts = {}
        for _, v in ipairs(phantomChar:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") then
                table.insert(phantomVisualParts, v)
            end
            if v:IsA("BasePart") then
                table.insert(phantomBaseParts, v)
            end
        end
        local function syncLoop(dt)
            local realChar = LocalPlayer.Character
            if not realChar or not FLNS.phantomModel then return end
            if not FLNS.phantomModel.Parent then return end
            local realHRP    = realChar:FindFirstChild("HumanoidRootPart")
            local phantomHRP = FLNS.phantomModel:FindFirstChild("HumanoidRootPart")
            if realHRP and phantomHRP then
                local realFloor    = FLNS.getFloorOffset(realChar)
                local phantomFloor = FLNS.getFloorOffset(FLNS.phantomModel)
                local realBaseY    = realHRP.Position.Y - realFloor
                local targetCF = CFrame.new(
                    realHRP.Position.X,
                    realBaseY + phantomFloor,
                    realHRP.Position.Z
                ) * (realHRP.CFrame - realHRP.CFrame.Position)
                phantomHRP.CFrame = targetCF
                if not phantomHRP.Anchored then
                    phantomHRP.Anchored = true
                end
            end
            for i = 1, #FLNS.motorMap do
                local pair = FLNS.motorMap[i]
                local rm, pm = pair.real, pair.phantom
                if rm and pm and rm.Parent and pm.Parent then
                    pm.Transform = rm.Transform
                end
            end
            local cam = workspace.CurrentCamera
            if cam then
                local realHead = realChar:FindFirstChild("Head")
                if realHead then
                    local dist = (cam.CFrame.Position - realHead.Position).Magnitude
                    local firstPerson = dist < 1.0
                    local ltm = firstPerson and 1 or 0
                    for i = 1, #phantomVisualParts do
                        local v = phantomVisualParts[i]
                        if v.LocalTransparencyModifier ~= ltm then
                            v.LocalTransparencyModifier = ltm
                        end
                    end
                end
            end
        end
        RunService:BindToRenderStep("FLNS_PhantomSync", Enum.RenderPriority.Character.Value + 1, syncLoop)
        local _FLNSSteppedAcc = 0
        table.insert(FLNS.phantomConnections, RunService.Stepped:Connect(function(_, dt)
            if not FLNS.phantomModel or not FLNS.phantomModel.Parent then return end
            _FLNSSteppedAcc = _FLNSSteppedAcc + dt
            if _FLNSSteppedAcc < 0.1 then return end
            _FLNSSteppedAcc = 0
            for i = 1, #phantomBaseParts do
                local v = phantomBaseParts[i]
                if v.CanCollide then v.CanCollide = false end
                if not v.Massless then v.Massless = true end
                if v.CanTouch then v.CanTouch = false end
                if v.Name == "HumanoidRootPart" and not v.Anchored then
                    v.Anchored = true
                end
            end
        end))
        do
            local keepAlive = true
            table.insert(FLNS.phantomConnections, {
                Disconnect = function() keepAlive = false end
            })
            task.spawn(function()
                while keepAlive do
                    task.wait(1.5)
                    if not keepAlive then break end
                    if not FLNS.phantomModel or not FLNS.phantomModel.Parent then break end
                    local realChar = LocalPlayer.Character
                    if realChar then
                        FLNS.rehideMarked(realChar)
                    end
                    local ph = FLNS.phantomModel and FLNS.phantomModel:FindFirstChildOfClass("Humanoid")
                    if ph then
                        pcall(function()
                            if ph.Health < ph.MaxHealth then
                                ph.Health = ph.MaxHealth
                            end
                            ph.PlatformStand = true
                        end)
                    end
                end
            end)
        end
        do
            local thisPhantom = phantomChar
            local ancestryConn
            ancestryConn = thisPhantom.AncestryChanged:Connect(function(_, parent)
                if parent then return end
                if ancestryConn then pcall(function() ancestryConn:Disconnect() end) end
                if FLNS.phantomModel == thisPhantom then
                    FLNS.phantomModel = nil
                end
                if FLNS.phantomDestroying then return end
                if AC_CURRENT_AVATAR and AC_CURRENT_AVATAR.desc then
                    task.defer(function()
                        if FLNS.phantomDestroying then return end
                        if not AC_CURRENT_AVATAR then return end
                        if FLNS.phantomModel and FLNS.phantomModel.Parent then return end
                        local d = AC_CURRENT_AVATAR.desc
                        local n = AC_CURRENT_AVATAR.name
                        pcall(function() FLNS.buildPhantom(d, n) end)
                    end)
                end
            end)
            table.insert(FLNS.phantomConnections, ancestryConn)
        end
        return true, "Berhasil morph menjadi " .. (displayName or "Avatar")
    end

    local AC_MORPHCHAR
    AC_MORPHCHAR = function(char, name, id, desc, onDone, forPlayer)
        task.spawn(function()
            local okAll, errAll = xpcall(function()
                if not char or not char.Parent then return "Target character vanished" end
                local isLocalChar = (char == LocalPlayer.Character)
                if isLocalChar then
                    local ok, msg = FLNS.buildPhantom(desc, name)
                    if not ok then
                        AC.setStatus("Gagal: " .. tostring(msg), Color3.fromRGB(155, 45, 45))
                        return "Local morph failed: " .. tostring(msg)
                    end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and name then
                        pcall(function() hum.DisplayName = name end)
                    end
                    return nil
                else
                    local hum = char:WaitForChild("Humanoid", 5)
                    if not hum then return "Target has no Humanoid" end
                    local rigType = hum.RigType
                    local ok, refModel = pcall(function()
                        return Players:CreateHumanoidModelFromDescription(desc, rigType)
                    end)
                    if not ok or not refModel then return "Failed to build reference model" end
                    local snap = {
                        char = char, player = forPlayer,
                        displayName = hum.DisplayName,
                        parts = {}, accessories = {}, clothing = {}, charMeshes = {},
                        faceDecals = {}, scales = {},
                    }
                    for _, v in ipairs(char:GetChildren()) do
                        if v:IsA("Accessory") or v:IsA("Hat") then
                            table.insert(snap.accessories, v:Clone())
                        elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                            table.insert(snap.clothing, v:Clone())
                        elseif v:IsA("CharacterMesh") then
                            table.insert(snap.charMeshes, v:Clone())
                        end
                    end
                    local headSnap = char:FindFirstChild("Head")
                    if headSnap then
                        for _, d in ipairs(headSnap:GetChildren()) do
                            if d:IsA("Decal") then
                                table.insert(snap.faceDecals, { Name = d.Name, Texture = d.Texture, Face = d.Face })
                            end
                        end
                    end
                    local bcSnap = char:FindFirstChildOfClass("BodyColors")
                    if bcSnap then snap.bodyColors = bcSnap:Clone() end
                    local snapPartNames = {
                        "Head","UpperTorso","LowerTorso",
                        "RightUpperArm","RightLowerArm","RightHand",
                        "LeftUpperArm","LeftLowerArm","LeftHand",
                        "RightUpperLeg","RightLowerLeg","RightFoot",
                        "LeftUpperLeg","LeftLowerLeg","LeftFoot",
                        "Torso","Left Arm","Right Arm","Left Leg","Right Leg",
                    }
                    for _, pname in ipairs(snapPartNames) do
                        local dst = char:FindFirstChild(pname)
                        if dst and dst:IsA("BasePart") then
                            local rec = { isMesh = dst:IsA("MeshPart"), color = dst.Color }
                            if dst:IsA("MeshPart") then
                                rec.meshId    = dst.MeshId
                                rec.textureId = dst.TextureID
                            else
                                local sm = dst:FindFirstChildOfClass("SpecialMesh")
                                if sm then
                                    rec.sm = { MeshId = sm.MeshId, TextureId = sm.TextureId, Scale = sm.Scale }
                                end
                            end
                            snap.parts[pname] = rec
                        end
                    end
                    for _, sn in ipairs({"BodyHeightScale","BodyWidthScale","BodyHeadScale","BodyTypeScale","BodyProportionScale"}) do
                        local dv = hum:FindFirstChild(sn)
                        if dv then snap.scales[sn] = dv.Value end
                    end
                    if not (AC_MORPH_SNAPSHOT and AC_MORPH_SNAPSHOT.char == char) then
                        AC_MORPH_SNAPSHOT = snap
                    end
                    for _, v in ipairs(char:GetChildren()) do
                        if v:IsA("Accessory") or v:IsA("Hat")
                        or v:IsA("Shirt")       or v:IsA("Pants")
                        or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh")
                        or v:IsA("BodyColors") then
                            pcall(function() v:Destroy() end)
                        end
                    end
                    local head = char:FindFirstChild("Head")
                    if head then
                        for _, d in ipairs(head:GetChildren()) do
                            if d:IsA("Decal") then pcall(function() d:Destroy() end) end
                        end
                    end
                    local partNames = {
                        "Head","UpperTorso","LowerTorso",
                        "RightUpperArm","RightLowerArm","RightHand",
                        "LeftUpperArm","LeftLowerArm","LeftHand",
                        "RightUpperLeg","RightLowerLeg","RightFoot",
                        "LeftUpperLeg","LeftLowerLeg","LeftFoot",
                        "Torso","Left Arm","Right Arm","Left Leg","Right Leg",
                    }
                    for _, pname in ipairs(partNames) do
                        local src = refModel:FindFirstChild(pname)
                        local dst = char:FindFirstChild(pname)
                        if src and dst then
                            if src:IsA("MeshPart") and dst:IsA("MeshPart") then
                                pcall(function() dst.MeshId    = src.MeshId    end)
                                pcall(function() dst.TextureID = src.TextureID end)
                                pcall(function() dst.Color     = src.Color     end)
                            elseif src:IsA("Part") and dst:IsA("Part") then
                                pcall(function() dst.Color = src.Color end)
                                local sm = src:FindFirstChildOfClass("SpecialMesh")
                                if sm then
                                    local dm = dst:FindFirstChildOfClass("SpecialMesh")
                                    if not dm then dm = Instance.new("SpecialMesh"); dm.Parent = dst end
                                    pcall(function() dm.MeshId    = sm.MeshId    end)
                                    pcall(function() dm.TextureId = sm.TextureId end)
                                    pcall(function() dm.Scale     = sm.Scale     end)
                                end
                            end
                        end
                    end
                    local srcBC = refModel:FindFirstChildOfClass("BodyColors")
                    if srcBC then
                        local dstBC = char:FindFirstChildOfClass("BodyColors")
                        if not dstBC then dstBC = Instance.new("BodyColors"); dstBC.Parent = char end
                        for _, p in ipairs({"HeadColor3","TorsoColor3","LeftArmColor3","RightArmColor3","LeftLegColor3","RightLegColor3"}) do
                            pcall(function() dstBC[p] = srcBC[p] end)
                        end
                    end
                    local refHum = refModel:FindFirstChildOfClass("Humanoid")
                    if refHum then
                        for _, sn in ipairs({"BodyHeightScale","BodyWidthScale","BodyHeadScale","BodyTypeScale","BodyProportionScale"}) do
                            local sv = refHum:FindFirstChild(sn)
                            if sv then
                                local dv = hum:FindFirstChild(sn)
                                if not dv then dv = Instance.new("NumberValue"); dv.Name = sn; dv.Parent = hum end
                                pcall(function() dv.Value = sv.Value end)
                            end
                        end
                    end
                    for _, v in ipairs(refModel:GetChildren()) do
                        if v:IsA("Accessory") or v:IsA("Hat") then
                            local clone = v:Clone()
                            makeUniqueAccName(char, clone)
                            AttachAccessoryLocal(char, clone)
                        elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") then
                            local clone = v:Clone()
                            clone.Parent = char
                        end
                    end
                    refModel:Destroy()
                    if name then pcall(function() hum.DisplayName = name end) end
                    return nil
                end
            end, function(err)
                warn("[AvatarChanger] error:", err)
                return tostring(err)
            end)
            if onDone then
                onDone(okAll and errAll == nil, errAll)
            end
        end)
    end

    local AC_APPLYAVATAR
    AC_APPLYAVATAR = function(userid)
        task.spawn(function()
            xpcall(function()
                AC.setStatus("Fetching...", Color3.fromRGB(195, 165, 50))
                local txt  = tostring(userid):gsub("%s+", "")
                local ID   = tonumber(txt)
                local NAME = nil
                if ID then
                    local ok = pcall(function()
                        NAME = Players:GetNameFromUserIdAsync(ID)
                    end)
                    if not ok or not NAME then
                        AC.setStatus("User not found!", Color3.fromRGB(155, 45, 45))
                        return
                    end
                else
                    local ok = pcall(function()
                        ID   = Players:GetUserIdFromNameAsync(txt)
                        NAME = txt
                    end)
                    if not ok or not ID then
                        AC.setStatus("User not found!", Color3.fromRGB(155, 45, 45))
                        return
                    end
                    pcall(function() NAME = Players:GetNameFromUserIdAsync(ID) end)
                    NAME = NAME or txt
                end
                AC.setStatus("Loading avatar...", Color3.fromRGB(195, 165, 50))
                local ok_desc, DESC = pcall(function()
                    return Players:GetHumanoidDescriptionFromUserId(ID)
                end)
                if not ok_desc or not DESC then
                    AC.setStatus("Failed to load description!", Color3.fromRGB(155, 45, 45))
                    return
                end
                if FLNS.phantomReapplyConn then
                    pcall(function() FLNS.phantomReapplyConn:Disconnect() end)
                    FLNS.phantomReapplyConn = nil
                end
                if AC_CURRENT_AVATAR and AC_CURRENT_AVATAR._conn then
                    pcall(function() AC_CURRENT_AVATAR._conn:Disconnect() end)
                    AC_CURRENT_AVATAR._conn = nil
                end
                AC_CURRENT_AVATAR = {id = ID, name = NAME, desc = DESC}
                local ok_build, msg = FLNS.buildPhantom(DESC, NAME)
                if ok_build then
                    AC.setStatus("Applied: " .. NAME, Color3.fromRGB(55, 175, 55))
                    local char = LocalPlayer.Character
                    if char then
                        local hum = char:FindFirstChildOfClass("Humanoid")
                        if hum then pcall(function() hum.DisplayName = NAME end) end
                    end
                else
                    AC.setStatus("Gagal: " .. tostring(msg), Color3.fromRGB(155, 45, 45))
                    return
                end
                FLNS.phantomReapplyConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
                    if not (AC_CURRENT_AVATAR and AC_CURRENT_AVATAR.id == ID) then return end
                    if not newChar then return end
                    FLNS.hideChar(newChar)
                    FLNS.connectHideConn(newChar)
                    task.spawn(function()
                        local hum = newChar:WaitForChild("Humanoid", 5)
                        newChar:WaitForChild("HumanoidRootPart", 5)
                        pcall(function()
                            if hum then hum:GetAppliedDescription() end
                        end)
                        task.wait(0.15)
                        if not (AC_CURRENT_AVATAR and AC_CURRENT_AVATAR.id == ID) then return end
                        if not newChar or not newChar.Parent then return end
                        FLNS.buildPhantom(DESC, NAME)
                        if hum then pcall(function() hum.DisplayName = NAME end) end
                    end)
                end)
                AC_CURRENT_AVATAR._conn = FLNS.phantomReapplyConn
            end, function(err)
                AC.setStatus("Error!", Color3.fromRGB(155, 45, 45))
                warn("[AvatarChanger] error:", err)
            end)
        end)
    end
    
    local AC_APPLY_TO_PLAYER = function(targetInput)
        task.spawn(function()
            xpcall(function()
                if not AC_CURRENT_AVATAR then
                    AC.setStatus("Apply your avatar first!", Color3.fromRGB(195, 165, 50))
                    return
                end
                local txt = tostring(targetInput):gsub("%s+", "")
                if txt == "" then
                    AC.setStatus("Enter target username/ID!", Color3.fromRGB(195, 165, 50))
                    return
                end
                AC.setStatus("Searching for target...", Color3.fromRGB(195, 165, 50))
                local targetPlayer = nil
                local txtLower = txt:lower()
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        if plr.Name:lower() == txtLower or plr.DisplayName:lower() == txtLower then
                            targetPlayer = plr; break
                        end
                    end
                end
                if not targetPlayer then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer then
                            if plr.Name:lower():find(txtLower, 1, true) or plr.DisplayName:lower():find(txtLower, 1, true) then
                                targetPlayer = plr; break
                            end
                        end
                    end
                end
                local numId = tonumber(txt)
                if not targetPlayer and numId then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= LocalPlayer and plr.UserId == numId then
                            targetPlayer = plr; break
                        end
                    end
                end
                if not targetPlayer then
                    AC.setStatus("Player not found on server!", Color3.fromRGB(155, 45, 45))
                    return
                end
                local targetChar = targetPlayer.Character
                if not targetChar then
                    AC.setStatus("Character " .. targetPlayer.Name .. " not found!", Color3.fromRGB(155, 45, 45))
                    return
                end
                AC.setStatus("Applying to " .. targetPlayer.Name .. "...", Color3.fromRGB(195, 165, 50))
                AC_MORPHCHAR(targetChar, targetPlayer.DisplayName, AC_CURRENT_AVATAR.id, AC_CURRENT_AVATAR.desc, function(okM, msg)
                    if okM then
                        AC.setStatus("Applied to: " .. targetPlayer.Name, Color3.fromRGB(55, 175, 55))
                    else
                        AC.setStatus("Morph failed: " .. tostring(msg), Color3.fromRGB(155, 45, 45))
                    end
                end, targetPlayer)
            end, function(err)
                AC.setStatus("Error!", Color3.fromRGB(155, 45, 45))
            end)
        end)
    end

    local function AC_UNDO_MORPH()
        local snap = AC_MORPH_SNAPSHOT
        if not snap then
            AC.setStatus("No player morph to undo", Color3.fromRGB(195, 165, 50))
            return
        end
        local char = snap.char
        if not char or not char.Parent then
            AC_MORPH_SNAPSHOT = nil
            AC.setStatus("Target left - morph already reset by respawn", Color3.fromRGB(195, 165, 50))
            return
        end
        if snap.player and snap.player.Parent and snap.player.Character ~= char then
            AC_MORPH_SNAPSHOT = nil
            AC.setStatus("Target respawned - morph already reset", Color3.fromRGB(195, 165, 50))
            return
        end
        task.spawn(function()
            local okAll, errAll = xpcall(function()
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not hum then return "Target has no Humanoid" end
                for _, v in ipairs(char:GetChildren()) do
                    if v:IsA("Accessory") or v:IsA("Hat") or v:IsA("Shirt") or v:IsA("Pants")
                    or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh") or v:IsA("BodyColors") then
                        pcall(function() v:Destroy() end)
                    end
                end
                for pname, rec in pairs(snap.parts) do
                    local dst = char:FindFirstChild(pname)
                    if dst and dst:IsA("BasePart") then
                        pcall(function() dst.Color = rec.color end)
                        if rec.isMesh then
                            pcall(function() dst.MeshId = rec.meshId end)
                            pcall(function() dst.TextureID = rec.textureId end)
                        else
                            local sm = dst:FindFirstChildOfClass("SpecialMesh")
                            if rec.sm then
                                if not sm then
                                    sm = Instance.new("SpecialMesh")
                                    sm.Parent = dst
                                end
                                pcall(function() sm.MeshId = rec.sm.MeshId end)
                                pcall(function() sm.TextureId = rec.sm.TextureId end)
                                pcall(function() sm.Scale = rec.sm.Scale end)
                            elseif sm then
                                pcall(function() sm:Destroy() end)
                            end
                        end
                    end
                end
                local head = char:FindFirstChild("Head")
                if head then
                    for _, fd in ipairs(snap.faceDecals) do
                        pcall(function()
                            local d = Instance.new("Decal")
                            d.Name = fd.Name
                            d.Texture = fd.Texture
                            d.Face = fd.Face
                            d.Parent = head
                        end)
                    end
                end
                if snap.bodyColors then
                    pcall(function() snap.bodyColors:Clone().Parent = char end)
                end
                for _, c in ipairs(snap.charMeshes) do
                    pcall(function() c:Clone().Parent = char end)
                end
                for _, c in ipairs(snap.clothing) do
                    pcall(function() c:Clone().Parent = char end)
                end
                for _, c in ipairs(snap.accessories) do
                    pcall(function()
                        local acc = c:Clone()
                        makeUniqueAccName(char, acc)
                        AttachAccessoryLocal(char, acc)
                    end)
                end
                for sn, val in pairs(snap.scales) do
                    local dv = hum:FindFirstChild(sn)
                    if dv then pcall(function() dv.Value = val end) end
                end
                pcall(function() hum.DisplayName = snap.displayName end)
                return nil
            end, function(err)
                warn("[AvatarChanger] undo error:", err)
                return tostring(err)
            end)
            if okAll and errAll == nil then
                AC_MORPH_SNAPSHOT = nil
                AC.setStatus("Restored target's original avatar", Color3.fromRGB(55, 175, 55))
            else
                AC.setStatus("Undo failed: " .. tostring(errAll), Color3.fromRGB(155, 45, 45))
            end
        end)
    end

    Config._AvatarChangerCleanup = function()
        if FLNS.phantomReapplyConn then
            pcall(function() FLNS.phantomReapplyConn:Disconnect() end)
            FLNS.phantomReapplyConn = nil
        end
        if AC_CURRENT_AVATAR and AC_CURRENT_AVATAR._conn then
            pcall(function() AC_CURRENT_AVATAR._conn:Disconnect() end)
            AC_CURRENT_AVATAR._conn = nil
        end
        AC_CURRENT_AVATAR = nil
        AC_MORPH_SNAPSHOT = nil
        if FLNS.phantomModel or #FLNS.phantomConnections > 0 or FLNS.respawnHideConn then
            FLNS.destroyPhantom()
        end
    end

    local ac_state = { input = "", target = "" }
    ac_statusLabel = UI.AvatarChangerBox:AddLabel("Status: Idle")
    UI.AvatarChangerBox:AddInput("ACInput", { Default = "",
        Numeric = false,
        Finished = true,
        Text = "User ID / Username",
        Placeholder = "User ID or Username",
        Callback = function(Value)
            ac_state.input = Value
        end })
    UI.AvatarChangerBox:AddInput("ACTarget", { Default = "",
        Numeric = false,
        Finished = true,
        Text = "Target Player",
        Placeholder = "PlayerName or DisplayName",
        Callback = function(Value)
            ac_state.target = Value
        end })
    UI.AvatarChangerBox:AddButton({ Text = "Apply Avatar",
        Func = function()
            if ac_state.input and ac_state.input ~= "" then
                AC_APPLYAVATAR(ac_state.input)
            else
                AC.setStatus("Enter User ID/Name first!", Color3.fromRGB(195, 165, 50))
            end
        end,
     })
    UI.AvatarChangerBox:AddButton({ Text = "Apply to Player",
        Func = function()
            if ac_state.target and ac_state.target ~= "" then
                AC_APPLY_TO_PLAYER(ac_state.target)
            else
                AC.setStatus("Enter target name first!", Color3.fromRGB(195, 165, 50))
            end
        end,
     })
    UI.AvatarChangerBox:AddButton({ Text = "Undo Player Morph",
        Func = function()
            AC_UNDO_MORPH()
        end,
     })
    UI.AvatarChangerBox:AddButton({ Text = "Random Avatar",
        Func = function()
            local rnd = RANDOM_IDS[math.random(1, #RANDOM_IDS)]
            ac_state.input = tostring(rnd)
            pcall(function() Options.ACInput:SetText(tostring(rnd)) end)
            AC_APPLYAVATAR(rnd)
        end,
     })
    UI.AvatarChangerBox:AddButton({ Text = "Reset to Original",
        Func = function()
            FLNS.destroyPhantom()
            if FLNS.phantomReapplyConn then
                pcall(function() FLNS.phantomReapplyConn:Disconnect() end)
                FLNS.phantomReapplyConn = nil
            end
            AC_CURRENT_AVATAR = nil
            AC.setStatus("Reset to original", Color3.fromRGB(145, 145, 145))
        end,
     })

    M._AC = AC
    M._FLNS = FLNS
    M._state = {
        AC_CURRENT_AVATAR = function() return AC_CURRENT_AVATAR end,
        AC_MORPH_SNAPSHOT = function() return AC_MORPH_SNAPSHOT end,
    }

    return M
end

function M.Unload(Config)
    Config = Config or _Config
    if type(Config) ~= "table" then return end
    if Config._AvatarChangerCleanup then
        pcall(function() Config._AvatarChangerCleanup() end)
        Config._AvatarChangerCleanup = nil
    elseif M._FLNS then
        
        local FLNS = M._FLNS
        pcall(function()
            if FLNS.phantomReapplyConn then
                FLNS.phantomReapplyConn:Disconnect()
                FLNS.phantomReapplyConn = nil
            end
        end)
        pcall(function()
            if FLNS.phantomModel or #FLNS.phantomConnections > 0 or FLNS.respawnHideConn then
                FLNS.destroyPhantom()
            end
        end)
    end
end

return M
