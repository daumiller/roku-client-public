function PreplayContextScreen() as object
    if m.PreplayContextScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PreplayScreen())

        obj.screenName = "Preplay Context"

        ' Methods
        obj.Init = ppcInit
        obj.ResetInit = ppcResetInit
        obj.Show = ppcShow
        obj.OnChildResponse = ppcOnChildResponse
        obj.GetComponents = ppcGetComponents
        obj.GetMainInfo = ppcGetMainInfo
        obj.GetImages = ppcGetImages
        obj.GetButtons = ppcGetButtons
        obj.Refresh = ppcRefresh

        ' Preplay overrides
        obj.LoadContext = ppcLoadContext

        m.PreplayContextScreen = obj
    end if

    return m.PreplayContextScreen
end function

function createPreplayContextScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PreplayContextScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub ppcInit()
    ApplyFunc(PreplayScreen().Init, m)

    m.ResetInit(m.path)
end sub

sub ppcResetInit(path=invalid as dynamic)
    m.DisableListeners(true)
    m.server = m.requestItem.GetServer()

    ' path override (optional)
    if path <> invalid then
        m.path = path
        m.childrenPath = m.path + "/children"
    else
        m.path = m.requestItem.GetItemPath()
        m.childrenPath = m.requestItem.GetAbsolutePath("key")
    end if

    m.childrenPath = AddUrlParam(m.childrenPath, "excludeAllLeaves=1")
    m.parentPath = AddUrlParam(m.path, "includeRelated=1&includeRelatedCount=0&includeOnDeck=1&includeExtras=1")

    m.requestContext = invalid
    m.childRequestContext = invalid
    m.children = CreateObject("roList")
end sub

sub ppcShow()
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

sub ppcGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    prop = {
        yOffset: 125
        xOffset: 50
        spacing: 30
        buttonWidth: 100
        gridHeight: 206
        rightWidth: 200
        yOffsetOverlay: 265
    }

    ' *** Background Artwork *** '
    if m.item.Get("art") <> invalid then
        m.background = createBackgroundImage(m.item)
        m.components.Push(m.background)
        m.SetRefreshCache("background", m.background)
    end if

    overlay = createBlock(Colors().OverlayMed)
    overlay.setFrame(0, prop.yOffsetOverlay, 1280, 720)
    m.components.Push(overlay)

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

    ' *** Buttons *** '
    vbButtons = createVBox(false, false, false, 10)
    vbButtons.SetFocusManual(invalid)
    components = m.GetButtons()
    for each comp in components
        vbButtons.AddComponent(comp)
    end for
    vbButtons.SetFrame(prop.xOffset, prop.yOffset, prop.buttonWidth, 720 - prop.yOffset)
    m.components.Push(vbButtons)
    xOffset = prop.xOffset + prop.spacing + m.components.peek().width

    ' *** Parent Poster / Art *** '
    vbImages = createVBox(false, false, false, 10)
    container = m.GetImages()
    for each comp in container.components
        vbImages.AddComponent(comp)
    end for
    vbImages.SetFrame(xOffset, prop.yOffset, container.width, 720 - prop.yOffset)
    m.components.Push(vbImages)
    xOffset = xOffset + prop.spacing + m.components.peek().width

    ' *** Grid for Children *** '
    hbGrid = createHBox(false, false, false, 10)
    hbGrid.DisableNonParentExit("right")
    hbGrid.DisableNonParentExit("left")
    hbGrid.ignoreParentShift = true
    hbGrid.demandCenter = true

    for each item in m.children
        ' TODO(rob): another place to figure out how to determine orientation
        contentType = item.Get("type")
        if contentType = "show" or contentType = "season" or contentType = "movie" then
            orientation = ComponentClass().ORIENTATION_PORTRAIT
        else
            orientation = ComponentClass().ORIENTATION_LANDSCAPE
        end if

        card = createCard(item, item.GetOverlayTitle(), invalid, item.GetUnwatchedCount())
        card.SetOrientation(orientation)
        card.width = card.GetWidthForOrientation(card.orientation, prop.gridHeight)
        card.fixed = false
        card.plexObject = item
        card.SetFocusable("show_item")
        if m.focusedItem = invalid then m.focusedItem = card
        hbGrid.AddComponent(card)
    end for
    hbGrid.SetFrame(prop.xOffset, prop.yOffset + prop.spacing + container.height, hbgrid.getpreferredwidth(), prop.gridHeight)
    m.components.Push(hbGrid)

    ' *** Sumary (dependent on child placement)
    summary = createTextArea(m.item.Get("summary", ""), FontRegistry().NORMAL, 0)
    summary.SetPadding(10)
    summary.SetFrame(xOffset, prop.yOffsetOverlay, 1230 - xOffset, hbGrid.y - prop.yOffsetOverlay)
    summary.SetColor(Colors().Text, &h00000000, Colors().OverlayLht)
    m.components.push(summary)

    ' *** Title, Media Info ***
    vbInfo = createVBox(false, false, false, 0)
    components = m.GetMainInfo()
    for each comp in components
        vbInfo.AddComponent(comp)
    end for
    vbInfo.SetFrame(xOffset, prop.yOffset, 1230 - xOffset, hbGrid.y - prop.yOffset)
    m.components.Push(vbInfo)

    ' *** Right Side Info *** '
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(1230 - prop.rightWidth, prop.yOffset, prop.rightWidth, hbGrid.y - prop.yOffset)
    components = m.GetSideInfo()
    for each comp in components
        vbox.AddComponent(comp)
    end for
    m.components.Push(vbox)

    ' Focus layer between the seasons grid and action bar
    focusBox = createFocusBox(0, hbGrid.y - 2, AppSettings().GetWidth(), 1)
    focusBox.SetFocusManual(vbButtons, "up")
    focusBox.SetFocusManual(hbGrid, "down")
    m.components.Push(focusBox)
end sub

function ppcGetMainInfo() as object
    components = createObject("roList")

    ' TODO(rob): change the info based on content type
    components.push(createLabel(m.item.Get("title", ""), m.customFonts.Large))
    components.push(createLabel(ucase(m.item.GetLimitedTagValues("Genre", 3)), FontRegistry().NORMAL))

    text = joinArray([m.item.GetUnwatchedCountString(), m.item.GetDuration()], " / ")
    components.push(createLabel(text, FontRegistry().NORMAL))

    return components
end function

sub ppcOnChildResponse(request as object, response as object, context as object)
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

function ppcGetImages() as object
    container = createObject("roAssociativeArray")
    container.components = createObject("roList")

    ' TODO(rob): different orientation based on content type
    contentType = m.item.Get("type")
    if contentType = "show" or contentType = "season" then
        orientation = ComponentClass().ORIENTATION_PORTRAIT
    else if contentType = "clip" or contentType = "playlist" then
        orientation = ComponentClass().ORIENTATION_SQUARE
    else
        orientation = ComponentClass().ORIENTATION_LANDSCAPE
    end if

    container.height = 291
    container.width = ComponentClass().GetWidthForOrientation(orientation, container.height)

    m.posterThumb = createImage(m.item, container.width, container.height)
    m.posterThumb.fade = true
    m.posterThumb.cache = true
    m.posterThumb.SetOrientation(orientation)
    container.components.push(m.posterThumb)
    m.SetRefreshCache("posterThumb", m.posterThumb)

    return container
end function

function ppcGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")

    ' Always include a Play button
    ' TODO(schuyler): We may have secondary play actions as well. For example,
    ' Play on a season starts with the on deck item, so we might also have
    ' Play All to start at the beginning and Play Shuffled.
    '
    buttons.push({text: Glyphs().PLAY, command: "play_default" })
    buttons.Push({text: Glyphs().SHUFFLE, command: "shuffle"})

    ' TODO(rob): scrobble entire container - with warning?
    buttonHeight = 50
    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = buttonHeight
        btn.plexObject = button.item
        if m.focusedItem = invalid then m.focusedItem = btn
        components.push(btn)
    end for

    optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: buttonHeight
        padding: { right: 10, left: 10, top: 0, bottom: 0 }
        font: FontRegistry().NORMAL,
    }

    ' extras drop down
    if m.item.extraItems <> invalid and m.item.extraItems.count() > 0 then
        btn = createDropDownButton(Glyphs().EXTRAS, m.customFonts.glyphs, m)
        btn.SetDropDownPosition("right")
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = buttonHeight
        if m.focusedItem = invalid then m.focusedItem = btn
        for each item in m.item.extraItems
            option = {
                text: item.GetLongerTitle(),
                command: "play_extra",
                plexObject: item,
            }
            option.Append(optionPrefs)
            btn.options.push(option)
        end for
        components.push(btn)
    end if

    ' more/pivots drop down
    if m.item.relatedItems <> invalid and m.item.relatedItems.count() > 0 then
        btn = createDropDownButton(Glyphs().MORE, m.customFonts.glyphs, m)
        btn.SetDropDownPosition("right")
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = buttonHeight
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

sub ppcLoadContext(delta as integer)
    path = m.requestItem.GetContextPath(false)
    if path <> invalid then
        ApplyFunc(PreplayScreen().LoadContext, m, [delta, path])
    end if
end sub

sub ppcRefresh(request=invalid as dynamic, response=invalid as dynamic, context=invalid as dynamic)
    if m.itemPath <> invalid then
        m.ResetInit(m.itemPath)
        ApplyFunc(PreplayScreen().Refresh, m)
        m.refocus = invalid
    end if
end sub
