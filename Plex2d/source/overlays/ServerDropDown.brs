sub sddoverlayGetComponents()
    GDMDiscovery().Discover()
    MyPlexManager().RefreshResources()

    vbox = createVBox(false, false, false, 0)

    ' server containers for ordering. This may be better handles inside of
    ' `PlexServerManager().GetServers()`
    servers = createObject("roList")
    serversOwned = createObject("roList")
    serversShared = createObject("roList")

    for each server in PlexServerManager().GetServers()
        if server.owned then
            serversOwned.push(server)
        else
            serversShared.push(server)
        end if
    end for
    servers.Append(serversOwned)
    servers.Append(serversShared)

    if servers.Count() = 0 then return

    for each server in servers
        comp = createServerButton(server, m.button.customFonts.title, m.button.customFonts.subtitle,  m.button.customFonts.glyph, "selected_server")
        comp.bgColor = Colors().ButtonMed
        comp.fixed = false
        comp.zOrder = m.zOrderOverlay
        comp.SetPadding(10, 10, 10, 10)
        comp.SetFocusMethod(comp.FOCUS_BACKGROUND, Colors().Orange)
        comp.SetMetadata(server)

        if server.Equals(PlexServerManager().GetSelectedServer()) or m.screen.focusedItem = invalid then
            m.screen.focusedItem = comp
        end if

        vbox.AddComponent(comp)
    end for

    m.CalculatePosition(vbox)
end sub
