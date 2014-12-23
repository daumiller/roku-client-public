function PlexRequestClass() as object
    if m.PlexRequestClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PlexRequest"

        obj.OnResponse = pnrOnResponse

        m.PlexRequestClass = obj
    end if

    return m.PlexRequestClass
end function

function createPlexRequest(server as object, path as string) as object
    obj = createHttpRequest(server.BuildUrl(path))
    obj.Append(PlexRequestClass())

    obj.server = server
    obj.path = path

    AddPlexHeaders(obj.request, server.GetToken())

    return obj
end function

sub pnrOnResponse(event as object, context as object)
    if context.completionCallback <> invalid then
        result = createPlexResult(m.server, m.path)
        result.SetResponse(event)
        context.completionCallback.Call([m, result, context])
    end if
end sub

' Helper functions that operate on ifHttpAgent objects

sub AddPlexHeaders(transferObj, token=invalid)
    settings = AppSettings()

    transferObj.AddHeader("X-Plex-Platform", "Roku")
    transferObj.AddHeader("X-Plex-Version", settings.GetGlobal("appVersionStr"))
    transferObj.AddHeader("X-Plex-Client-Identifier", settings.GetGlobal("clientIdentifier"))
    transferObj.AddHeader("X-Plex-Platform-Version", settings.GetGlobal("rokuVersionStr", "unknown"))
    transferObj.AddHeader("X-Plex-Product", "Plex for Roku")
    transferObj.AddHeader("X-Plex-Device", settings.GetGlobal("rokuModel"))
    transferObj.AddHeader("X-Plex-Device-Name", settings.GetGlobal("friendlyName"))
    transferObj.AddHeader("X-Plex-Client-Capabilities", settings.GetCapabilities())

    AddAccountHeaders(transferObj, token)
end sub

sub AddPlexParameters(builder as object)
    settings = AppSettings()
    versionArr = settings.GetGlobal("rokuVersionArr")

    builder.AddParam("X-Plex-Platform", "Roku")
    builder.AddParam("X-Plex-Platform-Version", tostr(versionArr[0]) + "." + tostr(versionArr[1]))
    builder.AddParam("X-Plex-Version", settings.GetGlobal("appVersionStr"))
    builder.AddParam("X-Plex-Product", "Plex for Roku")
    builder.AddParam("X-Plex-Device", settings.GetGlobal("rokuModel"))
end sub

sub AddAccountHeaders(transferObj, token=invalid)
    if token <> invalid then
        transferObj.AddHeader("X-Plex-Token", token)
    end if

    ' TODO(schuyler): Add username?
end sub
