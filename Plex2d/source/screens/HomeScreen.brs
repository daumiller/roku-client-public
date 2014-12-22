function HomeScreen() as object
    if m.HomeScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = homeShow
        obj.AfterItemFocused = homeAfterItemFocused
        obj.HandleCommand = homeHandleCommand
        obj.OnKeyRelease = homeOnKeyRelease

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
        request = createPlexRequest(m.server, "/hubs?excludePlaylists=1&excludeMusic=1&excludePhotos=1")
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

sub homeAfterItemFocused(item as object)
    pendingDraw = m.DescriptionBox.Show(item)
    if pendingDraw then m.screen.DrawAll()
end sub

function homeHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "sign_out" then
        MyPlexAccount().SignOut()
    else if command = "sign_in" then
        ' TODO(rob): we should not recieve this command until the channel
        ' is available to IAP users.
        Application().PushScreen(createPinScreen(false))
    else if command = "switch_user" then
        user = item.metadata
        if user.id = MyPlexAccount().id then return handled

        if MyPlexAccount().isAdmin = false and user.protected = "1" then
            ' pinPrompt handles switching and error feedback
            pinPrompt = createPinPrompt(m)
            pinPrompt.userSwitch = user
            pinPrompt.Show(true)
        else if not MyPlexAccount().SwitchHomeUser(user.id) then
            ' provide feedback on failure to switch to non protected users
            ' TODO(rob): need verbiage for failure
            dialog = createDialog("Unable to switch users", "Please check your connection and try again.", m)
            dialog.Show()
        end if
    else if command = "selected_server" then
        PlexServerManager().SetSelectedServer(item.metadata, true)
        Application().PushScreen(createHomeScreen(item.metadata))
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
        if container.Get("type") = "show" or container.Get("type") = "movie" then
            buttons.push(m.createButton(container))
        end if
    end for

    return buttons
end function

sub homeOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK and m.exitDialog = invalid then
        dialog = createDialog("Are you ready to exit Plex?", invalid, m)
        dialog.enableBackButton = true
        dialog.buttonsSingleLine = true
        dialog.AddButton("Yes", "exit")
        dialog.AddButton("No", "no_exit")
        dialog.HandleButton = homeDialogHandleButton
        dialog.Show()
        m.exitDialog = dialog
    else
        ' exit the channel on back button in the dialog
        if keyCode = m.kp_BK and m.exitDialog <> invalid then
            m.exitDialog.Close()
            m.exitDialog = invalid
        end if
        ApplyFunc(ComponentsScreen().OnKeyRelease, m, [keyCode])
    end if
end sub

sub homeDialogHandleButton(button as object)
    Debug("dialog button selected with command: " + tostr(button.command))

    m.Close()
    if button.command = "exit" then
        Application().popScreen(m.screen)
    else if button.command = "no_exit" then
        m.screen.exitDialog = invalid
    else
        Debug("command not defined: " + tostr(button.command))
    end if
end sub
