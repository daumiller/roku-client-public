function HomeTestScreen() as object
    if m.HomeTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "HomeTest Screen"

        ' HomeTest methods
        obj.Show = homeTestShow
        obj.OnResponse = homeTestOnResponse
        obj.ClearCache = homeTestClearCache
        obj.GetComponents = homeTestGetComponents
        obj.AfterItemFocused = homeTestAfterItemFocused

        ' Hubs and Sections (get/create)
        obj.GetHubs = homeTestGetHubs
        obj.CreateHub = homeTestCreateHub
        obj.GetSections = homeTestGetSections
        obj.CreateSection = homeTestCreateSection

        ' Methods for debugging
        obj.CreateDummyHub = homeTestCreateDummyHub
        obj.OnRewindButton = homeTestSwitchHubLayout

        ' Standard Properties
        obj.sectionsMaxRows = 6
        obj.sectionsMaxCols = 2
        obj.layoutStyle = 1

        m.HomeTestScreen = obj
    end if

    return m.HomeTestScreen
end function

function createHomeTestScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HomeTestScreen())

    obj.Init()

    obj.server = server

    obj.hubsContainer = CreateObject("roAssociativeArray")
    obj.sectionsContainer = CreateObject("roAssociativeArray")

    return obj
end function

sub homeTestShow()
    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.sectionsContainer.request = invalid then
        request = createPlexRequest(m.server, "/library/sections")
        context = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.sectionsContainer = context
    end if

    ' hub requests
    if m.hubsContainer.request = invalid then
        request = createPlexRequest(m.server, "/hubs")
        context = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.hubsContainer = context
    end if

    if m.hubsContainer.response <> invalid and m.sectionsContainer.response <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)
    else
        Debug("homeTestShow:: waiting for all requests to be completed")
    end if
end sub

function homeTestOnResponse(request as object, response as object, context as object) as object
    response.ParseResponse()
    context.response = response
    context.items = response.items

    m.show()
end function

sub homeTestGetComponents()
    m.components.Clear()
    m.focusedItem = invalid

    ' *** HEADER *** '

    ' TODO(rob) make pretty - testing just to see interaction with buttons
    headBkg = createBlock(&h000000e0)
    headBkg.SetFrame(0, 0, 1280, 72)
    m.components.Push(headBkg)

    headLogo = createImage("pkg:/images/plex_logo_HD_62x20.png", 62, 20)
    headLogo.SetFrame(100, 35, 62, 20)
    m.components.Push(headLogo)

    hbHeadButtons = createHBox(false, false, false, 25)
    hbHeadButtons.SetFrame(900, 35, 1280, 25)

    ' Server List Drop Down
    btnServers = createDropDown(m.server.name, FontRegistry().font16)
    btnServers.width = 128
    ' TODO(?): PlexNet server list and sorted?
    servers = PlexServerManager().getServers()
    for each server in servers
        if server.isReachable() = true then
            btnServers.options.push({text: server.name, command: "selected_server", font: FontRegistry().font16, metadata: server })
        end if
    end for
    hbHeadButtons.AddComponent(btnServers)

    ' Options Drop Down: Settings, Sign Out/In
    if MyPlexAccount().IsSignedIn then
        connect = {text: "Sign Out", command: "sign_out"}
    else
        connect = {text: "Sign In", command: "sign_in"}
    end if
    btnOptions = createDropDown(firstOf(MyPlexAccount().username, "Options"), FontRegistry().font16)
    btnOptions.width = 128
    btnOptions.options.push({text: "Settings", command: "settings", font: FontRegistry().font16 })
    btnOptions.options.push({text: connect.text, command: connect.command, font: FontRegistry().font16 })
    hbHeadButtons.AddComponent(btnOptions)

    m.components.Push(hbHeadButtons)

    ' *** SECTIONS & HUBS *** '
    hbox = createHBox(false, false, false, 25)
    hbox.SetFrame(100, 125, 2000*2000, 500)

    ' ** SECTIONS ** '
    sections = m.GetSections()

    ' Section Buttons
    if sections.count() > 0 then
        ' Calculate how many columns we need and allow
        cols = int(sections.count()/m.sectionsMaxRows + .9)
        if cols > m.sectionsMaxCols then cols = m.sectionsMaxCols

        for col = 0 to cols-1
            vbox = createVBox(false, false, false, 10)
            vbox.SetFrame(100, 125, 300, 500)

            for row = 0 to m.sectionsMaxRows-1
                index = m.sectionsMaxRows*col + row
                if index >= sections.count() then exit for
                if sections[index] <> invalid then
                    vbox.AddComponent(sections[index])
                    if m.focusedItem = invalid then m.focusedItem = sections[index]
                end if
            end for
            hbox.AddComponent(vbox)
        end for

        ' TODO(rob/schuyler): allow the width to be specified and not overridden
        if sections.count() > m.sectionsMaxRows*cols then
            moreButton = createButton("More", FontRegistry().font16, "more")
            moreButton.SetColor(&hffffffff, &h1f1f1fff)
            moreButton.width = 72
            moreButton.height = 44
            moreButton.fixed = false
            vbox.AddComponent(moreButton)
        end if
    end if

    ' ** HUBS ** '
    hubs = m.GetHubs()
    ' always focus the first HUB to the left of the screen
    if hubs.count() > 0 then
        hubs[0].demandLeft = 50
        for each hub in hubs
            hbox.AddComponent(hub)
        end for
    end if
    m.components.Push(hbox)

end sub

function homeTestSwitchHubLayout()
    ' clear memory!
    m.Deactivate(invalid)
    ' start fresh on the components screen
    m.Init()
    ' change layout style
    m.layoutStyle = m.layoutStyle+1

    m.ClearCache()

    ' profit
    m.show()
end function

function homeTestCreateDummyHub(orientation as integer, layout as integer, name as string, more = true as boolean) as object
    hub = createHub("HUB " + name, orientation, layout, 10)
    hub.height = 500
    ' set the test poset url based on the orientation (square/landscape = art)
    if orientation = 1 then
        url = "http://roku.rarforge.com/images/sn-poster.jpg"
    else
        url = "http://roku.rarforge.com/images/sn-art.jpg"
    end if
    for i = 1 to hub.MaxChildrenForLayout()
        card = createCard(url, name + tostr(i))
        card.SetFocusable("card")
        if m.focusedItem = invalid then m.focusedItem = card
        hub.AddComponent(card)
    end for
    if more then hub.ShowMoreButton("more")
    return hub
end function

function homeTestCreateHub(container) as object
    ' TODO(rob): we need a way to determine the orientation and layout for the hub. I'd expect we
    ' can determine orientation here, but I'd expect the 'createHub' function to calculate a
    ' layout based on the number of items in a hub, rendering the 'layout' unnecessary

    ' NOTE: I am also a little confused on layout/orientation. I expect some HUBS will have mixed
    ' orientation, so in reality, we should just be passing the container to the HUB class and it
    ' calcuate the layout (first pass), then add each card with whatever orientation it choose.
    orientation = 1
    layout = 1

    hub = createHub(container.GetSingleLineTitle(), orientation, layout, 10)
    hub.height = 500

    ' TODO(rob): we'll need to determing the orientation (and possibly layout) first. As of now,
    ' we'll just keep appending the last item to fill out the hub if we have less than expected.
    for i = 0 to hub.MaxChildrenForLayout()-1
        if container.items[i] <> invalid then
            item = container.items[i]
        end if

        ' TODO(rob): proper image transcoding + how we determine the correct image type to use
        attrs = item.attrs
        thumb = firstOfArr([attrs.grandparentThumb, attrs.parentThumb, attrs.thumb, attrs.art, attrs.composite, ""])
        image = { url: m.server.BuildUrl(thumb, true), server: m.server }

        card = createCard(image, item.GetSingleLineTitle())
        card.setMetadata(item.attrs)
        card.plexObject = item
        card.SetFocusable("card")
        if m.focusedItem = invalid then m.focusedItem = card
        hub.AddComponent(card)
    end for

    ' TODO(rob): logic clean up? It's possibly a container having "more" set, isn't authority.
    ' e.g. the layout selected only supports 3 cards, but we have 4. More will = 0 since the
    ' PMS expects this HUB to have > 5 items. Do we show more? Maybe we will have a layout for
    ' any count up to 5? If we end up having the HUB class calculate the orientation/layout,
    ' I'd expect it will also be able to calculate the more button status as well.
    if container.items.count()-1 > hub.MaxChildrenForLayout() then
        hub.ShowMoreButton("more")
    else if container.get("more") <> "0" then
        hub.ShowMoreButton("more")
    end if

    return hub
end function

function homeTestCreateSection(container as object) as object
    button = createButton(container.GetSingleLineTitle(), FontRegistry().font16, "section_button")
    button.setMetadata(container.attrs)
    button.plexObject = container
    button.width = 200
    button.height = 66
    button.fixed = false
    button.setColor(Colors().TextClr, Colors().BtnBkgClr)
    return button
end function

function homeTestGetSections() as object
    sections = []
    for each container in m.sectionsContainer.items
        sections.push(m.createSection(container))
    end for

    return sections
end function

function homeTestGetHubs() as object
    hubs = []

    if m.layoutStyle = 1 then
        for each container in m.hubsContainer.items
            hubs.push(m.CreateHub(container))
        end for
    else if m.layoutStyle = 2 then
        letters = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
        for each letter in letters
            hubs.push(m.CreateDummyHub(1, 1, ucase(letter)))
        end for
    else if m.layoutStyle = 3 then
        for count = 0 to 2
            hubs.push(m.CreateDummyHub(1, 1, tostr(count) + "A"))
            hubs.push(m.CreateDummyHub(2, 2, tostr(count) + "B", false))
            hubs.push(m.CreateDummyHub(2, 4, tostr(count) + "C", false))
            hubs.push(m.CreateDummyHub(1, 3, tostr(count) + "D"))
        end for
    else
        ' lazy logic - back to defaults
        m.layoutStyle = 0
        for count = 0 to 2
            hubs.push(m.CreateDummyHub(1, 1, tostr(count) + "A"))
            hubs.push(m.CreateDummyHub(2, 2, tostr(count) + "B"))
            hubs.push(m.CreateDummyHub(2, 3, tostr(count) + "C"))
        end for
    end if

    return hubs
end function

sub homeTestClearCache()
    if m.hubsContainer <> invalid then m.hubsContainer.clear()
    if m.sectionsContainer <> invalid then m.sectionsContainer.clear()
end sub

sub homeTestAfterItemFocused(item as object)
    manualKey = "descriptionComponents"
    components = m.componentsManual[manualKey]
    if components = invalid then
        m.componentsManual[manualKey] = []
        components = m.componentsManual[manualKey]
    end if

    descriptionShown = (components.count() > 0)
    if descriptionShown then
        for each comp in components
            comp.Destroy()
        end for
        components.clear()
        ' avoid drawing now to avoid flashes if we are redrawing description
    end if

    ' exit early if we are not drawing the description and draw if applicable
    if item.plexObject = invalid or item.plexObject.islibrarysection() then
        if descriptionShown then CompositorScreen().drawAll()
        return
    end if

    ' *** Component Description *** '
    compDesc = createVBox(false, false, false, 0)
    compDesc.SetFrame(50, 630, 1280, 100)

    label = createLabel(item.plexObject.getlongertitle(), FontRegistry().font18b)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    compDesc.AddComponent(label)

    line2 = []
    line2.push(item.plexObject.GetOriginallyAvailableAt())
    if line2.peek()  = "" then
        line2.pop()
        line2.push(item.plexObject.GetAddedAt())
    end if
    line2.push(item.plexObject.GetDuration())
    if item.plexObject.type = "episode" then
        line2.unshift(item.plexObject.Get("title"))
    end if

    label = createLabel(joinArray(line2, " / "), FontRegistry().font18)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(&hc0c0c0c0)
    compDesc.AddComponent(label)

    components.push(compDesc)

    for each comp in components
        CompositorScreen().DrawComponent(comp)
    end for
    CompositorScreen().drawAll()
end sub
