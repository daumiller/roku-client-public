function createPreplayContextScreen(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PreplayScreen())
    obj.screenName = "Preplay Context"

    ' Method overrides
    obj.Init = ppcInit
    obj.Show = ppcShow
    obj.OnChildResponse = ppcOnChildResponse
    obj.GetComponents = ppcGetComponents
    obj.GetMainInfo = ppcGetMainInfo
    obj.GetImages = ppcGetImages

    obj.Init()

    obj.server = item.container.server
    obj.requestedItem = item

    return obj
end function

sub ppcInit()
    ApplyFunc(PreplayScreen().Init, m)
    m.childContainer = CreateObject("roAssociativeArray")
    m.children = CreateObject("roList")
end sub

sub ppcShow()
    if not application().isactivescreen(m) then return

    if m.itemContainer.request = invalid then
        ' probably a more correct way to do this
        path = "/library/metadata/" + m.requestedItem.Get("ratingKey")
        request = createPlexRequest(m.server, path)
        context = request.CreateRequestContext("preplay_item", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.itemContainer = context
    end if

    if m.childContainer.request = invalid then
        path = m.requestedItem.Get("key") + "?excludeAllLeaves=1"
        request = createPlexRequest(m.server, path)
        context = request.CreateRequestContext("preplay_item", createCallable("OnChildResponse", m))
        Application().StartRequest(request, context)
        m.childContainer = context
    end if

    if m.itemContainer.response <> invalid and m.childContainer.response <> invalid then
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

    ' *** Background Artwork *** '
    if m.item.Get("art") <> invalid then
        image = { source: m.server.BuildUrl(m.item.Get("art"), true), server: m.server, transcodeOpts: {blur: 2} }
        background = createImage(image, 1280, 720)
        m.components.Push(background)

        background = createBlock(Colors().ScrDrkOverlayClr)
        background.setFrame(0, 72, 1280, 720)
        m.components.Push(background)

        background = createBlock(Colors().ScrMedOverlayClr)
        background.setFrame(0, 265, 1280, 720)
        m.components.Push(background)
    end if

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

    ' NOTE: the poster images can vary in height/width depending on the content.
    ' This means we will have to calculate the offsets ahead of time to know
    ' where to place the summary. That is, until we have a way to tell a HBox to
    ' use all the left ofter space and resize accordingly.

    xOffset = 50
    spacing = 30

    ' *** Parent Poster / Art *** '
    vbImages = createVBox(false, false, false, 10)
    container = m.GetImages()
    for each comp in container.components
        vbImages.AddComponent(comp)
    end for
    vbImages.SetFrame(xOffset, 125, container.width, 720-125)
    m.components.Push(vbImages)
    xOffset = xOffset + spacing + m.components.peek().width

    ' *** Grid for Children *** '
    yOffset = 125 + spacing + container.height
    hbGrid = createHBox(false, false, false, 10)
    hbGrid.SetFrame(50, yOffset, 2000*2000, 206)
    hbGrid.ignoreParentShift = true

    for each item in m.children
        ' TODO(rob): another place to figure out how to determine orientation
        contentType = item.Get("type")
        if contentType = "show" or contentType = "season" or contentType = "movie" then
            orientation = ComponentClass().ORIENTATION_PORTRAIT
        else
            orientation = ComponentClass().ORIENTATION_LANDSCAPE
        end if

        card = createCard(ImageClass().BuildImgObj(item, m.server), item.GetSingleLineTitle(), invalid, item.GetUnwatchedCount())
        card.SetOrientation(orientation)
        card.width = card.GetWidthForOrientation(card.orientation, hbGrid.Height)
        card.fixed = false
        card.setMetadata(item.attrs)
        card.plexObject = item
        card.SetFocusable("card")
        if m.focusedItem = invalid then m.focusedItem = card
        hbGrid.AddComponent(card)
    end for
    m.components.Push(hbGrid)

    ' *** Title, Media Info ***
    vbInfo = createVBox(false, false, false, 0)
    components = m.GetMainInfo()
    for each comp in components
        vbInfo.AddComponent(comp)
    end for
    vbInfo.SetFrame(xOffset, 125, 1230-xOffset, 239)
    m.components.Push(vbInfo)

    ' TODO(rob): dynamic width
    summary = createLabel(firstOf(m.item.Get("summary"),""), FontRegistry().font16)
    summary.SetPadding(20, 20, 20, 0)
    summary.wrap = true
    summary.SetFrame(xOffset, 265, 1230-xOffset, 239)
    m.components.push(summary)

    ' *** Right Side Info *** '
    vbox = createVBox(false, false, false, 0)
    vbox.SetFrame(1230-200, 125, 200, 239)
    components = m.GetSideInfo()
    for each comp in components
        vbox.AddComponent(comp)
    end for
    m.components.Push(vbox)
end sub

function ppcGetMainInfo() as object
    components = createObject("roList")

    ' TODO(rob): change the info based on content type
    label = createLabel(firstOf(m.item.Get("title"),""), m.customFonts.Large)
    components.push(label)

    label = createLabel(ucase(m.item.GetLimitedTagValues("Genre",3)), FontRegistry().font16)
    components.push(label)

    label = createLabel(m.item.GetDuration(), FontRegistry().font16)
    components.push(label)

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

    poster = createImage(ImageClass().BuildImgObj(m.item, m.server), container.width, container.height)
    poster.SetOrientation(orientation)
    container.components.push(poster)

    return container
end function
