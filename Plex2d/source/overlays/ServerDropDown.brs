sub sddoverlayGetComponents()
    GDMDiscovery().Discover()
    MyPlexManager().RefreshResources()

    vbox = createVBox(false, false, false, 0)

    ' server containers for ordering. This may be better handles inside of
    ' `PlexServerManager().GetServers()`
    servers = createObject("roList")
    serversOwned = createObject("roList")
    serversShared = createObject("roList")

    buttonWidth = m.button.minWidth
    for each server in PlexServerManager().GetServers()
        ' calculate the dynamic width
        titleWidth = m.button.customFonts.title.GetOneLineWidth(server.name, m.button.maxWidth)
        subtitleWidth = m.button.customFonts.subtitle.GetOneLineWidth(firstOf(server.GetSubtitle(), ""), m.button.maxWidth)
        if titleWidth > buttonWidth then buttonWidth = titleWidth
        if subtitleWidth > buttonWidth then buttonWidth = subtitleWidth

        ' server ordering
        if server.owned then
            serversOwned.push(server)
        else
            serversShared.push(server)
        end if
    end for
    servers.Append(serversOwned)
    servers.Append(serversShared)

    if servers.Count() = 0 then return

    ' finalize the dynamic width including the status and padding offsets
    focusPx = CompositorScreen().focusPixels
    padding = {
        top: 0 + focusPx,
        right: 10 + focusPx,
        bottom: 5 + focusPx,
        left: 10 + focusPx
    }
    buttonHeight = m.button.customFonts.title.GetOneLineHeight() + m.button.customFonts.subtitle.GetOneLineHeight() + padding.top*2 + padding.bottom*2
    statusWidth = m.button.createButton(servers[0], "", 0, 0, padding).statusWidth
    buttonWidth = buttonWidth + statusWidth + padding.left + padding.right
    if buttonWidth > m.button.maxWidth then buttonWidth = m.button.maxWidth

    for each server in servers
        comp = m.button.createButton(server, "selected_server", buttonWidth, buttonHeight, padding)
        comp.zOrder = m.zOrderOverlay
        vbox.AddComponent(comp)
    end for
    comp.focusSeparator = invalid

    m.CalculatePosition(vbox)
end sub

function sddoverlayCreateButton(server as object, command as dynamic, width as integer, height as integer, padding=invalid as dynamic) as object
    obj = createServerButton(server, command, m.customFonts.title, m.customFonts.subtitle, m.customFonts.glyph, m.customFonts.status)

    obj.width = width
    obj.height = height
    obj.padding = padding
    obj.innerBorderFocus = true
    obj.focusSeparator = 1
    obj.SetMetadata(server)

    if server.Equals(PlexServerManager().GetSelectedServer()) or m.screen.focusedItem = invalid then
        m.screen.focusedItem = obj
    end if

    return obj
end function
