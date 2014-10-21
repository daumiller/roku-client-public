function HubsScreen() as object
    if m.HubsScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Hubs Screen"

        ' Hubs methods
        obj.Init = hubsInit
        obj.OnResponse = hubsOnResponse
        obj.ClearCache = hubsClearCache
        obj.GetComponents = hubsGetComponents

        ' Hubs and Buttons
        obj.Gethubs = HubsGetHubs
        obj.CreateHub = hubsCreateHub
        obj.GetButtons = hubsGetButtons
        obj.CreateButton = hubsCreateButton

        m.HubsScreen = obj
    end if

    return m.HubsScreen
end function

sub hubsInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Standard Properties
    m.buttonsMaxRows = 6
    m.buttonsMaxCols = 2

    ' Section and Hub containers
    m.hubsContainer = CreateObject("roAssociativeArray")
    m.buttonsContainer = CreateObject("roAssociativeArray")
end sub

function hubsOnResponse(request as object, response as object, context as object) as object
    response.ParseResponse()
    context.response = response
    context.items = response.items

    m.show()
end function

sub hubsGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

    ' *** BUTTONS & HUBS *** '
    hbox = createHBox(false, false, false, 25)
    hbox.SetFrame(50, 125, 2000*2000, 500)

    ' ** BUTTONS ** '
    buttons = m.GetButtons()

    if buttons.count() > 0 then
        ' Calculate how many columns we need and allow
        cols = int(buttons.count()/m.buttonsMaxRows + .9)
        if cols > m.buttonsMaxCols then cols = m.buttonsMaxCols

        for col = 0 to cols-1
            vbox = createVBox(false, false, false, 10)
            vbox.SetFrame(100, 125, 300, 500)

            for row = 0 to m.buttonsMaxRows-1
                index = m.buttonsMaxRows*col + row
                if index >= buttons.count() then exit for
                if buttons[index] <> invalid then
                    vbox.AddComponent(buttons[index])
                    if m.focusedItem = invalid then m.focusedItem = buttons[index]
                end if
            end for
            hbox.AddComponent(vbox)
        end for

        ' TODO(rob/schuyler): allow the width to be specified and not overridden
        if buttons.count() > m.buttonsMaxRows*cols then
            moreButton = createButton("More", FontRegistry().font16, "more")
            moreButton.SetColor(&hffffffff, &h1f1f1fff)
            moreButton.width = 72
            moreButton.height = 44
            moreButton.fixed = false
            moreButton.phalign = moreButton.JUSTIFY_RIGHT
            vbox.AddComponent(moreButton)
        end if
    end if

    ' ** HUBS ** '
    hubs = m.GetHubs()
    ' always focus the first HUB to the left of the screen
    if hubs.count() > 0 then
        for index = 0 to hubs.count()-1
            if index = 0 then
                ' move first HUB to the left of screen
                hubs[index].demandLeft = 50
            else
                ' move all other hubs to another offset
                hubs[index].demandLeft = 300
            end if
            hbox.AddComponent(hubs[index])
        end for
    end if
    m.components.Push(hbox)

    ' set the placement of the description box (manualComponent)
    m.DescriptionBox = createDescriptionBox(m)
    m.DescriptionBox.setFrame(50, 630, 1280-50, 100)
end sub

function hubsCreateHub(container) as dynamic
    if container.items = invalid or container.items.count() = 0 return invalid
    ' TODO(rob): we need a way to determine the orientation and layout for the hub. I'd expect we
    ' can determine orientation here, but I'd expect the 'createHub' function to calculate a
    ' layout based on the number of items in a hub, rendering the 'layout' unnecessary

    ' NOTE: I am also a little confused on layout/orientation. I expect some HUBS will have mixed
    ' orientation, so in reality, we should just be passing the container to the HUB class and it
    ' calcuate the layout (first pass), then add each card with whatever orientation it choose.
    orientation = 1
    layout = 1

    hub = createHub(container.GetSingleLineTitle(), orientation, layout, 10)
    hub.CalculateStyle(container)
    hub.height = 500

    ' TODO(rob): we'll need to determing the orientation (and possibly layout) first. As of now,
    ' we'll just keep appending the last item to fill out the hub if we have less than expected.
    for i = 0 to hub.MaxChildrenForLayout()-1
        if container.items[i] <> invalid then
            item = container.items[i]
        end if

        ' Continue Watching Hub is special. Use the shows title instead of the episode string
        if tostr(hub.hubIdentifier) = "home.continue" then
            if item.Get("type") = "episode" then
                title = firstOf(item.Get("grandparentTitle"), item.Get("parentTitle"))
            else
                title = item.GetSingleLineTitle()
            end if
        else if tostr(item.Get("type")) = "movie" or tostr(item.Get("type")) = "show" then
            title = invalid
        else
            title = item.GetSingleLineTitle()
        end if

        card = createCard(ImageClass().BuildImgObj(item, m.server), title, item.GetViewOffsetPercentage())
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
        hub.ShowMoreButton("grid_button")
    else if container.get("more") <> "0" then
        hub.ShowMoreButton("grid_button")
    end if

    return hub
end function

function hubsCreateButton(container as object) as object
    button = createButton(container.GetSingleLineTitle(), FontRegistry().font16, "section_button")
    button.setMetadata(container.attrs)
    button.plexObject = container
    button.width = 200
    button.height = 66
    button.fixed = false
    button.setColor(Colors().TextClr, Colors().BtnBkgClr)
    return button
end function

function hubsGetButtons() as object
    buttons = []
    for each container in m.buttonsContainer.items
        buttons.push(m.createButton(container))
    end for

    return buttons
end function

function hubsGetHubs() as object
    hubs = []

    for each container in m.hubsContainer.items
        hub = m.CreateHub(container)
        if hub <> invalid then hubs.push(hub)
    end for

    return hubs
end function

sub hubsClearCache()
    if m.hubsContainer <> invalid then m.hubsContainer.clear()
    if m.buttonsContainer <> invalid then m.buttonsContainer.clear()
end sub
