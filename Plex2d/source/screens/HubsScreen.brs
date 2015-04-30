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
        obj.HandleCommand = hubsHandleCommand
        obj.GetEmptyMessage = hubsGetEmptyMessage
        obj.OnFwdButton = hubsOnFwdButton
        obj.OnRevButton = hubsOnRevButton
        obj.AdvanceContainerFocus = hubsAdvanceContainerFocus

        ' Hubs and Buttons
        obj.GetHubs = hubsGetHubs
        obj.CreateHub = hubsCreateHub
        obj.GetButtons = hubsGetButtons
        obj.CreateButton = hubsCreateButton

        m.HubsScreen = obj
    end if

    return m.HubsScreen
end function

sub hubsInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Section and Hub containers
    m.hubsContext = CreateObject("roAssociativeArray")
    m.buttonsContext = CreateObject("roAssociativeArray")
    m.playlistContext = CreateObject("roAssociativeArray")
    m.focusContainers = CreateObject("roArray", 5, true)
end sub

sub hubsOnResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response
    context.items = response.items

    m.Show()
end sub

function hubsHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "show_section" then
        Application().PushScreen(createSectionsScreen(item.plexObject))
    else if not ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
        handled = false
    end if

    return handled
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
        vbox = createVBox(false, false, false, 10)
        vbox.scrollOverflowColor = Colors().Background
        vbox.SetFrame(100, 125, 300, 500)
        vbox.SetScrollable(invalid, true, true, "left")
        ' TODO(rob): hide components when shifted outside viewport
        vbox.ignoreFirstLast = true

        for each button in buttons
            vbox.AddComponent(button)
            if m.focusedItem = invalid then m.focusedItem = button
        end for
        hbox.AddComponent(vbox)
        m.focusContainers.Push(vbox)
    end if

    ' ** HUBS ** '
    hubs = m.GetHubs()
    ' always focus the first HUB to the left of the screen
    if hubs.count() > 0 then
        for index = 0 to hubs.count()-1
            if index = 0 then hubs[index].first = true
            hubs[index].demandLeft = 300
            hbox.AddComponent(hubs[index])
            m.focusContainers.Push(hubs[index])
        end for
    else
        ' Display a helpful messae if the hubs are empty.
        m.customFonts.title = FontRegistry().GetTextFont(30, true)
        rect = { x: iif(buttons.count() > 0, 300, 219), y: 200, w: 1000, h: 320 }
        HDtoSD(rect)

        chevron = createImage("pkg:/images/plex-chevron.png", HDtoSDWidth(195), HDtoSDHeight(320), invalid, "scale-to-fit")
        chevron.SetFrame(rect.x, rect.y, chevron.width, chevron.height)
        m.components.Push(chevron)

        ' title and subtitle
        message = m.GetEmptyMessage()
        width = HDtoSDWidth(600)
        vb = createVBox(false, false, false, HDtoSDWidth(10))
        m.components.Push(vb)

        titleLabel = createLabel(message.title, m.customFonts.title)
        titleLabel.width = width
        vb.AddComponent(titleLabel)

        subtitleLabel = createLabel(message.subtitle, FontRegistry().LARGE)
        subtitleLabel.wrap = true
        subtitleLabel.SetFrame(0, 0, width, FontRegistry().LARGE.getOneLineHeight() * 2)
        vb.AddComponent(subtitleLabel)

        ' Set the text in the middle of the chevron
        yOffset = chevron.y + chevron.height/2 - vb.GetPreferredHeight()/2
        xOffset = chevron.x + chevron.width + HDtoSDWidth(30)
        vb.SetFrame(xoffset, yOffset, width, chevron.height)
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
        title = item.GetOverlayTitle(hub.hubIdentifier = "home.continue", hub.orientation = ComponentClass().ORIENTATION_LANDSCAPE)

        ' TODO(rob): handle the viewstate overlays differently (cleaner...)
        contentType = item.Get("type", "")
        if contentType = "album" or contentType = "artist" or contentType = "playlist" then
            card = createCard(item, item.GetOverlayTitle())
        else
            card = createCard(item, title, item.GetViewOffsetPercentage(), item.GetUnwatchedCount(), item.IsUnwatched())
        end if
        ' TODO(schuyler): Do we need this? I don't think so.
        ' card.setMetadata(item.attrs)
        card.plexObject = item
        card.SetFocusable("show_item")
        card.DisableNonParentFocus("down")
        if m.focusedItem = invalid then m.focusedItem = card
        hub.AddComponent(card)
    end for

    ' TODO(rob): logic clean up? It's possibly a container having "more" set, isn't authority.
    ' e.g. the layout selected only supports 3 cards, but we have 4. More will = 0 since the
    ' PMS expects this HUB to have > 5 items. Do we show more? Maybe we will have a layout for
    ' any count up to 5? If we end up having the HUB class calculate the orientation/layout,
    ' I'd expect it will also be able to calculate the more button status as well.
    if container.items.Count() > hub.MaxChildrenForLayout() then
        hub.ShowMoreButton("show_grid")
    else if container.get("more") <> "0" then
        hub.ShowMoreButton("show_grid")
    end if

    return hub
end function

function hubsCreateButton(container as object, command="show_section" as string) as object
    button = createButton(container.GetSingleLineTitle(), FontRegistry().LARGE, command)
    button.setMetadata(container.attrs)
    button.plexObject = container
    button.width = 200
    button.height = 66
    button.fixed = false
    button.setColor(Colors().Text, Colors().Button)
    return button
end function

function hubsGetButtons() as object
    buttons = []
    for each item in m.buttonsContext.items
        buttons.push(m.createButton(item))
    end for

    return buttons
end function

function hubsGetHubs() as object
    hubs = []

    for each item in m.hubsContext.items
        hub = m.CreateHub(item)
        if hub <> invalid then hubs.push(hub)
    end for

    return hubs
end function

sub hubsClearCache()
    if m.hubsContext <> invalid then m.hubsContext.Clear()
    if m.buttonsContext <> invalid then m.buttonsContext.Clear()
    if m.playlistContext <> invalid then m.playlistContext.Clear()
end sub

function hubsGetEmptyMessage() as object
    obj = createObject("roAssociativeArray")
    obj.title = "No content available in this library"
    obj.subtitle = "Please add content and/or check that " + chr(34) + "Include in dashboard" + chr(34) + " is enabled.".
    return obj
end function

sub hubsOnFwdButton(item=invalid as dynamic)
    m.AdvanceContainerFocus(1)
end sub

sub hubsOnRevButton(item=invalid as dynamic)
    m.AdvanceContainerFocus(-1)
end sub

sub hubsAdvanceContainerFocus(delta as integer)
    if m.focusContainers.Count() = 0 then return

    ' default to first/last container if no match
    containerIndex = iif(delta < 0, 0, m.focusContainers.Count() - 1)
    if m.focusedItem.parent <> invalid then
        for index = 0 to m.focusContainers.Count() - 1
            container = m.focusContainers[index]
            if container.id = m.focusedItem.parent.id then
                containerIndex = index + delta
                exit for
            end if
        end for
    end if
    if m.focusContainers[containerIndex] = invalid then return

    ' Set focus to the first focusable item in the container
    for each comp in m.focusContainers[containerIndex].components
        if comp.focusable = true then
            m.FocusItemManually(comp)
            exit for
        end if
    end for
end sub
