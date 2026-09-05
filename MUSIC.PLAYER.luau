local Module = {}
function Module.Mount(deps, section)
    local Library          = assert(deps.Library,          "[MusicPlayer] deps.Library is required")
    local Options          = deps.Options          or Library.Options
    local Toggles          = deps.Toggles          or Library.Toggles
    local LocalPlayer      = assert(deps.LocalPlayer,      "[MusicPlayer] deps.LocalPlayer is required")
    local UserInputService = assert(deps.UserInputService, "[MusicPlayer] deps.UserInputService is required")
    local RunService       = assert(deps.RunService,       "[MusicPlayer] deps.RunService is required")
    local TweenService     = assert(deps.TweenService,     "[MusicPlayer] deps.TweenService is required")
    local notify           = deps.notify or function() end
    local Config           = assert(deps.Config,           "[MusicPlayer] deps.Config is required")
    assert(section, "[MusicPlayer] section (groupbox) is required")

    if not Config._MusicPlayer then
        Config._MusicPlayer = { Sound = nil, Connections = {} }
    end
    local function mpTrackConn(conn)
        if conn and typeof(conn) == "RBXScriptConnection" then
            table.insert(Config._MusicPlayer.Connections, conn)
        end
        return conn
    end

    local function makeUI(parent, className, props)
        local obj = Instance.new(className)
        if parent ~= nil then obj.Parent = parent end
        if props then
            for k, v in pairs(props) do
                pcall(function() obj[k] = v end)
            end
        end
        return obj
    end

    local function resolveSectionContainer(sec)
        if typeof(sec) == "Instance" then
            return sec
        end
        for _, prop in ipairs({ "Container", "Handler", "Frame", "Content", "ContentFrame" }) do
            local ok, val = pcall(function() return sec[prop] end)
            if ok and val and typeof(val) == "Instance" and val:IsA("GuiObject") then
                return val
            end
        end
        local rootOk, root = pcall(function() return sec.Root end)
        if rootOk and root and typeof(root) == "Instance" then
            for _, child in ipairs(root:GetChildren()) do
                if child:IsA("Frame") and child:FindFirstChildOfClass("UIListLayout") then
                    return child
                end
            end
        end
        return nil
    end

    local function jsonEncodeString(s)
        return '"' .. s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t') .. '"'
    end

    local function jsonEncodeSongs(tbl)
        local items = {}
        for _, song in ipairs(tbl) do
            local isFile  = song.IsFile == true
            local saveId  = isFile and (song.RawPath or "") or (song.Id or "")
            local rawPath = isFile and (song.RawPath or "") or ""
            local entry = string.format(
                '{"Name":%s,"Id":%s,"Icon":%s,"RawPath":%s,"IsFile":"%s"}',
                jsonEncodeString(song.Name or ""),
                jsonEncodeString(saveId),
                jsonEncodeString(song.Icon or ""),
                jsonEncodeString(rawPath),
                tostring(isFile)
            )
            table.insert(items, entry)
        end
        return "[" .. table.concat(items, ",") .. "]"
    end

    local function jsonDecodeSongs(str)
        local result = {}
        local pos = 1
        while pos <= #str do
            local objStart = str:find("{", pos, true)
            if not objStart then break end
            local objEnd = str:find("}", objStart, true)
            if not objEnd then break end
            local obj = str:sub(objStart, objEnd)
            local entry = {}
            for key in obj:gmatch('"(%w+)"%s*:') do
                local _, valQ = obj:find('"' .. key .. '"%s*:%s*"', 1)
                if valQ then
                    local val = {}
                    local i = valQ + 1
                    while i <= #obj do
                        local c = obj:sub(i, i)
                        if c == '"' then break end
                        if c == '\\' then
                            i = i + 1
                            local esc = obj:sub(i, i)
                            local map = {['"']='"',['\\']='\\',['n']='\n',['r']='\r',['t']='\t'}
                            table.insert(val, map[esc] or esc)
                        else
                            table.insert(val, c)
                        end
                        i = i + 1
                    end
                    entry[key] = table.concat(val)
                end
            end
            if entry.Name and entry.Id and entry.Icon then table.insert(result, entry) end
            pos = objEnd + 1
        end
        return result
    end

    local MP_SAVE_FILE = "Fallens Directory/Music_Player.json"

    local function mp_canFileIO()
        return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
    end

    local function mp_saveCustomSongs(songsTable, defaultCount)
        if not mp_canFileIO() then return end
        local custom = {}
        for i = defaultCount + 1, #songsTable do
            local song = songsTable[i]
            if song and not song.FromFolder then table.insert(custom, song) end
        end
        local saveDir = MP_SAVE_FILE:match("^(.+)/[^/\\]+$") or "Fallens Directory"
        local dirOk, dirExists = pcall(isfolder, saveDir)
        if not dirOk or not dirExists then
            local made = pcall(makefolder, saveDir)
            if not made then return end
        end
        pcall(writefile, MP_SAVE_FILE, jsonEncodeSongs(custom))
    end

    local function mp_loadCustomSongs()
        if not mp_canFileIO() then return {} end
        local existOk, exists = pcall(isfile, MP_SAVE_FILE)
        if not existOk or not exists then return {} end
        local ok, content = pcall(readfile, MP_SAVE_FILE)
        if not ok or not content or content == "" then return {} end
        local ok2, decoded = pcall(jsonDecodeSongs, content)
        if not ok2 or type(decoded) ~= "table" then return {} end
        for _, s in ipairs(decoded) do
            local isFile = (s.IsFile == "true")
            if not isFile and type(s.Id) == "string" and s.Id:match("^getcustomasset://") then
                isFile = true
            end
            s.IsFile = isFile
            if isFile then
                local raw = (type(s.RawPath) == "string" and s.RawPath ~= "" and s.RawPath) or nil
                if not raw and type(s.Id) == "string" and s.Id ~= ""
                    and not s.Id:match("^rbxassetid://")
                    and not s.Id:match("^getcustomasset://") then
                    raw = s.Id
                end
                s.RawPath = raw
            end
        end
        return decoded
    end

    local MP_MUSIC_FOLDER     = "Fallens Music"
    local MP_ICON_SONG_FOLDER = "rbxthumb://type=Asset&id=13780950281&w=150&h=150"
    local MP_AUDIO_EXTS = {
        ogg = { magic = "OggS" },
        mp3 = { magic = "\255\251", alt = "ID3" },
    }

    local function mp_canFolderIO()
        return mp_canFileIO()
            and type(isfolder)   == "function"
            and type(makefolder) == "function"
            and type(listfiles)  == "function"
    end

    local function mp_ensureMusicFolder()
        if not mp_canFolderIO() then return false end
        local ok, exists = pcall(isfolder, MP_MUSIC_FOLDER)
        if not ok or not exists then
            pcall(makefolder, MP_MUSIC_FOLDER)
        end
        return true
    end

    local function mp_resolveLocalAudio(path)
        if type(getcustomasset) == "function" then
            local ok, res = pcall(getcustomasset, path)
            if ok and res and res ~= "" then return res end
        end
        if type(getsynasset) == "function" then
            local ok, res = pcall(getsynasset, path)
            if ok and res and res ~= "" then return res end
        end
        if type(getasset) == "function" then
            local ok, res = pcall(getasset, path)
            if ok and res and res ~= "" then return res end
        end
        return nil
    end

    local function mp_validateAudioFile(data, ext)
        if not data or #data < 4 then return false end
        local info = MP_AUDIO_EXTS[ext]
        if not info then return false end
        local header = data:sub(1, 4)
        if header:sub(1, #info.magic) == info.magic then return true end
        if info.alt and header:sub(1, #info.alt) == info.alt then return true end
        return false
    end

    local function mp_loadFolderSongs()
        if not mp_canFolderIO() then return {} end
        mp_ensureMusicFolder()
        local okL, files = pcall(listfiles, MP_MUSIC_FOLDER)
        if not okL or type(files) ~= "table" then return {} end
        local result = {}
        for _, path in ipairs(files) do
            local filename    = path:match("[^/\\]+$") or path
            local ext         = (filename:match("%.([^%.]+)$") or ""):lower()
            if MP_AUDIO_EXTS[ext] then
                local displayName = filename:match("^(.-)%.[^%.]+$") or filename
                local okD, data   = pcall(readfile, path)
                local canPlay     = mp_validateAudioFile(data, ext)
                local resolvedId  = nil
                if canPlay then
                    resolvedId = mp_resolveLocalAudio(path)
                end
                table.insert(result, {
                    Name    = canPlay
                                and displayName
                                or  (displayName .. " (corrupt/unsupported)"),
                    Id      = resolvedId or "",
                    Icon    = MP_ICON_SONG_FOLDER,
                    IsFile  = true,
                    FromFolder = true,
                    RawPath = path,
                    CanPlay = canPlay,
                    FileExt = ext,
                })
            end
        end
        return result
    end

    local IC = Color3.fromRGB(215, 215, 215)
    local function clickLayer(parent, zi)
        return makeUI(parent, "TextButton", {
            Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = zi or 20
        })
    end

    local MP_LUCIDE_ICONS = {
        play         = "lucide:play",
        pause        = "lucide:pause",
        skipBack     = "lucide:skip-back",
        skipForward  = "lucide:skip-forward",
    }
    local MP_ICON_FALLBACKS = {
        play         = "rbxassetid://135609604299893",
        pause        = "rbxassetid://74873705394436",
        skipBack     = "rbxassetid://70466132711334",
        skipForward  = "rbxassetid://124844823753990",
    }

    local function _mp_makeLucideIcon(parent, iconName, S, color, bsz)
        bsz = bsz or parent.Size.X.Offset
        color = color or IC
        local iconLabel = makeUI(parent, "ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, S, 0, S),
            BackgroundTransparency = 1,
            ImageColor3 = color,
            ImageTransparency = 0,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 3,
        })
        local resolved = false
        pcall(function()
            if Library and Library.SetIconMode then
                Library:SetIconMode(iconLabel, iconName)
                resolved = iconLabel.Image ~= ""
            end
        end)
        if not resolved then
            local fallback = MP_ICON_FALLBACKS[iconName == MP_LUCIDE_ICONS.play and "play"
                or iconName == MP_LUCIDE_ICONS.pause and "pause"
                or iconName == MP_LUCIDE_ICONS.skipBack and "skipBack"
                or iconName == MP_LUCIDE_ICONS.skipForward and "skipForward"
                or "play"]
            pcall(function() iconLabel.Image = fallback end)
        end
        return iconLabel
    end

    local function iconSkipBack(parent, S, color)
        return _mp_makeLucideIcon(parent, MP_LUCIDE_ICONS.skipBack, S, color)
    end
    local function iconSkipForward(parent, S, color)
        return _mp_makeLucideIcon(parent, MP_LUCIDE_ICONS.skipForward, S, color)
    end
    local function iconPlay(parent, S, color, bsz)
        return _mp_makeLucideIcon(parent, MP_LUCIDE_ICONS.play, S, color, bsz)
    end
    local function iconPause(parent, S, color, bsz)
        return _mp_makeLucideIcon(parent, MP_LUCIDE_ICONS.pause, S, color, bsz)
    end

    local function _mp_buildInfoSection(parent, MP_ICON_SONG, MP_ICON_VOL, MP_ICON_MUTE)
        task.spawn(function()
            local ContentProvider = game:GetService("ContentProvider")
            local preloadInstances = {}
            for _, id in ipairs({ MP_ICON_SONG, MP_ICON_VOL, MP_ICON_MUTE }) do
                local tmp = Instance.new("ImageLabel")
                tmp.Image = id
                table.insert(preloadInstances, tmp)
            end
            pcall(function() ContentProvider:PreloadAsync(preloadInstances) end)
            for _, img in ipairs(preloadInstances) do img:Destroy() end
        end)
        local songInfoFrame = makeUI(parent, "Frame", {
            Size = UDim2.new(1, -2, 0, 32),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2, BorderSizePixel = 0
        })
        makeUI(songInfoFrame, "UICorner", { CornerRadius = UDim.new(0, 8) })
        makeUI(songInfoFrame, "TextLabel", {
            Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 8, 0, 4),
            BackgroundTransparency = 1, Text = "NOW PLAYING",
            TextColor3 = Library.Scheme.FontColor , TextSize = 9,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left
        })
        local songNameLabel = makeUI(songInfoFrame, "TextLabel", {
            Size = UDim2.new(1, -16, 0, 16),
            Position = UDim2.new(0, 8, 0, 18),
            BackgroundTransparency = 1, Text = "Select a song",
            TextColor3 = Library.Scheme.FontColor , TextSize = 12,
            Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        return {
            songNameLabel = songNameLabel,
        }
    end

    local function _mp_buildProgressSection(parent, sound)
        local function formatTime(s)
            if not s or s < 0 then return "0:00" end
            return string.format("%d:%02d", math.floor(s/60), math.floor(s%60))
        end
        local progressOuter = makeUI(parent, "Frame", {
            Size = UDim2.new(1, -2, 0, 6),
            BackgroundColor3 = Color3.fromRGB(55, 55, 55), BorderSizePixel = 0, ZIndex = 2
        })
        makeUI(progressOuter, "UICorner", { CornerRadius = UDim.new(1, 0) })
        local progressBar = makeUI(progressOuter, "Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(130, 130, 130), BorderSizePixel = 0, ZIndex = 3
        })
        makeUI(progressBar, "UICorner", { CornerRadius = UDim.new(1, 0) })
        local progressThumb = makeUI(progressOuter, "Frame", {
            Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.fromRGB(220, 220, 220),
            BorderSizePixel = 0, ZIndex = 5, Visible = false
        })
        makeUI(progressThumb, "UICorner", { CornerRadius = UDim.new(1, 0) })
        local progressHit = makeUI(progressOuter, "TextButton", {
            Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0.5, -10),
            BackgroundTransparency = 1, Text = "", ZIndex = 10
        })
        local timeRow = makeUI(parent, "Frame", {
            Size = UDim2.new(1, -2, 0, 12), BackgroundTransparency = 1, BorderSizePixel = 0
        })
        local currentTimeLabel = makeUI(timeRow, "TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = "0:00",
            TextColor3 = Library.Scheme.FontColor , TextSize = 10,
            Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left
        })
        local totalTimeLabel = makeUI(timeRow, "TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundTransparency = 1, Text = "0:00",
            TextColor3 = Library.Scheme.FontColor , TextSize = 10,
            Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right
        })
        local isScrubbing = false
        local function getSeekRatio(inputPos)
            local outerPos  = progressOuter.AbsolutePosition
            local outerSize = progressOuter.AbsoluteSize
            return math.clamp((inputPos.X - outerPos.X) / outerSize.X, 0, 1)
        end
        local function seekTo(ratio)
            if sound.IsLoaded and sound.TimeLength and sound.TimeLength > 0 then
                sound.TimePosition = ratio * sound.TimeLength
                progressBar.Size = UDim2.new(ratio, 0, 1, 0)
                progressThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
                currentTimeLabel.Text = formatTime(ratio * sound.TimeLength)
            end
        end
        mpTrackConn(progressHit.MouseEnter:Connect(function()
            progressThumb.Visible = true
            TweenService:Create(progressOuter, TweenInfo.new(0.1), { Size = UDim2.new(1, -2, 0, 8) }):Play()
            TweenService:Create(progressBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(180, 180, 180) }):Play()
        end))
        mpTrackConn(progressHit.MouseLeave:Connect(function()
            if not isScrubbing then
                progressThumb.Visible = false
                TweenService:Create(progressOuter, TweenInfo.new(0.1), { Size = UDim2.new(1, -2, 0, 6) }):Play()
                TweenService:Create(progressBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(130, 130, 130) }):Play()
            end
        end))
        mpTrackConn(progressHit.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                isScrubbing = true; progressThumb.Visible = true; seekTo(getSeekRatio(input.Position))
            end
        end))
        mpTrackConn(UserInputService.InputChanged:Connect(function(input)
            if isScrubbing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                seekTo(getSeekRatio(input.Position))
            end
        end))
        mpTrackConn(UserInputService.InputEnded:Connect(function(input)
            if isScrubbing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                isScrubbing = false
                seekTo(getSeekRatio(input.Position))
                progressThumb.Visible = false
                TweenService:Create(progressOuter, TweenInfo.new(0.1), { Size = UDim2.new(1, -2, 0, 6) }):Play()
                TweenService:Create(progressBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(130, 130, 130) }):Play()
            end
        end))
        return {
            progressBar      = progressBar,
            progressThumb    = progressThumb,
            currentTimeLabel = currentTimeLabel,
            totalTimeLabel   = totalTimeLabel,
            isScrubbing      = function() return isScrubbing end,
            formatTime       = formatTime,
        }
    end

    local function _mp_buildControls(parent)
        local BTN_SM = 34; local BTN_LG = 44
        local ICON_SM = 14; local ICON_LG = 16
        local controlRow = makeUI(parent, "Frame", {
            Size = UDim2.new(1, -2, 0, 52), BackgroundTransparency = 1, BorderSizePixel = 0
        })
        local prevFrame = makeUI(controlRow, "Frame", {
            Size = UDim2.new(0, BTN_SM, 0, BTN_SM),
            Position = UDim2.new(0.5, -BTN_LG/2-BTN_SM-8, 0.5, -BTN_SM/2),
            BackgroundColor3 = Color3.fromRGB(48,48,48), BorderSizePixel = 0
        })
        makeUI(prevFrame, "UICorner", { CornerRadius = UDim.new(1,0) })
        makeUI(prevFrame, "UIStroke", { Color = Color3.fromRGB(80,80,80), Thickness = 1, Transparency = 0.2 })
        iconSkipBack(prevFrame, ICON_SM, IC)
        local prevClick = clickLayer(prevFrame, 20)
        local playFrame = makeUI(controlRow, "Frame", {
            Size = UDim2.new(0, BTN_LG, 0, BTN_LG),
            Position = UDim2.new(0.5, -BTN_LG/2, 0.5, -BTN_LG/2),
            BackgroundColor3 = Color3.fromRGB(55,55,55), BorderSizePixel = 0
        })
        makeUI(playFrame, "UICorner", { CornerRadius = UDim.new(1,0) })
        makeUI(playFrame, "UIStroke", { Color = Color3.fromRGB(100,100,100), Thickness = 1.2, Transparency = 0.1 })
        local playIconHolder = makeUI(playFrame, "Frame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 2 })
        iconPlay(playIconHolder, ICON_LG, IC, BTN_LG)
        local pauseIconHolder = makeUI(playFrame, "Frame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 2, Visible = false })
        iconPause(pauseIconHolder, ICON_LG, IC, BTN_LG)
        local playClick = clickLayer(playFrame, 20)
        local nextFrame = makeUI(controlRow, "Frame", {
            Size = UDim2.new(0, BTN_SM, 0, BTN_SM),
            Position = UDim2.new(0.5, BTN_LG/2+8, 0.5, -BTN_SM/2),
            BackgroundColor3 = Color3.fromRGB(48,48,48), BorderSizePixel = 0
        })
        makeUI(nextFrame, "UICorner", { CornerRadius = UDim.new(1,0) })
        makeUI(nextFrame, "UIStroke", { Color = Color3.fromRGB(80,80,80), Thickness = 1, Transparency = 0.2 })
        iconSkipForward(nextFrame, ICON_SM, IC)
        local nextClick = clickLayer(nextFrame, 20)
        mpTrackConn(prevClick.MouseEnter:Connect(function()
            TweenService:Create(prevFrame, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(68,68,68) }):Play()
        end))
        mpTrackConn(prevClick.MouseLeave:Connect(function()
            TweenService:Create(prevFrame, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(48,48,48) }):Play()
        end))
        mpTrackConn(nextClick.MouseEnter:Connect(function()
            TweenService:Create(nextFrame, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(68,68,68) }):Play()
        end))
        mpTrackConn(nextClick.MouseLeave:Connect(function()
            TweenService:Create(nextFrame, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(48,48,48) }):Play()
        end))
        mpTrackConn(playClick.MouseEnter:Connect(function()
            TweenService:Create(playFrame, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(75,75,75) }):Play()
        end))
        mpTrackConn(playClick.MouseLeave:Connect(function()
            TweenService:Create(playFrame, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(55,55,55) }):Play()
        end))
        return {
            playClick       = playClick,
            prevClick       = prevClick,
            nextClick       = nextClick,
            playIconHolder  = playIconHolder,
            pauseIconHolder = pauseIconHolder,
        }
    end

    local function _mp_buildVolumeSection(sec, MP_ICON_VOL, MP_ICON_MUTE, sound, isMutedRef, savedVolumeRef)
        local function setVolume(vol)
            vol = math.clamp(vol, 0, 1)
            sound.Volume = vol
            if not isMutedRef[1] then savedVolumeRef[1] = vol end
        end
        local volSlider = sec:AddSlider("MusicVolume", {
            Text = "Volume",
            Default = 50,
            Min = 0,
            Max = 100,
            Rounding = 0,
            Suffix = "%",
            Callback = function(v)
                local vol = v / 100
                if isMutedRef[1] and v > 0 then
                    isMutedRef[1] = false
                end
                setVolume(vol)
            end,
        })
        local muteBtn = sec:AddButton({
            Text = "Mute",
            Func = function()
                isMutedRef[1] = not isMutedRef[1]
                if isMutedRef[1] then
                    savedVolumeRef[1] = sound.Volume > 0 and sound.Volume or savedVolumeRef[1]
                    sound.Volume = 0
                    muteBtn:SetText("Unmute")
                    if volSlider and volSlider.SetValue then
                        volSlider:SetValue(0)
                    end
                else
                    setVolume(savedVolumeRef[1])
                    muteBtn:SetText("Mute")
                    if volSlider and volSlider.SetValue then
                        volSlider:SetValue(math.floor(savedVolumeRef[1] * 100))
                    end
                end
            end,
        })
        setVolume(savedVolumeRef[1])
        return {
            volSlider = volSlider,
            muteBtn   = muteBtn,
        }
    end

    local function createMusicPlayerPage(sec)
        local MP_ICON_SONG = "rbxthumb://type=Asset&id=13780950281&w=150&h=150"
        local MP_ICON_VOL  = "rbxthumb://type=Asset&id=117386765962827&w=150&h=150"
        local MP_ICON_MUTE = "rbxthumb://type=Asset&id=96383895319411&w=150&h=150"
        local DEFAULT_SONGS = {
            { Name = "Kagayaku Shunkan", Id = "rbxassetid://113287483392873", Icon = MP_ICON_SONG }
        }
        local DEFAULT_COUNT = #DEFAULT_SONGS
        local songs = {}
        for _, s in ipairs(DEFAULT_SONGS) do table.insert(songs, s) end
        for _, s in ipairs(mp_loadCustomSongs()) do
            if s.IsFile and s.RawPath then
                local resolved = mp_resolveLocalAudio(s.RawPath)
                s.Id      = resolved or ""
                s.CanPlay = (resolved ~= nil)
            elseif s.IsFile then
                s.Id = ""; s.CanPlay = false
            end
            table.insert(songs, s)
        end
        local songByName = {}
        local function rebuildSongMap()
            songByName = {}
            for _, s in ipairs(songs) do songByName[s.Name] = s end
        end
        rebuildSongMap()
        local function getSongNames()
            local names = {}
            for _, s in ipairs(songs) do table.insert(names, s.Name) end
            return names
        end
        local sound = Instance.new("Sound")
        sound.Name = "FallensMusicPlayer"; sound.Volume = 0.5
        do
            local parented = pcall(function()
                sound.Parent = game:GetService("SoundService")
            end)
            if not parented then
                pcall(function()
                    sound.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                        or LocalPlayer
                end)
            end
        end
        local isMutedRef       = { false }
        local savedVolumeRef   = { 0.5 }
        local currentSongIndex = 1
        local isPlaying        = false
        local isChangingSong   = false
        local optionsFrame6 = resolveSectionContainer(sec)
        if not optionsFrame6 then
            warn("[FALLENS] Music Player: failed to resolve ModernV2 section container; custom widgets will not be rendered.")
            return sound
        end
        local infoResult  = _mp_buildInfoSection(optionsFrame6, MP_ICON_SONG, MP_ICON_VOL, MP_ICON_MUTE)
        local progResult  = _mp_buildProgressSection(optionsFrame6, sound)
        local ctrlResult  = _mp_buildControls(optionsFrame6)
        local volResult   = _mp_buildVolumeSection(sec, MP_ICON_VOL, MP_ICON_MUTE, sound, isMutedRef, savedVolumeRef)
        local songNameLabel  = infoResult.songNameLabel
        local progressBar    = progResult.progressBar
        local progressThumb  = progResult.progressThumb
        local currentTimeLabel = progResult.currentTimeLabel
        local totalTimeLabel   = progResult.totalTimeLabel
        local formatTime     = progResult.formatTime
        local playClick      = ctrlResult.playClick
        local prevClick      = ctrlResult.prevClick
        local nextClick      = ctrlResult.nextClick
        local playIconHolder = ctrlResult.playIconHolder
        local pauseIconHolder = ctrlResult.pauseIconHolder
        local volSlider      = volResult.volSlider
        local muteBtn        = volResult.muteBtn
        local function setPlayState(playing)
            playIconHolder.Visible  = not playing
            pauseIconHolder.Visible = playing
        end
        local function playSongByName(songName, autoPlay)
            local songEntry = songByName[songName]
            if not songEntry then return end
            for i, s in ipairs(songs) do
                if s.Name == songName then currentSongIndex = i; break end
            end
            isChangingSong = true
            sound:Stop(); sound.TimePosition = 0
            if songEntry.IsFile then
                if songEntry.CanPlay == false then
                    songNameLabel.Text = "File missing, corrupt, or unsupported!"
                    isPlaying = false; setPlayState(false)
                    task.defer(function() isChangingSong = false end); return
                end
                local assigned = false
                if songEntry.Id and songEntry.Id ~= "" then
                    local ok1 = pcall(function() sound.SoundId = songEntry.Id end)
                    if ok1 then assigned = true end
                end
                if not assigned and songEntry.RawPath then
                    local resolved = mp_resolveLocalAudio(songEntry.RawPath)
                    if resolved then
                        songEntry.Id = resolved
                        local ok2 = pcall(function() sound.SoundId = resolved end)
                        if ok2 then assigned = true end
                    end
                end
                if not assigned then
                    local fmt = songEntry.FileExt and songEntry.FileExt:upper() or "audio"
                    songNameLabel.Text = "Failed to load " .. fmt .. " file!"
                    isPlaying = false; setPlayState(false)
                    task.defer(function() isChangingSong = false end); return
                end
            else
                local okSet = pcall(function() sound.SoundId = songEntry.Id end)
                if not okSet then
                    songNameLabel.Text = "Invalid sound ID!"
                    isPlaying = false; setPlayState(false)
                    task.defer(function() isChangingSong = false end); return
                end
            end
            songNameLabel.Text = songEntry.Name
            if autoPlay then
                isPlaying = true; setPlayState(true)
                local wantId = tostring(songEntry.Id)
                task.spawn(function()
                    pcall(function()
                        if not sound.IsLoaded then
                            local loaded = false
                            local conn = sound.Loaded:Connect(function() loaded = true end)
                            local t0 = os.clock()
                            while not loaded and not sound.IsLoaded and os.clock() - t0 < 8 do
                                task.wait(0.1)
                            end
                            if conn then conn:Disconnect() end
                        end
                        if sound.IsLoaded then
                            sound.TimePosition = 0; sound:Play()
                        elseif isPlaying and sound.SoundId == wantId then
                            isPlaying = false; setPlayState(false)
                            songNameLabel.Text = (songEntry.Name or "?") .. " - failed to load"
                        end
                    end)
                end)
            end
            task.defer(function() isChangingSong = false end)
        end
        local function playSong(idx, autoPlay)
            local songEntry = songs[idx]
            if not songEntry then return end
            playSongByName(songEntry.Name, autoPlay)
        end
        local playlistDropdown = sec:AddDropdown("MusicPlaylist", { Text = "Playlist",
            Values           = getSongNames(),
            Default          = songs[1] and songs[1].Name or nil,
            Multi            = false,
            Searchable = true,
            Callback         = function(value)
                if value and value ~= "" then
                    playSongByName(value, true)
                end
            end })
        local function rebuildPlaylist()
            rebuildSongMap()
            local names = getSongNames()
            Options.MusicPlaylist:SetValues(names)
        end
        sec:AddLabel("Add Custom Song")
        local songNameInput = sec:AddInput("MusicSongName", { Text = "Song Name",
            Default     = "",
            Placeholder = "Enter song name...",
            Numeric     = false,
        })
        local songIdInput = sec:AddInput("MusicSongId", { Text = "Sound ID / Path",
            Default     = "",
            Placeholder = "rbxassetid://ID  |  12345678  |  Fallens Music/song.mp3",
            Numeric     = false,
        })
        sec:AddButton({ Text = "+ Add Song",
            Func = function()
                local rawName = Options.MusicSongName.Value
                if type(rawName) == "string" then rawName = rawName:match("^%s*(.-)%s*$") end
                local rawId   = Options.MusicSongId.Value
                if type(rawId) == "string" then rawId = rawId:match("^%s*(.-)%s*$") end
                if not rawName or rawName == "" then
                    notify("Music Player", "Song name cannot be empty!", 3)
                    return
                end
                if not rawId or rawId == "" then
                    notify("Music Player", "Enter a Sound ID or local file path!", 3)
                    return
                end
                local finalId; local isFile = false
                if rawId:match("^rbxassetid://") then
                    finalId = rawId
                elseif rawId:match("^%d+$") then
                    finalId = "rbxassetid://" .. rawId
                elseif rawId:lower():match("%.mp3$") or rawId:lower():match("%.ogg$") then
                    if not mp_canFolderIO() then
                        notify("Music Player", "File IO not supported on this executor!", 3)
                        return
                    end
                    local okD, data = pcall(readfile, rawId)
                    local ext = (rawId:match("%.([^%.]+)$") or ""):lower()
                    if not mp_validateAudioFile(data, ext) then
                        notify("Music Player", "File not found or corrupt: " .. rawId, 4)
                        return
                    end
                    local resolved = mp_resolveLocalAudio(rawId)
                    if not resolved then
                        notify("Music Player", "GetCustomAsset() failed for this file!", 4)
                        return
                    end
                    finalId = resolved; isFile = true
                else
                    notify("Music Player", "Invalid input! Use ID, rbxassetid://, or .mp3/.ogg path", 4)
                    return
                end
                local finalName = rawName
                if songByName[finalName] then
                    local counter = 2
                    while songByName[finalName .. " (" .. counter .. ")"] do
                        counter = counter + 1
                    end
                    finalName = rawName .. " (" .. counter .. ")"
                end
                table.insert(songs, {
                    Name = finalName, Id = finalId, Icon = MP_ICON_SONG,
                    IsFile = isFile, RawPath = isFile and rawId or nil, CanPlay = true,
                })
                mp_saveCustomSongs(songs, DEFAULT_COUNT)
                rebuildPlaylist()
                Options.MusicSongName:SetText("")
                Options.MusicSongId:SetText("")
                notify("Music Player", "\"" .. finalName .. "\" added to playlist!", 3)
            end,
        })
        sec:AddButton({ Text = "- Remove Current Song",
            Func = function()
                local currentName = songs[currentSongIndex] and songs[currentSongIndex].Name
                if not currentName then
                    notify("Music Player", "No song selected.", 3)
                    return
                end
                if currentSongIndex <= DEFAULT_COUNT then
                    notify("Music Player", "Cannot remove default songs.", 3)
                    return
                end
                table.remove(songs, currentSongIndex)
                if currentSongIndex > #songs then currentSongIndex = #songs end
                if currentSongIndex < 1 then currentSongIndex = 1 end
                mp_saveCustomSongs(songs, DEFAULT_COUNT)
                rebuildPlaylist()
                local newName = songs[currentSongIndex] and songs[currentSongIndex].Name or nil
                if newName then
                    Options.MusicPlaylist:SetValue(newName)
                    songNameLabel.Text = newName
                else
                    songNameLabel.Text = "Select a song"
                end
                notify("Music Player", "Removed: " .. currentName, 3)
            end,
        })
        sec:AddLabel("Fallens Music Folder")
        sec:AddButton({ Text = "Scan Fallens Music Folder",
            Func = function()
                if not mp_canFolderIO() then
                    notify("Music Player", "File IO not supported on this executor!", 3)
                    return
                end
                task.spawn(function()
                    local newSongs, keptPaths = {}, {}
                    for _, s in ipairs(songs) do
                        if not s.IsFile or not s.FromFolder then
                            table.insert(newSongs, s)
                            if s.RawPath then keptPaths[s.RawPath] = true end
                        end
                    end
                    local folderSongs = mp_loadFolderSongs()
                    local added = 0
                    for _, s in ipairs(folderSongs) do
                        if not keptPaths[s.RawPath] then
                            table.insert(newSongs, s); added = added + 1
                        end
                    end
                    while #songs > 0 do table.remove(songs) end
                    for _, s in ipairs(newSongs) do table.insert(songs, s) end
                    rebuildPlaylist()
                    if #folderSongs == 0 then
                        notify("Music Player", "No MP3 or OGG files found in Fallens Music/ folder.", 4)
                    elseif added == 0 then
                        notify("Music Player", "Folder songs are already in the playlist.", 4)
                    else
                        notify("Music Player", added .. " audio file(s) found and added to playlist!", 4)
                    end
                end)
            end,
        })
        if songs[1] then
            songNameLabel.Text = songs[1].Name
        end
        mpTrackConn(playClick.MouseButton1Click:Connect(function()
            if not isPlaying then
                if not sound.SoundId or sound.SoundId == "" then
                    if songs[1] then
                        playSongByName(songs[1].Name, true)
                    end
                else
                    sound:Resume(); isPlaying = true; setPlayState(true)
                end
            else
                sound:Pause(); isPlaying = false; setPlayState(false)
            end
        end))
        mpTrackConn(nextClick.MouseButton1Click:Connect(function()
            local nextIdx = currentSongIndex % #songs + 1
            local nextName = songs[nextIdx] and songs[nextIdx].Name
            if nextName then
                Options.MusicPlaylist:SetValue(nextName)
            end
        end))
        mpTrackConn(prevClick.MouseButton1Click:Connect(function()
            local prevIdx = ((currentSongIndex - 2) % #songs) + 1
            local prevName = songs[prevIdx] and songs[prevIdx].Name
            if prevName then
                Options.MusicPlaylist:SetValue(prevName)
            end
        end))
        mpTrackConn(sound.Ended:Connect(function()
            if isChangingSong then return end
            if isPlaying then
                task.defer(function()
                    local nextIdx = currentSongIndex % #songs + 1
                    local nextName = songs[nextIdx] and songs[nextIdx].Name
                    if nextName then
                        Options.MusicPlaylist:SetValue(nextName)
                    end
                end)
            end
        end))
        local _mpTrackAcc = 0
        local _mpLastPosFloor = -1
        local _mpLastLenFloor = -1
        local _mpLastRatio    = -1
        mpTrackConn(RunService.Heartbeat:Connect(function(dt)
            if not sound.IsLoaded or not sound.TimeLength or sound.TimeLength <= 0 then return end
            if progResult.isScrubbing() then return end
            _mpTrackAcc = _mpTrackAcc + dt
            if _mpTrackAcc < 1/15 then return end
            _mpTrackAcc = 0
            local pos = sound.TimePosition or 0
            local len = sound.TimeLength
            local posFloor = math.floor(pos)
            local lenFloor = math.floor(len)
            local ratio = pos / len
            if ratio ~= _mpLastRatio then
                _mpLastRatio = ratio
                progressBar.Size = UDim2.new(ratio, 0, 1, 0)
                progressThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
            end
            if posFloor ~= _mpLastPosFloor then
                _mpLastPosFloor = posFloor
                currentTimeLabel.Text = formatTime(pos)
            end
            if lenFloor ~= _mpLastLenFloor then
                _mpLastLenFloor = lenFloor
                totalTimeLabel.Text = formatTime(len)
            end
        end))
        return sound
    end

    local sound = createMusicPlayerPage(section)
    if sound then Config._MusicPlayer.Sound = sound end
    return sound
end

function Module.Unload(Config)
    if not Config or not Config._MusicPlayer then return end
    if Config._MusicPlayer.Connections then
        for _, conn in ipairs(Config._MusicPlayer.Connections) do
            pcall(function() conn:Disconnect() end)
        end
        Config._MusicPlayer.Connections = {}
    end
    if Config._MusicPlayer.Sound then
        pcall(function() Config._MusicPlayer.Sound:Stop() end)
        pcall(function() Config._MusicPlayer.Sound:Destroy() end)
        Config._MusicPlayer.Sound = nil
    end
    Config._MusicPlayer = nil
end

return Module
