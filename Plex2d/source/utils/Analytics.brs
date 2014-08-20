function Analytics()
    if m.Analytics = invalid then
        obj = CreateObject("roAssociativeArray")

        ' We need a screenID property in order to use certain Application features
        obj.screenID = Application().SCREEN_ANALYTICS

        obj.numPlaybackEvents = 0
        obj.sessionTimer = createTimer("analytics")

        obj.TrackEvent = analyticsTrackEvent
        obj.TrackScreen = analyticsTrackScreen
        obj.TrackTiming = analyticsTrackTiming
        obj.SendTrackingRequest = analyticsSendTrackingRequest
        obj.OnStartup = analyticsOnStartup
        obj.Cleanup = analyticsCleanup

        ' Much of the data that we need to submit is session based and can be built
        ' now. When we're tracking an indvidual hit we'll append the hit-specific
        ' variables.

        encoder = CreateObject("roUrlTransfer")
        settings = AppSettings()

        uuid = settings.GetPreference("UUID", invalid, "analytics")
        if uuid = invalid then
            uuid = CreateUUID()
            settings.SetPreference("UUID", uuid, "analytics")
        end if

        dimensionsObj = settings.GetGlobal("DisplaySize")
        dimensions = tostr(dimensionsObj.w) + "x" + tostr(dimensionsObj.h)

        obj.baseData = "v=1"
        obj.baseData = obj.baseData + "&tid=UA-6111912-18"
        obj.baseData = obj.baseData + "&cid=" + uuid
        obj.baseData = obj.baseData + "&sr=" + dimensions
        obj.baseData = obj.baseData + "&ul=en-us"
        obj.baseData = obj.baseData + "&cd1=" + encoder.Escape(settings.GetGlobal("appName") + " for Roku")
        obj.baseData = obj.baseData + "&cd2=" + encoder.Escape(settings.GetGlobal("clientIdentifier"))
        obj.baseData = obj.baseData + "&cd3=Roku"
        obj.baseData = obj.baseData + "&cd4=" + encoder.Escape(settings.GetGlobal("rokuVersionStr", "unknown"))
        obj.baseData = obj.baseData + "&cd5=" + encoder.Escape(settings.GetGlobal("rokuModel"))
        obj.baseData = obj.baseData + "&cd6=" + encoder.Escape(settings.GetGlobal("appVersionStr"))
        obj.baseData = obj.baseData + "&an=" + encoder.Escape(settings.GetGlobal("appName") + " for Roku")
        obj.baseData = obj.baseData + "&av=" + encoder.Escape(settings.GetGlobal("appVersionStr"))

        ' Singleton
        obj.reset()
        m.Analytics = obj

        Application().On("init", createCallable("OnStartup", obj))
    end if

    return m.Analytics
end function

sub analyticsTrackEvent(category, action, label, value, customVars={})
    ' Now's a good time to update our session variables, in case we don't shut
    ' down cleanly.
    if category = "Playback" then m.numPlaybackEvents = m.numPlaybackEvents + 1

    settings = AppSettings()
    settings.SetPreference("session_duration", tostr(m.sessionTimer.GetElapsedSeconds()), "analytics")
    settings.SetPreference("session_playback_events", tostr(m.numPlaybackEvents), "analytics")

    customVars["t"] = "event"
    customVars["ec"] = category
    customVars["ea"] = action
    customVars["el"] = label
    customVars["ev"] = tostr(value)

    m.SendTrackingRequest(customVars)
end sub

sub analyticsTrackScreen(screenName, customVars={})
    customVars["t"] = "appview"
    customVars["cd"] = screenName

    m.SendTrackingRequest(customVars)
end sub

sub analyticsTrackTiming(time, category, variable, label, customVars={})
    customVars["t"] = "timing"
    customVars["utc"] = category
    customVars["utv"] = variable
    customVars["utl"] = label
    customVars["utt"] = tostr(time)

    m.SendTrackingRequest(customVars)
end sub

sub analyticsSendTrackingRequest(vars)
    ' Only if we're enabled
    if AppSettings().GetPreference("analytics", "1") <> "1" then return

    request = createHttpRequest("http://www.google-analytics.com/collect")
    context = request.CreateRequestContext("analytics")

    data = m.baseData
    for each name in vars
        if vars[name] <> invalid then data = data + "&" + name + "=" + UrlEscape(vars[name])
    next

    Debug("Final analytics data: " + data)

    Application().StartRequest(request, context, data)
end sub

sub analyticsOnStartup(signedIn)
    settings = AppSettings()

    lastSessionDuration = settings.GetIntPreference("session_duration", 0, "analytics")
    if lastSessionDuration > 0 then
        lastSessionPlaybackEvents = settings.GetPreference("session_playback_events", "0", "analytics")
        m.TrackEvent("App", "Shutdown", "", lastSessionDuration, {cm1: lastSessionPlaybackEvents})
    end if
    m.TrackEvent("App", "Start", "", 1, {sc: "start"})
end sub

sub analyticsCleanup()
    ' Just note the session duration. We wrote the number of playback events the
    ' last time we got one, and we won't send the actual event until the next
    ' startup.
    AppSettings().SetPreference("session_duration", tostr(m.sessionTimer.GetElapsedSeconds()), "analytics")
    m.sessionTimer = invalid
end sub
