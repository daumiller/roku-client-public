function HomeScreen() as object
    if m.HomeScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = homeShow
        obj.HandleCommand = homeHandleCommand
        obj.OnKeyRelease = homeOnKeyRelease
        obj.OnOverlayClose = homeOnOverlayClose
        obj.GetEmptyMessage = homeGetEmptyMessage

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

    obj.Init()

    obj.server = server

    Application().clearScreens()

    return obj
end function

sub homeShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.buttonsContainer.request = invalid then
        request = createPlexRequest(m.server, "/library/sections")
        context = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.buttonsContainer = context
    end if

    ' hub requests
    if m.hubsContainer.request = invalid then
        ' TODO(rob): modify to allow non-video sections
        request = createPlexRequest(m.server, "/hubs?excludePlaylists=1&excludePhotos=1")
        context = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.hubsContainer = context
    end if

    if m.hubsContainer.response <> invalid and m.buttonsContainer.response <> invalid then
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
            subtitle = "Plex Media Server version " + AppSettings().GetGlobal("MinServerVersionStr") + " or higher is required."
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
        ' TODO(rob): temporary placement and code
        settings = createSettings(m)
        settings.Show()
    else if not ApplyFunc(HubsScreen().HandleCommand, m, [command, item])
        handled = false
    end if

    return handled
end function

' TODO(rob): remove/modify to allow non-video sections
' temporary override to exclude non-video sections
function homeGetButtons() as object
    buttons = []
    for each container in m.buttonsContainer.items
        if container.Get("type") = "show" or container.Get("type") = "movie" or container.Get("type") = "artist" then
            buttons.push(m.createButton(container))
        else
            Debug("excluding section type: " + container.Get("type",""))
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
