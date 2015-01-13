' TODO(rob): check if media IsAccessible
function PreplayScreen() as object
    if m.PreplayScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Preplay Screen"

        ' Methods
        obj.Show = preplayShow
        obj.Refresh = preplayRefresh
        obj.Init = preplayInit
        obj.OnResponse = preplayOnResponse
        obj.HandleCommand = preplayHandleCommand
        obj.GetComponents = preplayGetComponents
        obj.OnPlayButton = preplayOnPlayButton

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
    m.customFonts.large = FontRegistry().GetTextFont(28)
    m.customFonts.glyphs = FontRegistry().GetIconFont(32)

    m.requestContext = invalid
end sub

function createPreplayScreen(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PreplayScreen())

    obj.Init()

    obj.requestItem = item
    obj.server = item.GetServer()

    return obj
end function

sub preplayShow()
    if not Application().IsActiveScreen(m) then return

    if m.requestContext = invalid then
        request = createPlexRequest(m.server, m.requestItem.GetItemPath())
        context = request.CreateRequestContext("preplay_item", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.requestContext = context
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

    m.Show()
end sub

sub preplayOnPlayButton(focusedItem=invalid as dynamic)
    m.CreatePlayerForItem(m.item)
end sub

function preplayHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "play" or command = "resume" or command = "play_extra" then
        handled = true
        videoItem = iif(command = "play_extra", item.plexObject, m.item)
        screen = VideoPlayer().CreateVideoScreen(videoItem, (command = "resume"))
        if screen.screenError = invalid then
            Application().PushScreen(screen)
        else
            dialog = createDialog("command failed: " + command, screen.screenError, m)
            dialog.Show()
        end if
    else if command = "scrobble" then
        m.item.Scrobble(createCallable("Refresh", m))
    else if command = "unscrobble" then
        m.item.Unscrobble(createCallable("Refresh", m))
    else if command = "settings" then
        settings = createSettings(m)
        settings.GetPrefs = preplayGetPrefs
        settings.screenPref = true
        settings.Show()
    else if command = "show_grid" then
        Application().PushScreen(createGridScreen(item.plexObject))
    else if command = "go_to_show" then
        Application().PushScreen(createPreplayContextScreen(m.item, m.item.Get("grandparentKey")))
    else if command = "go_to_season" then
        Application().PushScreen(createGridScreen(m.item, m.item.Get("parentKey") + "/children", 2, ComponentClass().ORIENTATION_LANDSCAPE))
    else if not ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
        handled = false
    end if

    return handled
end function

sub preplayGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' TODO(rob) position of items / HD2SD - where/when do we convert?
    descBlock = { x: 0, y: 364, width: 1280, height: 239 }

    ' *** Background Artwork *** '
    if m.item.Get("art") <> invalid then
        background = createImage(m.item, 1280, 720, { blur: 4 })
        background.SetOrientation(background.ORIENTATION_LANDSCAPE)
        m.components.Push(background)

        background = createBlock(Colors().OverlayDark)
        background.setFrame(0, 72, 1280, 720)
        m.components.Push(background)
    end if

    background = createBlock(Colors().OverlayMed)
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
    xOffset = xOffset + spacing + m.components.peek().width

    ' *** Progress Bar *** '
    if m.item.GetViewOffsetPercentage() > 0 then
        progress = createProgressBar(m.item.GetViewOffsetPercentage(), &h00000000, Colors().Orange)
        progress.setFrame(xOffset - spacing, descBlock.y, descBlock.width - xOffset + spacing, 6)
        progress.IsAnimated = true
        m.components.Push(progress)
    end if

    ' *** Title, Media Info ***
    vbInfo = createVBox(false, false, false, 0)
    components = m.GetMainInfo()
    for each comp in components
        vbInfo.AddComponent(comp)
    end for
    vbInfo.SetFrame(xOffset, 125, 1130-xOffset, 239)
    m.components.Push(vbInfo)

    ' TODO(rob): dynamic width
    summary = createLabel(m.item.Get("summary", ""), FontRegistry().font16)
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
    if m.item.Get("type", "") = "episode" then
        components.push(createLabel(m.item.Get("grandparentTitle", ""), m.customFonts.large))
        components.push(createLabel(m.item.Get("title", ""), m.customFonts.large))

        text = m.item.GetOriginallyAvailableAt()
        if m.item.Has("index") and m.item.Has("parentIndex") and not m.item.IsDateBased() then
            text = "Season " + tostr(m.item.Get("parentIndex")) + " Episode " + m.item.Get("index") + " / " + text
        end if
        components.push(createLabel(text, normalFont))

        if m.item.IsUnwatched() then
            components.push(createLabel("Unwatched", normalFont))
        end if

        components.push(createSpacer(0, normalFont.getOneLineHeight()))
    else
        components.push(createLabel(m.item.Get("title", ""), m.customFonts.large))
        components.push(createLabel(ucase(m.item.GetLimitedTagValues("Genre", 3)), normalFont))

        text = m.item.GetDuration()
        if m.item.IsUnwatched() then
            text = text + " / Unwatched"
        end if
        components.push(createLabel(text, normalFont))

        components.push(createSpacer(0, normalFont.getOneLineHeight()))
        if m.item.IsHomeVideo() then
            components.push(createSpacer(0, normalFont.getOneLineHeight()))
            components.push(createSpacer(0, normalFont.getOneLineHeight()))
        else
            components.push(createLabel("DIRECTOR" + spacer + m.item.GetLimitedTagValues("Director", 5), normalFont))
            components.push(createLabel("CAST" + spacer + m.item.GetLimitedTagValues("Role", 5), normalFont))
        end if
    end if

    ' Audio and Subtitles
    audioText = "None"
    subText = "None"
    mediaItems = m.item.mediaitems
    if mediaItems <> invalid and mediaItems.count() > 0 and mediaItems[0].HasStreams() then
        audioStream = mediaItems[0].parts[0].GetSelectedStreamOfType(2)
        if audioStream <> invalid then audioText = audioStream.GetTitle()

        subStream = mediaItems[0].parts[0].GetSelectedStreamOfType(3)
        if subStream <> invalid then subText = subStream.GetTitle()
    end if
    components.push(createLabel("AUDIO" + spacer + audioText, normalFont))
    components.push(createLabel("SUBTITLES" + spacer + subText, normalFont))

    return components
end function

function preplayGetSideInfo() as object
    components = createObject("roList")

    if tostr(m.item.Get("type")) = "episode" then
        components.push(createLabel(m.item.Get("year", ""), m.customFonts.large))
        components.push(createLabel(m.item.GetDuration(), m.customFonts.large))
        components.push(createStars(m.item.GetInt("rating"), 16))
    else
        components.push(createLabel(m.item.Get("year", ""), m.customFonts.large))
        components.push(createStars(m.item.GetInt("rating"), 16))
        components.push(createLabel(m.item.Get("contentRating", ""), FontRegistry().font16))
    end if

    for each comp in components
        comp.halign = comp.JUSTIFY_RIGHT
    end for

    return components
end function

function preplayGetImages() as object
    components = createObject("roList")

    posterSize = invalid
    mediaSize = invalid
    posterAttr = invalid
    ' TODO(rob): we probably need another layout Home Videos
    if m.item.Get("type", "") = "episode" then
        posterSize = { width: 210, height: 315 }
        mediaSize =  { width: 210, height: 118 }
    else if m.item.IsHomeVideo() then
        posterSize = { width: 210, height: 118 }
        mediaSize =  { width: 210, height: 118 }
        posterAttr = "art"
    else
        posterSize = { width: 295, height: 434 }
    end if

    posterThumb = createImage(m.item, posterSize.width, posterSize.height)
    posterThumb.thumbAttr = posterAttr
    components.push(posterThumb)

    if mediaSize <> invalid then
        ' We need to force this one to use the thumb attr
        mediaThumb = createImage(m.item, mediaSize.width, mediaSize.height)
        mediaThumb.thumbAttr = "thumb"
        components.push(mediaThumb)
    end if

    return components
end function

function preplayGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")
    if m.item.InProgress() then
        buttons.push({text: Glyphs().RESUME, command: "resume"})
    end if
    buttons.push({text: Glyphs().PLAY, command: "play"})
    if m.item.IsUnwatched() then
        buttons.push({text: Glyphs().SCROBBLE, command: "scrobble"})
    else
        buttons.push({text: Glyphs().UNSCROBBLE, command: "unscrobble"})
    end if

    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = 50
        if m.focusedItem = invalid then m.focusedItem = btn
        components.push(btn)
    end for

    optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: btn.height
        padding: { right: 10, left: 10, top: 0, bottom: 0 }
        font: FontRegistry().font16,
    }

    ' extras drop down
    if m.item.extraItems <> invalid and m.item.extraItems.count() > 0 then
        btn = createDropDown(Glyphs().EXTRAS, m.customFonts.glyphs, int(720 * .80), m)
        btn.SetDropDownPosition("right")
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = 47
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
    if m.item.extraItems <> invalid and m.item.extraItems.count() > 0 or m.item.Get("type", "") = "episode" then
        btn = createDropDown(Glyphs().MORE, m.customFonts.glyphs, int(720 * .80), m)
        btn.SetDropDownPosition("right")
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = 47
        if m.focusedItem = invalid then m.focusedItem = btn

        ' manual pivots for an episode
        if m.item.Get("type", "") = "episode" then
            episodePivots = [
                {command: "go_to_show", text: "Go to show"},
                {command: "go_to_season", text: "Go to season " + m.item.Get("parentIndex", "")},
            ]
            for each pivot in episodePivots
                option = {}
                option.Append(pivot)
                option.Append(optionPrefs)
                btn.options.push(option)
            end for
        end if

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

    ' settings
    ' btn = createButton(Glyphs().CONFIG, m.customFonts.glyphs, "settings")
    ' btn.SetColor(Colors().Text, Colors().Button)
    ' btn.width = 100
    ' btn.height = 50
    ' if m.focusedItem = invalid then m.focusedItem = btn
    ' components.push(btn)

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

function preplayGetPrefs() as object
    ' TODO(rob): set the default prefs
    prefs = CreateObject("roAssociativeArray")
    prefs.keys = CreateObject("roList")

    playback = CreateObject("roList")
    prefs.keys.push("Playback")
    prefs.playback = playback

    quality_options = [
        {title: "20 Mbps",  value: "20"},
        {title: "12 Mbps",  value: "12"},
        {title: "10 Mbps",  value: "10"},
        {title: "8 Mbps",   value: "8"},
        {title: "4 Mbps",   value: "4"},
        {title: "3 Mbps",   value: "3"},
        {title: "2 Mbps",   value: "2"},
        {title: "1.5 Mbps", value: "1.5"},
        {title: "720 Kbps", value: "720"},
        {title: "320 Kbps", value: "320"},

    ]

    transcode_options = [
        {title: "Direct Play",  value: "direct_play"},
        {title: "Direct Stream",  value: "direct_stream"},
        {title: "Transcode",  value: "transcode"},
    ]

    enadis_options = [
        {title: "Enabled",  value: "enabled"},
        {title: "Disabled",  value: "disabled"},
    ]

    todo_options = [{title: "TODO", value: "TODO"}]

    playback.Push({command: "transcoding", title: "Transcoding", options: transcode_options, prefType: "enum"})
    playback.Push({command: "quality", title: "Streaming Quality", options: quality_options, prefType: "enum"})
    playback.Push({command: "audio_stream", title: "Audio Stream", options: todo_options, prefType: "enum"})
    playback.Push({command: "subtitle_stream", title: "Subtitle Stream", options: todo_options, prefType: "enum"})
    playback.Push({command: "media", title: "Media", options: todo_options, prefType: "enum"})
    playback.Push({command: "continuous", title: "Continuous Play", options: enadis_options, prefType: "enum"})

    return prefs
end function

' TODO(rob): find a better way to refresh.. mainly to kill the image flashing
sub preplayRefresh(request=invalid as dynamic, response=invalid as dynamic, context=invalid as dynamic)
    ' clear a few items to fully refresh the screen (without destorying the screen)
    m.requestContext = invalid
    m.item = invalid

    ' sticky buttons
    m.refocus = computeRect(m.focusedItem)
    m.refocus.id = m.focusedItem.id

    m.Show()
end sub
