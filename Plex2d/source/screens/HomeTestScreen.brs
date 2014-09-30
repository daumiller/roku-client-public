function HomeTestScreen() as object
    if m.HomeTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "HomeTest Screen"

        obj.GetComponents = homeTestGetComponents

        ' debug - switch hub layout styles
        obj.HandleRewind = homeTestSwitchHubLayout

        ' HUB Request and Creation methods
        obj.Show = homeTestShow
        obj.OnHubResponse = homeTestOnHubResponse
        obj.CreateHubs = homeTestCreateHubs

        ' methods to create a hub (+ dummy debug)
        obj.CreateHub = homeTestCreateHub
        obj.CreateDummyHub = homeTestCreateDummyHub

        m.HomeTestScreen = obj
    end if

    return m.HomeTestScreen
end function

sub homeTestShow()
    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)
    if m.hubsContainer = invalid or m.hubsContainer.count() = 0 then
        m.request = createPlexRequest(m.server, "/hubs")
        m.context = m.request.CreateRequestContext("dummy_hubs", createCallable("OnHubResponse", m))
        Application().StartRequest(m.request, m.context)
    else
        ApplyFunc(ComponentsScreen().Show, m)
    end if
end sub

function homeTestOnHubResponse(request as object, response as object, context as object)
    Debug("Got hubs response with status " + tostr(response.GetStatus()))

    ' TODO(rob): handle an invalid response - no hubs

    m.hubsContainer = []
    if response.ParseResponse() then
        for each container in response.items
            if container.items <> invalid and container.items.count() > 0 then
                m.hubsContainer.push(container)
            end if
        end for
    end if

    ApplyFunc(ComponentsScreen().Show, m)
end function

function createHomeTestScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HomeTestScreen())

    obj.server = server

    obj.layoutStyle = 1

    obj.Init()

    return obj
end function

sub homeTestGetComponents()
    m.components.Clear()
    m.focusedItem = invalid

    ' TODO(rob) make pretty - testing just to see interaction with buttons
    headBkg = createBlock(&h000000e0)
    headBkg.SetFrame(0, 0, 1280, 72)
    m.components.Push(headBkg)

    headLogo = createImage("pkg:/images/plex_logo_HD_62x20.png", 62, 20)
    headLogo.SetFrame(100, 35, 62, 20)
    m.components.Push(headLogo)

    hbHeadButtons = createHBox(false, false, false, 25)
    hbHeadButtons.SetFrame(900, 35, 1280, 25)

    but1 = createButton(m.server.name, FontRegistry().font16, "server_selection")
    but1.width = 128
    hbHeadButtons.AddComponent(but1)

    if MyPlexAccount().IsSignedIn then
        command = "sign_out"
    else
        command = "sign_in"
    end if
    but2 = createButton(firstOf(MyPlexAccount().username,"Options"), FontRegistry().font16, command)
    but2.width = 128
    hbHeadButtons.AddComponent(but2)

    m.components.Push(hbHeadButtons)

    hbox = createHBox(false, false, false, 25)
    hbox.SetFrame(100, 125, 2000*2000, 500)

    hubs = m.CreateHubs()
    ' always focus the first HUB to the left of the screen
    hubs[0].demandLeft = 50
    for each hub in hubs
        hbox.AddComponent(hub)
    end for

    m.components.Push(hbox)

    ' m.components.Clear()

    ' ' dummy section data
    ' sectionData = []
    ' for count = 0 to 5
    '     sectionData.push({name: "section " + tostr(count), focus: (count = 0), command: "TBD"})
    ' end for
    ' ' dummy hub data
    ' dummyHub = {items: []}
    ' for count = 0 to 5
    '     dummyHub.items.push({
    '         poster: "http://roku.rarforge.com/images/sn-poster.jpg",
    '         art: "https://roku.rarforge.com/images/sn-art.jpg",
    '     })
    ' end for

    ' ' mainBox: This will get intersting. I am not sure how we want to handle it.
    ' ' Total hubs and hubs width dynamic, so we'll need to be able to add all the
    ' ' components, without resizing, and ignore rendering off screen components.
    ' mainBox = createHBox(false, false, false, 30)
    ' mainBox.SetFrame(50, 125, 1280*2, 720-125)

    ' ' HBox: sections container (buttons)
    ' sections = createVBox(false, false, false, 10)
    ' sections.halign = sections.JUSTIFY_RIGHT
    ' for each section in sectionData
    '     button = createButton(section.name, FontRegistry().font16, section.command)
    '     button.SetColor(&hffffffff, &h1f1f1fff)
    '     button.width = 128
    '     button.height = 72
    '     if section.focus then m.focusedItem = button
    '     sections.AddComponent(button)
    ' end for
    ' mainBox.AddComponent(sections)

    ' ' HBox: hubs container
    ' hubs = createHBox(false, false, false, 30)

    ' ' hub1
    ' dummyHub.htype = 2
    ' hub = createHub(dummyHub, 10)
    ' hubs.AddComponent(hub)

    ' ' hub2
    ' dummyHub.htype = 1
    ' hub = createHub(dummyHub, 10)
    ' hubs.AddComponent(hub)

    ' ' hub3
    ' dummyHub.htype = 3
    ' hub = createHub(dummyHub, 10)
    ' hubs.AddComponent(hub)

    ' ' add the hubs to the mainBox
    ' mainBox.AddComponent(hubs)

    ' m.components.Push(mainBox)
end sub

function homeTestSwitchHubLayout()
    ' clear memory!
    m.Deactivate(invalid)
    ' start fresh on the components screen
    m.Init()
    ' change layout style
    m.layoutStyle = m.layoutStyle+1
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
        card.SetFocusable("test")
        if m.focusedItem = invalid then m.focusedItem = card
        hub.AddComponent(card)
    end for
    if more then hub.ShowMoreButton("more")
    return hub
end function

function homeTestCreateHub(container)
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
        card.SetFocusable("test")
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

function homeTestCreateHubs() as object
    hubs = []

    if m.layoutStyle = 1 then
        for each container in m.hubsContainer
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
