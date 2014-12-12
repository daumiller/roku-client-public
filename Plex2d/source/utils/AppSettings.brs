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

    ' animation support - handle slower Rokus
    m.globals["animationSupport"] = true
    m.globals["animationFull"] = (model = "Roku 3")
end sub
