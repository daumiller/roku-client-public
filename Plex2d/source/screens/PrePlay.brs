function PreplayScreen() as object
    if m.PreplayScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Preplay Screen"

        ' Methods
        obj.Show = preplayShow
        obj.Init = preplayInit
        obj.OnResponse = preplayOnResponse
        obj.GetComponents = preplayGetComponents

        obj.GetButtons = preplayGetButtons
        obj.GetImages = preplayGetImages
        obj.GetSideInfo = preplayGetSideInfo
        obj.GetMainInfo = preplayGetMainInfo

        m.PreplayScreen = obj
    end if

    return m.PreplayScreen
end function

sub preplayInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts.Large = FontRegistry().GetTextFont(28)
    m.customFonts.button = FontRegistry().GetIconFont(32)

    m.itemContainer = CreateObject("roAssociativeArray")
end sub

function createPreplayScreen(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PreplayScreen())

    obj.Init()

    obj.requestedItem = item
    obj.server = item.container.server

    return obj
end function

sub preplayShow()
    if not application().isactivescreen(m) then return

    if m.itemcontainer.request = invalid then
        request = createPlexRequest(m.server, m.requestedItem.Get("key"))
        context = request.CreateRequestContext("preplay_item", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.itemContainer = context
    else if m.item <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)
    else
        dialog = createDialog("Unable to load", "Sorry, we couldn't load the requested item.", m)
        dialog.AddButton("OK", "close_screen")
        dialog.HandleButton = preplayDialogHandleButton
        dialog.Show()
    end if
end sub

sub preplayOnResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response
    context.items = response.items
    if context.items = invalid then return

    if context.items.count() = 1 then
        m.item = context.items[0]
    else
        ' Context - Playlist or other context?
        m.curIndex = 0
        m.items = context.items
        m.item = m.items[0]
    end if

    m.show()
end sub

sub preplayGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' TODO(rob) position of items / HD2SD - where/when do we convert?
    descBlock = { x: 0, y: 364, width: 1280, height: 239 }

    ' *** Background Artwork *** '
    if m.item.Get("art") <> invalid then
        image = { source: m.server.BuildUrl(m.item.Get("art"), true), server: m.server, transcodeOpts: {blur: 4} }
        background = createImage(image, 1280, 720)
        m.components.Push(background)

        background = createBlock(Colors().ScrDrkOverlayClr)
        background.setFrame(0, 72, 1280, 720)
        m.components.Push(background)
    end if

    background = createBlock(Colors().ScrMedOverlayClr)
    background.setFrame(descBlock.x, descBlock.y, descBlock.width, descBlock.height)
    m.components.Push(background)

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

    ' NOTE: the poster images can vary in height/width depending on the content.
    ' This means we will have to calculate the offsets ahead of time to know
    ' where to place the summary. That is, until we have a way to tell a HBox to
    ' use all the left over space and resize accordingly.

    xOffset = 50
    spacing = 30

    ' *** Buttons *** '
    vbButtons = createVBox(false, false, false, 10)
    components = m.GetButtons()
    for each comp in components
        vbButtons.AddComponent(comp)
    end for
    vbButtons.SetFrame(xOffset, 125, 100, 720-125)
    m.components.Push(vbButtons)
    xOffset = xOffset + spacing + m.components.peek().width

    ' *** Poster and Episode thumb *** '
    vbImages = createVBox(false, false, false, 20)
    components = m.GetImages()
    for each comp in components
        vbImages.AddComponent(comp)
    end for
    vbImages.SetFrame(xOffset, 125, components.peek().width, 720-125)
    m.components.Push(vbImages)

    ' *** Media Flag *** '
    hbMediaFlags = createHBox(false, false, false, 20)
    hbMediaFlags.SetFrame(xOffset, descBlock.y + descBlock.height + spacing, m.components.peek().width, 20)
    hbMediaFlags.halign = hbMediaFlags.JUSTIFY_CENTER
    tags = ["videoResolution", "audioCodec", "audioChannels"]
    for each tag in tags
        url = m.item.getMediaFlagTranscodeURL(tag, hbMediaFlags.width, hbMediaFlags.height)
        if url <> invalid then
            image = createImageScaleToParent(url, hbMediaFlags)
            hbMediaFlags.AddComponent(image)
        end if
    end for
    m.components.push(hbMediaFlags)

    ' *** Title, Media Info ***
    xOffset = xOffset + spacing + m.components.peek().width
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
    summary.SetFrame(xOffset, 364, 1230-xOffset, 239)
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

function preplayGetMainInfo() as object
    components = createObject("roList")

    spacer = "   "
    normalFont = FontRegistry().font16
    if tostr(m.item.Get("type")) = "episode" then
        components.push(createLabel(m.item.Get("grandparentTitle", ""), m.customFonts.Large))
        components.push(createLabel(m.item.Get("title", ""), m.customFonts.Large))

        text = m.item.GetOriginallyAvailableAt()
        if m.item.Has("index") and m.item.Has("parentIndex") then
            text = "Season " + tostr(m.item.Get("parentIndex")) + " Episode " + m.item.Get("index") + " / " + text
        end if
        components.push(createLabel(text, normalFont))

        if m.item.IsUnwatched() then
            components.push(createLabel("Unwatched", normalFont))
        end if

        components.push(createSpacer(0, normalFont.getOneLineHeight()))
    else
        components.push(createLabel(m.item.Get("title", ""), m.customFonts.Large))
        components.push(createLabel(ucase(m.item.GetLimitedTagValues("Genre",3)), normalFont))

        text = m.item.GetDuration()
        if m.item.IsUnwatched() then
            text = text + " / Unwatched"
        end if
        components.push(createLabel(text, normalFont))

        components.push(createSpacer(0, normalFont.getOneLineHeight()))
        components.push(createLabel("DIRECTOR" + spacer + m.item.GetLimitedTagValues("Director",5), normalFont))
        components.push(createLabel("CAST" + spacer + m.item.GetLimitedTagValues("Role",5), normalFont))
    end if

    return components
end function

function preplayGetSideInfo() as object
    components = createObject("roList")

    if tostr(m.item.Get("type")) = "episode" then
        label = createLabel(firstOf(m.item.Get("year"),""), m.customFonts.Large)
        label.halign = label.JUSTIFY_RIGHT
        components.push(label)

        label = createLabel(m.item.GetDuration(), m.customFonts.Large)
        label.halign = label.JUSTIFY_RIGHT
        components.push(label)

        label = createLabel(firstOf(m.item.Get("rating"),""), FontRegistry().font16)
        label.halign = label.JUSTIFY_RIGHT
        components.push(label)
    else
        label = createLabel(firstOf(m.item.Get("year"),""), m.customFonts.Large)
        label.halign = label.JUSTIFY_RIGHT
        components.push(label)

        label = createLabel(firstOf(m.item.Get("rating"),""), FontRegistry().font16)
        label.halign = label.JUSTIFY_RIGHT
        components.push(label)

        label = createLabel(firstOf(m.item.Get("contentRating"),""), FontRegistry().font16)
        label.halign = label.JUSTIFY_RIGHT
        components.push(label)
    end if

    return components
end function

function preplayGetImages() as object
    components = createObject("roList")

    posterSize = invalid
    mediaSize = invalid

    if tostr(m.item.Get("type")) = "episode"  then
        posterSize = { width: 210, height: 315 }
        mediaSize =  { width: 210, height: 118 }
    else
        posterSize = { width: 295, height: 434 }
    end if

    ' TODO(rob): better way to choose which thumb to use?
    posterThumb = firstOfArr([m.item.Get("parentThumb"), m.item.Get("grandparentThumb"), m.item.Get("thumb"), m.item.Get("composite"), ""])
    image = { source: m.server.BuildUrl(posterThumb, true), server: m.server, }
    posterThumb = createImage(image, posterSize.width, posterSize.height)
    components.push(posterThumb)

    if mediaSize <> invalid then
        image = { source: m.server.BuildUrl(m.item.Get("thumb"), true), server: m.server, }
        mediaThumb = createImage(image, mediaSize.width, mediaSize.height)
        components.push(mediaThumb)
    end if

    return components
end function

function preplayGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")
    ' TODO(rob) I need to find a better font editor to map the fonts.
    if m.item.InProgress() then
        buttons.push({text: "g", command: "resume"})
    end if
    buttons.push({text: "g", command: "play"})
    if m.item.IsUnwatched() then
        buttons.push({text: "b", command: "scrobble"})
    else
        buttons.push({text: "c", command: "unscrobble"})
    end if
    buttons.push({text: "f", command: "more"})

    for each button in buttons
        btn = createButton(button.text, m.customFonts.button, button.command)
        btn.SetColor(Colors().TextClr, Colors().BtnBkgClr)
        btn.width = 100
        btn.height = 50
        if m.focusedItem = invalid then m.focusedItem = btn
        components.push(btn)
    end for

    return components
end function

sub preplayDialogHandleButton(button as object)
    Debug("dialog button selected with command: " + tostr(button.command))

    if button.command = "close_screen" then
        m.Close()
        Application().popScreen(m.screen)
    else
        Debug("command not defined: (closing dialog now) " + tostr(button.command))
        m.Close()
    end if
end sub
