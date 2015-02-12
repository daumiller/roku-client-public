function AppSettings()
    if m.AppSettings = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Properties
        obj.regCache = {}
        obj.globals = {}
        obj.prefs = {}
        obj.overrides = []

        ' Methods
        obj.GetPreference = settingsGetPreference
        obj.GetIntPreference = settingsGetIntPreference
        obj.GetBoolPreference = settingsGetBoolPreference
        obj.SetPreference = settingsSetPreference
        obj.ClearPreference = settingsClearPreference
        obj.InitPrefs = settingsInitPrefs
        obj.GetSectionKey = settingsGetSectionKey

        obj.GetRegistry = settingsGetRegistry
        obj.GetIntRegistry = settingsGetIntRegistry
        obj.SetRegistry = settingsSetRegistry
        obj.ClearRegistry = settingsClearRegistry

        obj.ProcessLaunchArgs = settingsProcessLaunchArgs
        obj.GetGlobal = settingsGetGlobal
        obj.GetIntGlobal = settingsGetIntGlobal
        obj.InitGlobals = settingsInitGlobals
        obj.GetCapabilities = settingsGetCapabilities
        obj.DumpRegistry = settingsDumpRegistry

        obj.GetGlobalSettings = settingsGetGlobalSettings
        obj.SupportsSurroundSound = settingsSupportsSurroundSound
        obj.GetMaxResolution = settingsGetMaxResolution

        obj.SetPrefOverride = settingsSetPrefOverride
        obj.PopPrefOverrides = settingsPopPrefOverrides

        obj.reset()

        m.AppSettings = obj

        obj.InitPrefs()
        obj.InitGlobals()
    end if

    return m.AppSettings
end function

function settingsGetPreference(name as string) as dynamic
    obj = m.prefs[name]

    if obj = invalid then return invalid

    if obj.DoesExist("managedValue") and MyPlexAccount().isManaged then
        return obj.managedValue
    end if

    overrides = m.overrides.Peek()
    if overrides <> invalid and overrides.DoesExist(name) then
        return overrides[name]
    end if

    section = m.GetSectionKey(name)
    return m.GetRegistry(name, obj.default, section)
end function

function settingsGetIntPreference(name as string) as integer
    value = m.GetPreference(name)
    return firstOf(value, "0").toInt()
end function

function settingsGetBoolPreference(name as string) as boolean
    return (m.GetPreference(name) = "1")
end function

sub settingsSetPreference(name as string, value as dynamic)
    section = m.GetSectionKey(name)
    m.SetRegistry(name, value, section)
    Application().Trigger("change:" + name, [value])
end sub

sub settingsClearPreference(name as string)
    section = m.GetSectionKey(name)
    m.ClearRegistry(name, section)
end sub

sub settingsInitPrefs()
    ' All of our prefs are defined here, including information like default
    ' values, whether or not the pref is per-user, and whether managed users
    ' are allowed to change the value. This central definition allows callers
    ' to do things like just call GetPreference(name) without having to specify
    ' a default value or worry about scoping.

    ' Surround sound. A boolean pref for each codec.
    m.prefs["surround_sound_ac3"] = {
        key: "surround_sound_ac3",
        title: "Dolby Digital (AC3)",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    m.prefs["surround_sound_dca"] = {
        key: "surround_sound_dca",
        title: "DTS (DCA)",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    ' Subtitles.
    m.prefs["hardsubtitles"] = {
        key: "hardsubtitles",
        title: "Burn in (transcode)",
        default: "0",
        section: "user",
        prefType: "bool"
    }

    ' TODO(schuyler): How many different quality settings do we want? Local vs. remote? Per-server?
    ' TODO(schuyler): This is so wrong, but we want to stuff the qualities into
    ' a global, but we can't InitGlobals before we InitPrefs.
    ' Quality

    qualities = CreateObject("roList")
    qualities.Push({title: "20 Mbps", index: 12, maxBitrate: 20000, maxHeight: 1080})
    qualities.Push({title: "12 Mbps", index: 11, maxBitrate: 12000, maxHeight: 1080})
    qualities.Push({title: "10 Mbps", index: 10, maxBitrate: 10000, maxHeight: 1080})
    qualities.Push({title: "8 Mbps", index: 9, maxBitrate: 8000, maxHeight: 1080})
    qualities.Push({title: "4 Mbps", index: 8, maxBitrate: 4000, maxHeight: 720})
    qualities.Push({title: "3 Mbps", index: 7, maxBitrate: 3000, maxHeight: 720})
    qualities.Push({title: "2 Mbps", index: 6, maxBitrate: 2000, maxHeight: 720})
    qualities.Push({title: "1.5 Mbps", index: 5, maxBitrate: 1500, maxHeight: 480})
    qualities.Push({title: "720 Kbps", index: 4, maxBitrate: 720, maxHeight: 0})
    qualities.Push({title: "320 Kbps", index: 3, maxBitrate: 320, maxHeight: 0})
    m.globals["qualities"] = qualities

    options = CreateObject("roList")
    for each quality in qualities
        options.Push({title: quality.title, value: tostr(quality.index)})
    next
    m.prefs["local_quality"] = {
        key: "local_quality",
        title: "Local Streaming Quality",
        default: "8",
        section: "preferences",
        prefType: "enum",
        options: options
    }
    m.prefs["remote_quality"] = {
        key: "remote_quality",
        title: "Remote Streaming Quality",
        default: "7",
        section: "preferences",
        prefType: "enum",
        options: options
    }

    ' Cinema Trailers
    options = [
        {title: "Don't Play", value: "0" },
        {title: "Play 1 Before Movie", value: "1" },
        {title: "Play 2 Before Movie", value: "2" },
        {title: "Play 3 Before Movie", value: "3" },
        {title: "Play 4 Before Movie", value: "4" },
        {title: "Play 5 Before Movie", value: "5" },
    ]
    m.prefs["cinema_trailers"] = {
        key: "cinema_trailers",
        title: "Cinema Trailers",
        default: "0",
        section: "preferences",
        prefType: "enum",
        options: options
    }

    ' TODO(schuyler): How do we want to control these options now? An enum? Multiple bools?
    ' Direct Play
    m.prefs["playback_direct"] = {
        key: "playback_direct",
        title: "Direct Play",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }
    m.prefs["playback_remux"] = {
        key: "playback_remux",
        title: "Direct Stream",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }
    m.prefs["playback_transcode"] = {
        key: "playback_transcode",
        title: "Transcode",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    ' Log level
    options = [
        {title: "Disabled", value: "10"},
        {title: "Error", value: "4"},
        {title: "Warn", value: "3"},
        {title: "Info", value: "2"},
        {title: "Debug", value: "1"},
    ]
    m.prefs["log_level"] = {
        key: "log_level",
        title: "Logging",
        default: "2",
        section: "preferences",
        prefType: "enum",
        options: options
    }

    ' Remote Control
    m.prefs["remotecontrol"] = {
        key: "remotecontrol",
        title: "Remote Control",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    ' GDM
    m.prefs["gdm_discovery"] = {
        key: "gdm_discovery",
        title: "Server Discovery (GDM)",
        default: "1",
        section: "preferences",
        prefType: "bool",
        managedValue: "0"
        isRestricted: true,
    }

    ' Analytics
    m.prefs["analytics"] = {
        key: "analytics",
        title: "Analytics (anonymous)",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    ' Automatically sign in
    m.prefs["auto_signin"] = {
        key: "auto_signin",
        title: "Automatically sign in",
        default: "0",
        section: "preferences",
        prefType: "bool",
        isRestricted: true,
    }

    ' Audio direct play
    m.prefs["directplay_mp3"] = {
        key: "directplay_mp3",
        title: "MP3",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    m.prefs["directplay_aac"] = {
        key: "directplay_aac",
        title: "AAC",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }

    m.prefs["directplay_flac"] = {
        key: "directplay_flac",
        title: "FLAC",
        default: "1",
        section: "preferences",
        prefType: "bool"
    }
end sub

function settingsGetSectionKey(pref as string) as string
    obj = m.prefs[pref]

    if obj = invalid or obj.section <> "user" then
        return "preferences"
    else
        return "preferences_u" + tostr(MyPlexAccount().id)
    end if
end function

function settingsGetRegistry(name, defaultValue=invalid, section="misc")
    cacheKey = name + section
    if m.regCache.DoesExist(cacheKey) then return m.regCache[cacheKey]

    value = defaultValue
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(name) then value = sec.Read(name)

    if value <> invalid then
        m.regCache[cacheKey] = value
    end if

    return value
end function

function settingsGetIntRegistry(name, defaultValue=0, section="misc")
    value = m.GetRegistry(name, invalid, section)
    if value <> invalid then
        return value.toInt()
    else
        return defaultValue
    end if
end function

sub settingsSetRegistry(name, value, section="misc")
    if value = invalid then
        m.ClearRegistry(name, section)
        return
    end if

    sec = CreateObject("roRegistrySection", section)
    sec.Write(name, value)
    m.regCache[name + section] = value
    sec.Flush()
end sub

sub settingsClearRegistry(name, section="misc")
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(name)
    m.regCache.Delete(name + section)
    sec.Flush()
end sub

sub settingsProcessLaunchArgs(args)
    ' Process any launch args starting with "pref!"
    for each arg in args
        value = args[arg]
        if Left(arg, 5) = "pref!" then
            pref = Mid(arg, 6)
            Debug("Setting preference from launch param: " + pref + " = " + value)
            if value <> "" then
                m.SetPreference(pref, value)
            else
                m.ClearPreference(pref)
            end if
        else if arg = "debug" and value = "1" then
            l = Logger()
            l.SetLevel(l.LEVEL_DEBUG)
            l.EnablePapertrail()
            Debug("Enabling debugger because of launch args")
            m.DumpRegistry()
        end if
    next
end sub

sub settingsDumpRegistry()
    Debug("---- Registry Contents ----")
    registry = CreateObject("roRegistry")
    sections = registry.GetSectionList()

    for each sectionName in sections
        Debug("---- Start " + sectionName + " ----")
        section = CreateObject("roRegistrySection", sectionName)
        keys = section.GetKeyList()

        for each key in keys
            value = section.Read(key)
            Debug(key + ": " + tostr(value))
        end for

        Debug("---- End " + sectionName + " ----")
    end for

    Debug("---- End Registry ---------")
end sub

function settingsGetGlobal(name, defaultValue=invalid)
    return firstOf(m.globals[name], defaultValue)
end function

function settingsGetIntGlobal(name, defaultValue=0)
    value = m.GetGlobal(name)
    if value <> invalid then
        return value.toInt()
    else
        return defaultValue
    end if
end function

sub settingsInitGlobals()
    app = CreateObject("roAppManager")
    device = CreateObject("roDeviceInfo")
    m.globals["roDeviceInfo"] = device

    version = device.GetVersion()
    major = Mid(version, 3, 1).toInt()
    minor = Mid(version, 5, 2).toInt()
    build = Mid(version, 8, 5).toInt()
    versionStr = major.toStr() + "." + minor.toStr() + " build " + build.toStr()

    m.globals["rokuVersionStr"] = versionStr
    m.globals["rokuVersionArr"] = [major, minor, build]

    appInfo = CreateObject("roAppInfo")
    m.globals["appVersionStr"] = appInfo.GetVersion()
    m.globals["appName"] = appInfo.GetTitle()
    m.globals["appID"] = appInfo.GetID()

    m.globals["rokuModelCode"] = device.GetModel()
    m.globals["rokuModel"] = device.GetModelDisplayName()
    m.globals["rokuUniqueID"] = device.GetDeviceUniqueId()
    m.globals["clientIdentifier"] = m.globals["appName"] + m.globals["rokuUniqueID"]

    ' Stash some more info from roDeviceInfo into globals. Fetching the device
    ' info can be slow, especially for anything related to metadata creation
    ' that may happen inside a loop.

    m.globals["displaySize"] = device.GetDisplaySize()
    m.globals["displayMode"] = device.GetDisplayMode()
    m.globals["displayType"] = device.GetDisplayType()
    m.globals["IsHD"] = (device.GetDisplayType() = "HDTV")

    ' New-style quality settings indexed by old-style quality. The last value is
    ' a synthetic one meant to mean "highest", which should try to remux most things.
    m.globals["transcodeVideoQualities"]   = ["10",      "20",     "30",     "30",     "40",     "60",     "60",      "75",      "100",     "60",       "75",       "90",        "100",       "100"]
    m.globals["transcodeVideoResolutions"] = ["220x180", "220x128","284x160","420x240","576x320","720x480","1024x768","1280x720","1280x720","1920x1080","1920x1080","1920x1080", "1920x1080", "1920x1080"]
    m.globals["transcodeVideoBitrates"]    = ["64",      "96",     "208",    "320",    "720",    "1500",   "2000",    "3000",    "4000",    "8000",     "10000",    "12000",     "20000",     "200000"]

    ' animation support - handle slower Rokus
    m.globals["animationSupport"] = true
    m.globals["animationTest"] = AnimateTest()
    m.globals["animationFull"] = (m.globals["animationTest"] < 20)
    m.globals["friendlyName"] = GetFriendlyName()

    ' Idle timeout (PIN lock). Utilize screensaver timeout, or 5 minutes if we know
    ' the screensaver is disabled (fw 5.6+), or fallback to 30 minutes.
    ' TODO(rob): we can remove version/fallback check when 6.1 firmware is released.
    if CheckMinimumVersion([5, 6]) then
        if app.GetScreensaverTimeout() = 0 then
            m.globals["idleLockTimeout"] = 5 * 60
        else
            m.globals["idleLockTimeout"] = app.GetScreensaverTimeout() * 60
        end if
    else
        m.globals["idleLockTimeout"] = 30 * 60
    end if

    ' Minimum server version required
    m.globals["minServerVersionStr"] = "0.9.11.1"
    m.globals["minServerVersionArr"] = ParseVersion(m.globals["minServerVersionStr"])
end sub

function settingsGetCapabilities(recompute=false as boolean) as string
    if not recompute and m.globals["capabilities"] <> invalid then
        return m.globals["capabilities"]
    end if

    ' As long as we're only using the universal transcoder, we don't need to
    ' fully specify our capabilities. We just need to make sure our audio
    ' preferences are specified, and we might as well say we like h264.

    caps = "videoDecoders=h264{profile:high&resolution:1080&level=41};audioDecoders=aac{channels:2}"

    if m.SupportsSurroundSound(true) then
        surroundSoundAC3 = m.GetBoolPreference("surround_sound_ac3")
        surroundSoundDCA = m.GetBoolPreference("surround_sound_dca")
    else
        surroundSoundAC3 = false
        surroundSoundDCA = false
    end if

    if surroundSoundAC3 then
        caps = caps + ",ac3{channels:8}"
    end if

    if surroundSoundDCA then
        caps = caps + ",dca{channels:8}"
    end if

    m.globals["capabilities"] = caps
    return caps
end function

function settingsGetGlobalSettings() as object
    ' This is used by the settings overlay/component to decide what to
    ' show in the global settings. We return an array of objects, one for
    ' each group.

    groups = CreateObject("roList")

    ' Video preferences, liberally defined for now
    video = CreateObject("roList")

    ' Surround sound, but only if the device is configured for it
    if m.SupportsSurroundSound(true) then
        options = [
            m.prefs["surround_sound_ac3"],
            m.prefs["surround_sound_dca"],
        ]
        video.Push({key: "surround_sound", title: "Receiver Capabilities", options: options, prefType: "bool"})
    end if

    ' Soft subtitles
    options = [
        m.prefs["hardsubtitles"],
    ]
    video.Push({key: "subtitles", title: "Subtitles", options: options, prefType: "bool"})

    video.Push(m.prefs["local_quality"])
    video.Push(m.prefs["remote_quality"])
    video.Push(m.prefs["cinema_trailers"])

    groups.Push({
        title: "Video",
        settings: video
    })

    ' Advanced preferences, which is just about everything
    advanced = CreateObject("roList")

    ' Direct Play
    options = [
        m.prefs["playback_direct"],
        m.prefs["playback_remux"],
        m.prefs["playback_transcode"],
    ]
    advanced.Push({key: "playback", title: "Direct Play", options: options, prefType: "bool"})

    ' Log level
    advanced.Push(m.prefs["log_level"])

    ' TODO(schuyler): Grouping these together is at least half joke.
    options = [
        m.prefs["remotecontrol"],
        m.prefs["analytics"],
        m.prefs["gdm_discovery"],
        m.prefs["auto_signin"],
    ]
    advanced.Push({key: "tweaks", title: "Tweaks", options: options, prefType: "bool"})

    groups.Push({
        title: "Advanced",
        settings: advanced
    })

    return groups
end function

function settingsSupportsSurroundSound(refresh=false as boolean) as boolean
    ' Because of the headphones in the remote, we may need to recheck. And
    ' we can't really reliably tell if this is a Roku with headphones support.
    ' It's not that expensive to ask for the device info, so we just recheck if
    ' it's been more than a few seconds.

    if m.surroundSoundTimer = invalid then
        refresh = true
        m.surroundSoundTimer = createTimer("surround")
    else if m.surroundSoundTimer.GetElapsedSeconds() > 10 then
        refresh = true
    end if

    if refresh then
        result = (m.GetGlobal("roDeviceInfo").GetAudioOutputChannel() <> "Stereo")
        m.globals["surroundSound"] = result
        m.surroundSoundTimer.Mark()
    else
        result = m.globals["surroundSound"]
    end if

    return result
end function

' TODO(schuyler): Is this based on the server's quality? Local quality? Something else?
function settingsGetMaxResolution(local as boolean) as integer
    if local then
        qualityIndex = m.GetIntPreference("local_quality")
    else
        qualityIndex = m.GetIntPreference("remote_quality")
    end if

    if qualityIndex >= 9 then
        return 1080
    else if qualityIndex >= 6 then
        return 720
    else if qualityIndex >= 5 then
        return 480
    else
        return 0
    end if
end function

sub settingsSetPrefOverride(key as string, value as dynamic, screenID as integer)
    overrides = m.overrides.Peek()

    if overrides = invalid or overrides.id <> screenID then
        overrides = {id: screenID}
        m.overrides.Push(overrides)
    end if

    overrides[key] = value
end sub

sub settingsPopPrefOverrides(screenID as integer)
    overrides = m.overrides.Peek()

    if overrides <> invalid and overrides.id = screenID then
        m.overrides.Pop()
    end if
end sub
