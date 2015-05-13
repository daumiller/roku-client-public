function HomeScreen() as object
    if m.HomeScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = homeShow
        obj.HandleCommand = homeHandleCommand
        obj.OnKeyRelease = homeOnKeyRelease
        obj.OnOverlayClose = homeOnOverlayClose
        obj.GetEmptyMessage = homeGetEmptyMessage
        obj.OnPlaylistResponse = homeOnPlaylistResponse

        ' TODO(rob): remove/modify to allow non-video sections
        ' temporary override to exclude non-video sections
        obj.GetButtons = homeGetButtons

        obj.screenName = "Home Screen"

        m.HomeScreen = obj
    end if

    return m.HomeScreen
end function

function createHomeScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HomeScreen())

    obj.server = server

    obj.Init()

    Application().clearScreens()

    return obj
end function

sub homeShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.buttonsContext.request = invalid then
        request = createPlexRequest(m.server, "/library/sections")
        m.buttonsContext = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, m.buttonsContext)
    end if

    if m.playlistContext.request = invalid then
        request = createPlexRequest(m.server, "/playlists/all")
        request.AddHeader("X-Plex-Container-Start", "0")
        request.AddHeader("X-Plex-Container-Size", "0")
        m.playlistContext = request.CreateRequestContext("playlists", createCallable("OnPlaylistResponse", m))
        Application().StartRequest(request, m.playlistContext)
    end if

    if m.hubsContext.request = invalid then
        ' TODO(rob): modify to allow Photos
        request = createPlexRequest(m.server, "/hubs")
        m.hubsContext = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, m.hubsContext)
    end if

    if m.hubsContext.response <> invalid and m.buttonsContext.response <> invalid and m.playlistContext.response <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)
    else
        Debug("HubsShow:: waiting for all requests to be completed")
    end if
end sub

function homeHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "sign_out" then
        MyPlexAccount().SignOut()
    else if command = "sign_in" then
        ' TODO(rob): we should not recieve this command until the channel
        ' is available to IAP users.
        Application().PushScreen(createPinScreen(false))
    else if command = "selected_server" then
        server = item.metadata
        ' Provide some feedback for unsupported and unreachable servers
        if server.IsSupported = false then
            title = "Please upgrade your server"
            subtitle = "Plex Media Server version " + AppSettings().GetGlobal("MinServerVersionStr") + " or higher is required. "
            subtitle = subtitle + server.name + " is running version " + server.GetVersion()
            dialog = createDialog(title, subtitle, m)
            dialog.Show()
        else if server.IsReachable() = false then
            title = server.name + " is not reachable"
            subtitle = "Please sign into your server and check your connection."
            dialog = createDialog(title, subtitle, m)
            dialog.Show()
        else
            PlexServerManager().SetSelectedServer(item.metadata, true)
            Application().PushScreen(createHomeScreen(item.metadata))
        end if
    else if command = "settings" then
        settings = createSettings(m)
        settings.Show()
    else if not ApplyFunc(HubsScreen().HandleCommand, m, [command, item])
        handled = false
    end if

    return handled
end function

function homeGetButtons() as object
    buttons = []

    if m.playlistContext.item <> invalid then
        buttons.push(m.createButton(m.playlistContext.item, "show_grid"))
    end if

    for each item in m.buttonsContext.items
        ' Is it safe to just include all types? Or is it better to allow the types we know we support.
        if item.Get("type") = "show" or item.Get("type") = "movie" or item.Get("type") = "artist" or item.Get("type") = "photo" then
            buttons.push(m.createButton(item))
        else
            Debug("excluding section type: " + item.Get("type",""))
        end if
    end for

    return buttons
end function

sub homeOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK then
        dialog = createDialog("Are you ready to exit Plex?", invalid, m)
        dialog.enableBackButton = true
        dialog.buttonsSingleLine = true
        dialog.AddButton("Yes", "exit")
        dialog.AddButton("No", "no_exit")
        dialog.HandleButton = homeDialogHandleButton
        dialog.Show()

        dialog.On("close", createCallable("OnOverlayClose", m))
    else
        ApplyFunc(ComponentsScreen().OnKeyRelease, m, [keyCode])
    end if
end sub

sub homeDialogHandleButton(button as object)
    Debug("dialog button selected with command: " + tostr(button.command))

    m.Close()
    if button.command = "exit" then
        Application().popScreen(m.screen)
    end if
end sub

sub homeOnOverlayClose(overlay as object, backButton as boolean)
    if backButton then
        Application().popScreen(m)
    end if
end sub

function homeGetEmptyMessage() as object
    obj = createObject("roAssociativeArray")
    obj.title = "No content available on this server"
    obj.subtitle = "Please add content and/or check that " + chr(34) + "Include in dashboard" + chr(34) + " is enabled in your library sections."
    return obj
end function

sub homeOnPlaylistResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response

    if response.container <> invalid and response.container.GetInt("totalSize") > 0 then
        ' There may be a better way to do this, but we need to generate
        ' a synthetic PlexObject to add a playlist button.
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexObjectClass())
        obj.InitSynthetic(response.container, "Playlists")
        obj.container.Set("type", "playlist")
        obj.Set("type", "Playlist")
        obj.Set("title", "Playlists")
        obj.Set("key", response.container.address)
        context.item = obj
    end if

    m.Show()
end sub
