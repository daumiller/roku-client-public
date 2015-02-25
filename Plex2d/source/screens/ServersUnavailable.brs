function ServersUnavailableScreen() as object
    if m.ServersUnavailableScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Servers Unvailable"

        obj.Init = serverunavailInit
        obj.GetComponents = serverunavailGetComponents
        obj.OnItemSelected = serverunavailOnItemSelected

        m.ServersUnavailableScreen = obj
    end if

    return m.ServersUnavailableScreen
end function

function createServersUnavailableScreen() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ServersUnavailableScreen())

    obj.Init()

    Application().clearScreens()

    return obj
end function

sub serverunavailInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts = {
        title: FontRegistry().GetTextFont(32),
        subtitle: FontRegistry().NORMAL,
        text: FontRegistry().NORMAL,
        buttons: FontRegistry().NORMAL,
    }
end sub

sub serverunavailGetComponents()
    m.DestroyComponents()

    ' obtain the server list to determine the information to display
    servers = PlexServerManager().GetServers()

    if servers.Count() = 0 then
        title = "No Servers Found"
        subtitle = ""
    else
        title = "No Supported Servers Found"
        subtitle = "Plex Media Server version " + AppSettings().GetGlobal("MinServerVersionStr") + " or higher is required."
    end if

    xOffset = 219
    yOffset = 200

    chevron = createImage("pkg:/images/plex-chevron.png", 195, 320, invalid, "scale-to-fit")
    chevron.SetFrame(xOffset, yOffset, chevron.width, chevron.height)
    m.components.Push(chevron)

    xOffset = xOffset + chevron.width + 50
    width = 450

    ' Header (title)
    title = createLabel(title, m.customFonts.title)
    title.SetFrame(xOffset, yOffset, width, title.GetPreferredHeight())
    title.SetColor(Colors().Orange)
    m.components.Push(title)
    yOffset = yOffset + title.GetPreferredHeight()

    ' Title info
    subtitle = createLabel(subtitle, m.customFonts.subtitle)
    subtitle.SetFrame(xOffset, yOffset, width, subtitle.GetPreferredHeight())
    subtitle.SetColor(Colors().Red)
    m.components.Push(subtitle)
    yOffset = yOffset + subtitle.GetPreferredHeight() + 10

    ' Message if no server found
    if servers.Count() = 0 then
        vbInfo = createVBox(false, false, false, 0)
        vbInfo.SetFrame(xOffset, yOffset, width, 150)

        label = createLabel("You don't have any media servers yet. Download and install one and it'll appear here.", m.customFonts.text)
        label.wrap = true
        label.SetFrame(0, 0, width, m.customFonts.text.GetOneLineHeight() * 3)

        urlLabel = createLabel("https://plex.tv/downloads", m.customFonts.text)
        urlLabel.SetColor(Colors().Orange)

        vbInfo.AddComponent(label)
        vbInfo.AddComponent(urlLabel)
        m.components.Push(vbInfo)
        yOffset = yOffset + vbInfo.height
    end if

    ' Buttons
    buttons = createHBox(false, false, false, 10)
    buttons.SetFrame(xOffset, yOffset, width, m.customFonts.buttons.GetOneLineHeight()*2)
    m.components.Push(buttons)
    btnOptions = [{ command: "find_servers", text: "Retry" }]
    if MyPlexAccount().isSignedIn then
        btnOptions.Push({ command: "user_list", text: "Users" })
        btnOptions.Push({ command: "sign_out", text: "Sign Out" })
    else
        btnOptions.Push({ command: "sign_in", text: "Sign In" })
    end if
    btnOptions.Push({ command: "exit", text: "Exit" })

    for each option in btnOptions
        button = createButton(option.text, m.customFonts.buttons, option.command)
        button.SetColor(Colors().Text, Colors().Button)
        button.SetPadding(10)
        button.width = 100
        if m.focusedItem = invalid then m.focusedItem = button
        buttons.AddComponent(button)
    end for
    yOffset = yOffset + buttons.GetPreferredHeight() + 10

    ' List of servers found with their status (offline, unauthed, needs upgrade)
    if servers.Count() > 0 then
        vbServers = createVBox(false, false, false, 0)
        for each server in servers
            text = { prefix: ucase(server.name), suffix: "" }
            errors = createObject("roList")
            if server.IsSupported = false then
                errors.Push("server upgrade required")
            end if
            if server.IsReachable(false) = false then
                if server.connections.count() > 0 then
                    errors.Push("offline - " + tostr(server.connections[0].state))
                else
                    errors.Push("offline")
                end if
            end if
            if server.owned = false and server.owner <> invalid then
                text.suffix= " (" + tostr(server.owner) + ")"
            end if

            textLabel = createLabel(text.prefix + ": " + joinArray(errors, " & ") + text.suffix, m.customFonts.text)
            textLabel.SetPadding(5)
            textLabel.focusable = true
            textLabel.fixed = false
            vbServers.AddComponent(textLabel)
        end for

        height = cint((computeRect(chevron).down - yOffset) / textLabel.GetPreferredHeight()) * textLabel.GetPreferredHeight()
        vbServers.SetFrame(xOffset, yOffset, width, height)
        vbServers.SetScrollable(height / 2, false, false, "left")
        vbServers.stopShiftIfInView = true

        m.components.Push(vbServers)
    end if
end sub

sub serverunavailOnItemSelected(item as object)
    Debug("item selected with command: " + tostr(item.command))

    if item.command = "exit" then
        Application().PopScreen(m)
    else if item.command = "find_servers" then
        Application().PushScreen(createLoadingScreen())
    else if item.command = "sign_out" then
        MyPlexAccount().SignOut()
    else if item.command = "sign_in" then
        Application().PushScreen(createPinScreen(false))
    else if item.command = "user_list" then
        Application().PushScreen(createUsersScreen(true))
    else
        Debug("command not defined: (closing dialog now) " + tostr(item.command))
    end if
end sub
