function AppSettings()
    if m.AppSettings = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Properties
        obj.prefsCache = {}
        obj.globals = {}

        ' Methods
        obj.GetPreference = settingsGetPreference
        obj.GetIntPreference = settingsGetIntPreference
        obj.SetPreference = settingsSetPreference
        obj.ClearPreference = settingsClearPreference
        obj.ProcessLaunchArgs = settingsProcessLaunchArgs
        obj.GetGlobal = settingsGetGlobal
        obj.GetIntGlobal = settingsGetIntGlobal
        obj.InitGlobals = settingsInitGlobals
        obj.GetCapabilities = settingsGetCapabilities

        obj.reset()
        m.AppSettings = obj

        obj.InitGlobals()
    end if

    return m.AppSettings
end function

function settingsGetPreference(name, defaultValue=invalid, section="preferences")
    cacheKey = name + section
    if m.prefsCache.DoesExist(cacheKey) then return m.prefsCache[cacheKey]

    value = defaultValue
    sec = CreateObject("roRegistrySection", section)
    if sec.Exists(name) then value = sec.Read(name)

    if value <> invalid then
        m.prefsCache[cacheKey] = value
    end if

    return value
end function

function settingsGetIntPreference(name, defaultValue=0, section="preferences")
    value = m.GetPreference(name)
    if value <> invalid then
        return value.toInt()
    else
        return defaultValue
    end if
end function

sub settingsSetPreference(name, value, section="preferences")
    if value = invalid then
        m.ClearPreference(name, section)
        return
    end if

    sec = CreateObject("roRegistrySection", section)
    sec.Write(name, value)
    m.prefsCache[name + section] = value
    sec.Flush()
end sub

sub settingsClearPreference(name, section="preferences")
    sec = CreateObject("roRegistrySection", section)
    sec.Delete(name)
    m.prefsCache.Delete(name + section)
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
        end if
    next
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
    device = CreateObject("roDeviceInfo")

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
    m.globals["animationFull"] = (device.GetModelDisplayName() = "Roku 3")

    ' TODO(schuyler): Preference? Rely on GetFriendlyName from firmware 6.1? Make HTTP dial call?
    m.globals["friendlyName"] = m.globals["rokuModel"]
end sub

function settingsGetCapabilities(recompute=false as boolean) as string
    if not recompute and m.globals["capabilities"] <> invalid then
        return m.globals["capabilities"]
    end if

    ' As long as we're only using the universal transcoder, we don't need to
    ' fully specify our capabilities. We just need to make sure our audio
    ' preferences are specified, and we might as well say we like h264.

    caps = "videoDecoders=h264{profile:high&resolution:1080&level=41};audioDecoders=aac{channels:2}"

    ' TODO(schuyler): Surround sound prefs
    surroundSoundAC3 = false
    surroundSoundDCA = false

    if surroundSoundAC3 then
        caps = caps + ",ac3{channels:8}"
    end if

    if surroundSoundDCA then
        caps = caps + ",dca{channels:8}"
    end if

    m.globals["capabilities"] = caps
    return caps
end function
