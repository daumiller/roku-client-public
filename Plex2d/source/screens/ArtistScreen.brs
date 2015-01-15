function ArtistScreen() as object
    if m.ArtistScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PreplayScreen())

        obj.screenName = "Artist Screen"

        ' Methods
        obj.Init = artistInit
        obj.Show = artistShow
        obj.OnChildResponse = artistOnChildResponse
        obj.GetComponents = artistGetComponents
        obj.HandleCommand = artistHandleCommand
        obj.GetButtons = artistGetButtons

        m.ArtistScreen = obj
    end if

    return m.ArtistScreen
end function

function createArtistScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ArtistScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub artistInit()
    ApplyFunc(PreplayScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts.glyphs = FontRegistry().GetIconFont(32)

    ' path override (optional)
    if m.path <> invalid then
        m.childrenPath = m.path + "/children"
    else
        m.path = m.requestItem.GetItemPath()
        m.childrenPath = m.requestItem.GetAbsolutePath("key")
    end if

    m.childrenPath = m.childrenPath + "?excludeAllLeaves=1"
    m.parentPath = m.path + "?includeRelated=1&includeRelatedCount=0&includeExtras=1"

    m.server = m.requestItem.GetServer()

    m.requestContext = invalid
    m.childRequestContext = invalid
    m.children = CreateObject("roList")
end sub

sub artistShow()
    if not application().isactivescreen(m) then return

    if m.requestContext = invalid then
        request = createPlexRequest(m.server, m.parentPath)
        context = request.CreateRequestContext("preplay_item", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.requestContext = context
    end if

    if m.childRequestContext = invalid then
        request = createPlexRequest(m.server, m.childrenPath)
        context = request.CreateRequestContext("preplay_item", createCallable("OnChildResponse", m))
        Application().StartRequest(request, context)
        m.childRequestContext = context
    end if

    if m.requestContext.response <> invalid and m.childRequestContext.response <> invalid then
        if m.item <> invalid then
            ApplyFunc(ComponentsScreen().Show, m)
        else
            dialog = createDialog("Unable to load", "Sorry, we couldn't load the requested item.", m)
            dialog.AddButton("OK", "close_screen")
            dialog.HandleButton = preplayDialogHandleButton
            dialog.Show()
        end if
    end if
end sub

sub artistGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' *** Background Artwork *** '
    if m.item.Get("art") <> invalid then
        background = createImage(m.item, 1280, 720, { blur: 15, opacity: 60, background: Colors().ToHexString("Background") })
        background.SetOrientation(background.ORIENTATION_LANDSCAPE)
        m.components.Push(background)

        background = createBlock(Colors().OverlayDark)
        background.setFrame(0, 72, 1280, 720)
        m.components.Push(background)
    end if

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

    yOffset = 125
    xOffset = 50
    parentSpacing = 30
    parentHeight = 434
    childSpacing = 10
    demandLeft = xOffset + parentSpacing + parentHeight

    ' *** Buttons *** '
    vbButtons = createVBox(false, false, false, childSpacing)
    vbButtons.SetFrame(xOffset, yOffset, 100, 720 - yOffset)
    vbButtons.ignoreFirstLast = true
    for each comp in m.GetButtons()
        vbButtons.AddComponent(comp)
    end for
    m.components.Push(vbButtons)
    xOffset = xOffset + parentSpacing + vbButtons.width

    ' *** Artist title and image ***
    artistTitle = createLabel(m.item.GetLongerTitle(), FontRegistry().Font16)
    artistHeight = artistTitle.font.GetOneLineHeight()
    artistTitle.SetFrame(xOffset, yOffset - childSpacing - artistHeight, artistTitle.GetPreferredWidth(), artistHeight)
    artist = createImage(m.item, parentHeight, parentHeight)
    artist.fixed = false
    artist.SetFrame(xOffset, yOffset, parentHeight, parentHeight)
    m.components.push(artistTitle)
    m.components.push(artist)
    xOffset = xOffset + parentSpacing + parentHeight

    ' *** Biography: title and summary *** '
    m.summaryTitle = createLabel("BIOGRAPHY", FontRegistry().Font16)
    m.summaryHeight = m.summaryTitle.font.GetOneLineHeight()
    m.summaryTitle.SetFrame(xOffset, yOffset - childSpacing - m.summaryHeight, m.summaryTitle.GetPreferredWidth(), m.summaryHeight)
    m.summaryTitle.zOrderInit = -1
    m.components.push(m.summaryTitle)

    m.summary = createLabel(m.item.Get("summary", ""), FontRegistry().Font16)
    m.summary.SetColor(Colors().Text, Colors().OverlayDark)
    m.summary.SetPadding(20)
    m.summary.wrap = true
    m.summary.SetFrame(xOffset, yOffset, 1230 - xOffset, parentHeight)
    m.summary.zOrderInit = -1
    m.components.push(m.summary)

    ' *** Grids (Hubs) *** '
    m.hbGrid = createHBox(false, false, false, 30)
    m.hbGrid.SetFrame(xOffset, yOffset, 2000*2000, parentHeight)
    gridPrefs = { height: parentHeight, ignoreParentShift: true, demandLeft: demandLeft }

    ' TODO(rob): lazy load placeholders
    ' *** Albums *** '
    grid = createGrid(ComponentClass().ORIENTATION_SQUARE, 2, childSpacing, "Albums")
    grid.Append(gridPrefs)
    for each item in m.children
        card = createCard(item, item.GetOverlayTitle(false, true))
        card.plexObject = item
        card.fixed = false
        card.SetFocusable("show_item")
        if m.focusedItem = invalid then m.focusedItem = card
        grid.AddComponent(card)
    end for
    m.hbGrid.AddComponent(grid)

    ' TODO(rob): lazy load placeholders
    ' *** Extras ***
    if m.item.extraItems <> invalid and m.item.extraItems.count() > 0 then
        grid = createGrid(ComponentClass().ORIENTATION_LANDSCAPE, 2, childSpacing, "Videos")
        grid.Append(gridPrefs)
        for each item in m.item.extraItems
            card = createCard(item, item.GetOverlayTitle())
            card.plexObject = item
            card.fixed = false
            card.SetFocusable("show_item")
            if m.focusedItem = invalid then m.focusedItem = card
            grid.AddComponent(card)
        end for
        m.hbGrid.AddComponent(grid)
    end if

    m.components.Push(m.hbGrid)

    ' set the placement of the description box (manualComponent)
    m.DescriptionBox = createDescriptionBox(m)
    m.DescriptionBox.setFrame(50, 630, 1280-50, 100)
end sub

sub artistOnChildResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response
    context.items = response.items

    if context.items.count() > 0 then
        for each item in context.items
            m.children.push(item)
        end for
    end if

    m.show()
end sub

function artistGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")
    buttons.push({text: Glyphs().PLAY, command: "play"})
    buttons.push({text: Glyphs().SHUFFLE, command: "shuffle"})
    if m.item.Get("summary", "") <> "" then
        buttons.push({text: Glyphs().INFO, command: "summary"})
    end if

    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = 50
        btn.fixed = false
        if m.focusedItem = invalid then m.focusedItem = btn
        components.push(btn)
    end for

    ' more/pivots drop down
    if m.item.relatedItems <> invalid and m.item.relatedItems.count() > 0 then
        btn = createDropDown(Glyphs().MORE, m.customFonts.glyphs, int(720 * .80), m)
        btn.SetDropDownPosition("right")
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = 47
        if m.focusedItem = invalid then m.focusedItem = btn
        for each item in m.item.relatedItems
            option = {
                text: item.GetSingleLineTitle(),
                command: "show_grid",
                plexObject: item,
            }
            option.Append(optionPrefs)
            btn.options.push(option)
        end for
        components.push(btn)
    end if

    return components
end function

function artistHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "summary" then
        m.summaryVisible = not m.summaryVisible = true
        gridVisible = not m.summaryVisible
        Debug("toggle summary: gridVisible=" + tostr(gridVisible) + ", summaryVisible=" + tostr(m.summaryVisible))

        ' toggle summary
        m.summaryTitle.SetVisible(m.summaryVisible)
        m.summary.SetVisible(m.summaryVisible)

        ' toggle grid (hubs)
        for each grid in m.hbGrid.components
            for each component in grid.components
                component.focusable = gridVisible
                if component.IsOnScreen() then component.SetVisible(gridVisible)
            end for
        end for

        ' invalidate focus sibling and last focus item
        m.focusedItem.SetFocusSibling("right", invalid)
        m.lastFocusedItem = invalid

        m.screen.DrawAll()
    else
        return ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
    end if

    return handled
end function
