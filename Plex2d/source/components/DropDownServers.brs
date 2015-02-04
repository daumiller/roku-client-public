function DropDownServersClass() as object
    if m.DropDownServersClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(DropDownClass())
        obj.ClassName = "DropDownServers"

        obj.Init = ddsInit
        obj.GetComponents = ddsGetComponents
        obj.CreateButton = ddsCreateButton

        m.DropDownServerClass = obj
    end if

    return m.DropDownServerClass
end function

function createDropDownServers(text as string, font as object, maxHeight as integer, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownServersClass())

    obj.screen = screen
    obj.Init(text, font, maxHeight)

    return obj
end function

sub ddsInit(text as string, font as object,  maxHeight as integer)
    ApplyFunc(DropDownClass().Init, m, [text, font, maxHeight])

    ' Custom fonts for the drop down options. These need to be references at this
    ' this level to conserve memory. Each drop down will have a reference.
    m.customFonts = {
        title: FontRegistry().font16,
        subtitle: FontRegistry().font12,
        glyph: FontRegistry().GetIconFont(12),
        status: FontRegistry().GetTextFont(20),
    }

    ' Max and Min width of the drop down options (server/owner name dependent)
    m.maxWidth = 400
    m.minWidth = 128
end sub

sub ddsGetComponents()
    GDMDiscovery().Discover()
    MyPlexManager().RefreshResources()

    vbox = createVBox(false, false, false, 0)
    vbox.SetScrollable(m.maxHeight)

    ' server containers for ordering. This may be better handles inside of
    ' `PlexServerManager().GetServers()`
    servers = createObject("roList")
    serversOwned = createObject("roList")
    serversOnline = createObject("roList")
    serversOffline = createObject("roList")

    buttonWidth = m.minWidth
    for each server in PlexServerManager().GetServers()
        ' calculate the dynamic width
        serverWidth = m.customFonts.title.GetOneLineWidth(server.name, m.maxWidth)
        ownerWidth = m.customFonts.title.GetOneLineWidth(tostr(server.owner), m.maxWidth)
        if serverWidth > buttonWidth then buttonWidth = serverWidth
        if ownerWidth > buttonWidth then buttonWidth = ownerWidth

        ' server ordering
        if server.owned then
            serversOwned.push(server)
        else if server.IsReachable() then
            serversOnline.push(server)
        else
            serversOffline.push(server)
        end if
    end for
    servers.Append(serversOwned)
    servers.Append(serversOnline)
    servers.Append(serversOffline)

    ' cacluate the dynamic width incuding the status and padding offsets
    focusPx = CompositorScreen().focusPixels
    padding = {
        top: 0 + focusPx,
        right: 10 + focusPx,
        bottom: 5 + focusPx,
        left: 10 + focusPx
    }
    m.statusWidth = m.customFonts.glyph.GetOneLineWidth(Glyphs().CHECK, m.maxWidth)*2 + padding.left + padding.right
    buttonWidth = buttonWidth + m.statusWidth
    if buttonWidth > m.maxWidth then buttonWidth = m.maxWidth

    for each server in servers
        comp = m.createButton(server, "selected_server", buttonWidth, 66, padding)
        vbox.AddComponent(comp)
    end for

    m.CalculatePosition(vbox)
end sub

function ddsCreateButton(server as object, command as dynamic, width as integer, height as integer, padding=invalid as dynamic) as object
    obj = createButtonServer(server, command, m.customFonts.title, m.customFonts.subtitle, m.customFonts.glyph, m.customFonts.status)

    obj.width = width
    obj.height = height
    obj.padding = padding
    obj.statusWidth = m.statusWidth
    obj.focusInside = true
    obj.focusNonSiblings = false
    obj.zOrder = ZOrders().DROPDOWN
    obj.dropDown = m
    obj.focusParent = m
    obj.SetMetadata(server)

    if server.Equals(PlexServerManager().GetSelectedServer()) or m.screen.focusedItem = invalid then
        m.screen.focusedItem = obj
    end if

    return obj
end function
