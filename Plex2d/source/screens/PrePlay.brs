' TODO(rob): check if media IsAccessible
function PreplayScreen() as object
    if m.PreplayScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Preplay Screen"

        ' Methods
        obj.Activate = preplayActivate
        obj.Show = preplayShow
        obj.Refresh = preplayRefresh
        obj.Init = preplayInit
        obj.OnResponse = preplayOnResponse
        obj.OnDetailsResponse = preplayOnDetailsResponse
        obj.LoadContext = preplayLoadContext
        obj.OnContextResponse = preplayOnContextResponse
        obj.HandleCommand = preplayHandleCommand
        obj.GetComponents = preplayGetComponents
        obj.OnPlayButton = preplayOnPlayButton
        obj.OnFwdButton = preplayOnFwdButton
        obj.OnRevButton = preplayOnRevButton
        obj.OnDelete = preplayOnDelete

        obj.GetButtons = preplayGetButtons
        obj.GetImages = preplayGetImages
        obj.GetSideInfo = preplayGetSideInfo
        obj.GetMainInfo = preplayGetMainInfo
        obj.UpdatePrefOptions = preplayUpdatePrefOptions
        obj.SetRefreshCache = preplaySetRefreshCache

        obj.OnSettingsClosed = preplayOnSettingsClosed

        m.PreplayScreen = obj
    end if

    return m.PreplayScreen
end function

sub preplayActivate()
    ApplyFunc(ComponentsScreen().Activate, m)

    ' set any temporary preplay setting overrides
    m.OnSettingsClosed({}, false)
end sub

sub preplayInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts.large = FontRegistry().GetTextFont(30)
    m.customFonts.glyphs = FontRegistry().GetIconFont(32)

    m.requestContext = invalid
    m.refreshCache = CreateObject("roAssociativeArray")
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

        ' re-request the item to verify it's accessible
        request = createPlexRequest(m.server, m.requestItem.GetItemPath(true))
        context = request.CreateRequestContext("preplay_item", createCallable("OnDetailsResponse", m))
        Application().StartRequest(request, context)
        m.LoadContext()
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

    ' Will we ever receive more than one item here? If we do, we'll end up using this
    ' context for << >> buttons
    if context.items.Count() = 1 then
        m.item = context.items[0]
    else
        m.curIndex = 0
        m.items = context.items
        m.item = m.items[m.curIndex]
    end if

    m.Show()
end sub

sub preplayOnContextResponse(request as object, response as object, context as object)
    response.ParseResponse()
    if response.items = invalid then return

    ' Only include library items and set curIndex
    m.items = createObject("roList")
    for index = 0 to response.items.Count() - 1
        item = response.items[index]
        if item <> invalid and item.IsLibraryItem() then
            if m.curIndex = invalid and item.Get("ratingKey") = m.item.Get("ratingKey") then
                m.curIndex = index
            end if
            m.items.Push(item)
        end if
    end for
end sub

sub preplayOnDetailsResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response
    item = response.items[0]
    if item = invalid then return

    ' Reset/Choose media now that we have all the details
    m.item = item
    MediaDecisionEngine().ChooseMedia(m.item)

    if item.IsAccessible() or m.accessibleLabel.sprite = invalid then return
    m.accessibleLabel.sprite.SetZ(1)
    m.accessibleLabel.roundedCorners = true
    m.accessibleLabel.SetColor(Colors().Text, Colors().RedAlt)
    m.accessibleLabel.SetText("Unavailable", true, true)
    m.screen.DrawAll()
end sub

sub preplayOnPlayButton(focusedItem=invalid as dynamic)
    if focusedItem <> invalid and focusedItem.plexObject <> invalid then
        plexObject = focusedItem.plexObject
    else
        plexObject = m.item
    end if

    options = createPlayOptions()

    ' See if we should resume
    if not plexObject.IsDirectory() then
        onDeck = plexObject
    else if plexObject.onDeck <> invalid and plexObject.onDeck.Count() > 0 then
        onDeck = plexObject.onDeck[0]
    else
        onDeck = invalid
    end if

    if onDeck <> invalid and onDeck.IsVideoItem() and onDeck.GetInt("viewOffset") > 0 then
        options.resume = VideoResumeDialog(onDeck, m)
        if options.resume = invalid then return
    end if

    m.CreatePlayerForItem(plexObject, options)
end sub

function preplayHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "play" or command = "resume" or command = "playWithoutTrailers" then
        plexObject = firstOf(item.plexObject, m.item)

        options = createPlayOptions()
        options.resume = (command = "resume")
        options.extrasPrefixCount = iif(command = "playWithoutTrailers", 0, invalid)

        m.CreatePlayerForItem(plexObject, options)
    else if command = "play_default" then
        m.OnPlayButton()
    else if command = "delete" then
        dialog = createDialog("Delete Item", "Are you sure you want to permanently delete this item from disk?", m)
        dialog.buttonsSingleLine = true
        dialog.AddButton("YES", true, Colors().GetAlpha("Red", 50))
        dialog.AddButton("NO", false)
        dialog.Show(true)
        if dialog.result = true then
            m.item.DeleteItem(createCallable("OnDelete", m))
        end if
    else if command = "scrobble" then
        m.item.Scrobble(createCallable("Refresh", m))
    else if command = "unscrobble" then
        m.item.Unscrobble(createCallable("Refresh", m))
    else if command = "settings" then
        if m.localPrefs = invalid then m.localPrefs = {}
        settings = createSettings(m)
        settings.GetPrefs = preplayGetPrefs
        settings.storage = m.localPrefs
        settings.Show()
        settings.On("selected", createCallable("UpdatePrefOptions", m))
        settings.On("close", createCallable("OnSettingsClosed", m))
        settings.AddListener(m, "OnFailedFocus", CreateCallable("OnFailedFocus", settings))
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
        m.background = createImage(m.item, 1280, 720, { blur: 20, opacity: 70, background: Colors().ToHexString("Black") })
        m.background.SetOrientation(m.background.ORIENTATION_LANDSCAPE)
        m.background.cache = true
        m.background.fade = true
        m.components.Push(m.background)
        m.SetRefreshCache("background", m.background)
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
        progress = createProgressBar(m.item.GetViewOffsetPercentage(), Colors().Transparent, Colors().Orange)
        progress.setFrame(xOffset - spacing, descBlock.y, descBlock.width - xOffset + spacing, 6)
        progress.IsAnimated = true
        m.components.Push(progress)
    end if

    ' *** Title, Media Info ***
    m.vbInfo = createVBox(false, false, false, 0)
    m.vbInfo.SetFrame(xOffset, 125, 1130-xOffset, 239)
    components = m.GetMainInfo()
    for each comp in components
        m.vbInfo.AddComponent(comp)
    end for
    m.components.Push(m.vbInfo)

    summary = createTextArea(m.item.Get("summary", ""), FontRegistry().NORMAL, 0)
    summary.SetPadding(10, 10, 10, 0)
    summary.SetFrame(xOffset, 364, 1230-xOffset, 239)
    summary.SetColor(Colors().Text, &h00000000, Colors().OverlayLht)
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
    normalFont = FontRegistry().NORMAL
    if m.item.Get("type", "") = "episode" then
        components.push(createLabel(m.item.Get("grandparentTitle", ""), m.customFonts.large))
        components.push(createLabel(m.item.Get("title", ""), m.customFonts.large))

        text = m.item.GetOriginallyAvailableAt()
        if m.item.Has("index") and m.item.Has("parentIndex") and not m.item.IsDateBased() then
            text = "Season " + tostr(m.item.Get("parentIndex")) + " Episode " + m.item.Get("index") + " / " + text
        end if
        components.push(createLabel(text, normalFont))

        statusBox = createHBox(false, false, false, normalFont.GetOneLineWidth(" ", 20))
        statusBox.width = m.vbInfo.width
        if m.item.IsUnwatched() then
            label = createLabel("Unwatched", normalFont)
            label.SetColor(Colors().Text, Colors().Orange)
            label.roundedCorners = true
            statusBox.AddComponent(label)
        end if

        ' always add the accessible label (hidden) for reference
        m.accessibleLabel = createLabel(" ", normalFont)
        m.accessibleLabel.zOrderInit = -1
        statusBox.AddComponent(m.accessibleLabel)
        components.push(statusBox)

        components.push(createSpacer(0, normalFont.getOneLineHeight()))
    else
        components.push(createLabel(m.item.Get("title", ""), m.customFonts.large))
        components.push(createLabel(ucase(m.item.GetLimitedTagValues("Genre", 3)), normalFont))

        statusBox = createHBox(false, false, false, normalFont.GetOneLineWidth(" ", 20))
        statusBox.width = m.vbInfo.width
        durationLabel = createLabel(m.item.GetDuration(), normalFont)
        statusBox.AddComponent(durationLabel)
        if m.item.IsUnwatched() then
            label = createLabel("Unwatched", normalFont)
            label.SetColor(Colors().Text, Colors().Orange)
            label.roundedCorners = true
            statusBox.AddComponent(label)
        end if

        ' always add the accessible label (hidden) for reference
        m.accessibleLabel = createLabel(" ", normalFont)
        m.accessibleLabel.zOrderInit = -1
        statusBox.AddComponent(m.accessibleLabel)
        components.push(statusBox)

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
    mediaChoice = MediaDecisionEngine().ChooseMedia(m.item)
    if mediaChoice.audioStream <> invalid then
        audioText = mediaChoice.audioStream.GetTitle()
    else
        audioText = "None"
    end if
    if mediaChoice.subtitleStream <> invalid then
        subText = mediaChoice.subtitleStream.GetTitle()
    else
        subText = "None"
    end if
    m.audioLabel = createLabel("AUDIO" + spacer + audioText, normalFont)
    m.subtitleLabel = createLabel("SUBTITLES" + spacer + subText, normalFont)
    components.push(m.audioLabel)
    components.push(m.subtitleLabel)

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
        components.push(createLabel(m.item.Get("contentRating", ""), FontRegistry().NORMAL))
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

    m.posterThumb = createImage(m.item, posterSize.width, posterSize.height)
    m.posterThumb.thumbAttr = posterAttr
    m.posterThumb.fade = true
    m.posterThumb.cache = true
    components.push(m.posterThumb)
    m.SetRefreshCache("posterThumb", m.posterThumb)

    if mediaSize <> invalid then
        ' We need to force this one to use the thumb attr
        m.mediaThumb = createImage(m.item, mediaSize.width, mediaSize.height)
        m.mediaThumb.thumbAttr = "thumb"
        m.mediaThumb.fade = true
        m.mediaThumb.cache = true
        components.push(m.mediaThumb)
        m.SetRefreshCache("mediaThumb", m.mediaThumb)
    end if

    return components
end function

function preplayGetButtons() as object
    components = createObject("roList")
    buttons = createObject("roList")

    showPlayButton = true
    if m.item.InProgress() then
        buttons.push({text: Glyphs().RESUME, command: "resume", item: m.item})
    else
        buttons.push({text: Glyphs().PLAY, command: "play", item: m.item})
        showPlayButton = false
    end if

    showSecondaryPlay = (m.item.Get("type", "") = "movie" and AppSettings().GetIntPreference("cinema_trailers") > 0)
    if showSecondaryPlay then
        button = {
            type: "dropDown",
            text: Glyphs().PLAY,
            item: m.item,
            position: "right"
            options: createObject("roList")
        }
        if showPlayButton then
            button.options.Push({text: "Play from beginning", command: "play"})
        end if
        button.options.Push({text: "Play without trailers", command: "playWithoutTrailers"})
        buttons.push(button)
    else if showPlayButton then
        buttons.push({text: Glyphs().PLAY, command: "play", item: m.item})
    end if

    ' Settings
    if m.item.IsVideoItem() and m.item.mediaItems <> invalid then
        buttons.push({text: Glyphs().EQ, command: "settings", useIndicator: true})
    end if

    if m.item.IsUnwatched() then
        buttons.push({text: Glyphs().SCROBBLE, command: "scrobble"})
    else
        buttons.push({text: Glyphs().UNSCROBBLE, command: "unscrobble"})
    end if

    ' Shared prefs for any dropdown
    buttonHeight = 50
    optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: buttonHeight
        padding: { right: 10, left: 10, top: 0, bottom: 0 }
        font: FontRegistry().NORMAL,
    }

    ' extras drop down
    if m.item.extraItems <> invalid and m.item.extraItems.count() > 0 then
        button = {
            type: "dropDown",
            text: Glyphs().EXTRAS,
            position: "right",
            options: createObject("roList")
        }

        for each item in m.item.extraItems
            option = {
                text: item.GetLongerTitle(),
                command: "play",
                plexObject: item
            }
            button.options.Push(option)
        end for

        buttons.Push(button)
    end if

    ' more/pivots drop down
    if m.item.relatedItems <> invalid and m.item.relatedItems.count() > 0 or m.item.Get("type", "") = "episode" then
        button = {
            type: "dropDown",
            text: Glyphs().MORE,
            position: "right",
            options: createObject("roList")
        }

        ' manual pivots for an episode
        if m.item.Get("type", "") = "episode" then
            button.options.Push({command: "go_to_show", text: "Go to show"})
            button.options.Push({command: "go_to_season", text: "Go to season " + m.item.Get("parentIndex", "")})
        end if

        for each item in m.item.relatedItems
            option = {
                text: item.GetSingleLineTitle(),
                command: "show_grid",
                plexObject: item,
            }
            button.options.push(option)
        end for

        buttons.Push(button)
    end if

    if m.server.allowsMediaDeletion then
        buttons.push({text: Glyphs().DELETE, command: "delete"})
    end if

    for each button in buttons
        if button.type = "dropDown" then
            btn = createDropDownButton(button.text, m.customFonts.glyphs, buttonHeight * 5, m)
            btn.SetDropDownPosition(button.position)
            for each option in button.options
                option.Append(optionPrefs)
                option.plexObject = firstOf(option.plexObject, button.item)
                btn.options.push(option)
            end for
        else
            btn = createButton(button.text, m.customFonts.glyphs, button.command, (button.useIndicator = true))
        end if

        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = buttonHeight
        btn.plexObject = button.item
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

function preplayGetPrefs() as object
    groups = CreateObject("roList")
    playback = CreateObject("roList")
    settings = AppSettings()

    ' In order to show the currently selected media/streams we need to run the
    ' MDE first.
    item = m.screen.item
    mediaChoice = MediaDecisionEngine().ChooseMedia(item)
    part = mediaChoice.media.parts[0]

    ' Media item selection, if we have more than one.
    if item.mediaItems.Count() > 1 then
        options = CreateObject("roList")
        for each media in item.mediaItems
            options.Push({title: media.ToString(), value: media.Get("id")})
        next

        playback.Push({
            key: "media",
            title: "Version",
            default: mediaChoice.media.Get("id"),
            prefType: "enum",
            options: options
        })
    end if

    ' Audio stream selection.
    streams = part.GetStreamsOfType(PlexStreamClass().TYPE_AUDIO)
    if streams.Count() > 0 then
        options = CreateObject("roList")
        for each stream in streams
            options.Push({title: stream.GetTitle(), value: stream.Get("id")})
        next

        if mediaChoice.audioStream <> invalid then
            selectedId = mediaChoice.audioStream.Get("id")
        else
            selectedId = "0"
        end if

        playback.Push({
            key: "audio_stream",
            title: "Audio",
            default: selectedId,
            prefType: "enum",
            options: options
        })
    end if

    ' Subtitle stream selection.
    streams = part.GetStreamsOfType(PlexStreamClass().TYPE_SUBTITLE)
    if streams.Count() > 0 then
        options = CreateObject("roList")
        for each stream in streams
            options.Push({title: stream.GetTitle(), value: stream.Get("id")})
        next

        if mediaChoice.subtitleStream <> invalid then
            selectedId = mediaChoice.subtitleStream.Get("id")
        else
            selectedId = "0"
        end if

        playback.Push({
            key: "subtitle_stream",
            title: "Subtitles",
            default: selectedId,
            prefType: "enum",
            options: options
        })
    end if

    ' Quality, capped at the current media's quality.
    options = CreateObject("roList")

    if item.GetServer().IsLocalConnection() then
        defaultQuality = settings.GetIntPreference("local_quality")
    else
        defaultQuality = settings.GetIntPreference("remote_quality")
    end if

    height = mediaChoice.media.GetVideoResolution()
    bitrate = mediaChoice.media.GetInt("bitrate")

    qualities = settings.GetGlobal("qualities")
    prevQuality = invalid
    for each quality in qualities
        if height >= quality.maxHeight and bitrate >= quality.maxBitrate then
            ' add previous (higher) quality if the media bitrate > pref quality
            if bitrate > quality.maxBitrate and options.Count() = 0 and prevQuality <> invalid then
                options.Push({title: prevQuality.title, value: tostr(prevQuality.index), index: prevQuality.index})
            end if
            options.Push({title: quality.title, value: tostr(quality.index), index: quality.index})
        else if options.Count() = 0 then
            prevQuality = quality
        end if
    next

    ' lets add all qualities if nothing matches the video
    if options.Count() = 0 then
        for each quality in qualities
            options.Push({title: quality.title, value: tostr(quality.index), index: quality.index})
        end for
    else
        if defaultQuality > options[0].index then
            defaultQuality = options[0].index
        end if
    end if

    playback.Push({
        key: "quality",
        title: "Quality",
        default: tostr(defaultQuality),
        prefType: "enum",
        options: options
    })

    ' Direct Play
    options = [
        {title: "Direct Play", key: "playback_direct", default: settings.GetPreference("playback_direct")},
        {title: "Direct Stream", key: "playback_remux", default: settings.GetPreference("playback_remux")},
        {title: "Transcode", key: "playback_transcode", default: settings.GetPreference("playback_transcode")}
    ]
    playback.Push({
        key: "direct_play",
        title: "Direct Play",
        prefType: "bool",
        options: options
    })

    groups.Push({
        title: "Playback",
        settings: playback
    })

    return groups
end function

sub preplayRefresh(request=invalid as dynamic, response=invalid as dynamic, context=invalid as dynamic)
    for each toCache in m.refreshCache
        if m[toCache] <> invalid then
            m.refreshCache[toCache] = m[toCache].region
        end if
    end for

    TextureManager().RemoveTextureByScreenId(m.screenID)
    m.CancelRequests()

    ' clear a few items to fully refresh the screen (without destorying the screen)
    m.requestContext = invalid
    m.item = invalid

    ' sticky buttons
    GetGlobalAA().AddReplace("nextComponentId", 1)
    m.refocus = computeRect(m.focusedItem)
    m.refocus.id = m.focusedItem.id

    m.Show()
end sub

sub preplayOnDelete(request as object, response as object, context as object)
    if response.IsSuccess() then
        Application().popScreen(m)
    else
        dialog = createDialog("Unable to delete media", "Please check your file permissions.", m)
        dialog.AddButton("OK", "close_screen")
        dialog.Show(true)
    end if
end sub

sub preplayOnSettingsClosed(overlay as object, backButton as boolean)
    ' If we have any local playback options, evaluate them now.
    if m.localPrefs <> invalid then
        plexObject = m.item
        spacer = "   "
        redraw = false

        selectedMedia = invalid
        selectedAudio = invalid
        selectedSubtitle = invalid

        if m.localPrefs.media <> invalid then
            AppSettings().SetPrefOverride("local_mediaId", m.localPrefs.media, m.screenID)
            for each media in plexObject.mediaItems
                media.selected = (m.localPrefs.media = media.Get("id"))
                if media.selected then
                    selectedMedia = media
                    selectedAudio = selectedMedia.parts[0].GetSelectedStreamOfType(PlexStreamClass().TYPE_AUDIO)
                    selectedSubtitle = selectedMedia.parts[0].GetSelectedStreamOfType(PlexStreamClass().TYPE_SUBTITLE)
                end if
            next

            ' Media selection changed, let's invalidate it.
            m.item.mediaChoice = invalid
        end if

        ' Determine the selected media item to update audio and subtitle prefs
        if selectedMedia = invalid and m.item.mediaChoice <> invalid then
            selectedMedia = plexObject.mediaItems[0]
        else if m.item.mediaChoice <> invalid then
            selectedMedia = m.item.mediaChoice.media
        end if

        if m.localPrefs.audio_stream <> invalid then
            selectedAudio = selectedMedia.parts[0].SetSelectedStream(PlexStreamClass().TYPE_AUDIO, m.localPrefs.audio_stream, false)
        end if

        if m.localPrefs.subtitle_stream <> invalid then
            selectedSubtitle = selectedMedia.parts[0].SetSelectedStream(PlexStreamClass().TYPE_SUBTITLE, m.localPrefs.subtitle_stream, false)
        end if

        if selectedAudio <> invalid then
            m.audioLabel.SetText("AUDIO" + spacer + selectedAudio.GetTitle(), true, true)
            redraw = true
        end if

        if selectedSubtitle <> invalid or m.localPrefs.media <> invalid then
            if selectedSubtitle <> invalid then
                subtitleText = selectedSubtitle.GetTitle()
            else
                subtitleText = "None"
            end if
            m.subtitleLabel.SetText("SUBTITLES" + spacer + subtitleText, true, true)
            redraw = true
        end if

        if m.localPrefs.quality <> invalid then
            AppSettings().SetPrefOverride("local_quality", m.localPrefs.quality, m.screenID)
            AppSettings().SetPrefOverride("remote_quality", m.localPrefs.quality, m.screenID)
        end if

        possiblePrefs = ["playback_direct", "playback_remux", "playback_transcode"]
        for each prefKey in possiblePrefs
            if m.localPrefs[prefKey] <> invalid then
                AppSettings().SetPrefOverride(prefKey, m.localPrefs[prefKey], m.screenID)
            end if
        next

        if redraw then m.screen.DrawAll()
    end if
end sub

sub preplayUpdatePrefOptions(settings as object, prefKey as string, prefValue=invalid as dynamic)
    ' Update the audio/subtitle options based on the media selection
    if prefKey = "media" and prefValue <> invalid then
        ' Invalidate a few dependent settings
        m.localPrefs.audio_stream = invalid
        m.localPrefs.subtitle_stream = invalid
        selectedMedia = invalid

        for each media in m.item.mediaItems
            if prefValue = media.Get("id") then
                selectedMedia = media
                exit for
            end if
        end for

        ' iterate through the prefs reference to update the audio streams, as of now
        ' we only have one groups to work with.
        for each pref in settings.prefs[0].settings
            ' Update available audio options
            if pref.key = "audio_stream" then
                pref.options.Clear()
                if selectedMedia <> invalid then
                    streams = selectedMedia.parts[0].GetStreamsOfType(PlexStreamClass().TYPE_AUDIO)
                    if streams.Count() > 0 then
                        for each stream in streams
                            pref.options.Push({title: stream.GetTitle(), value: stream.Get("id")})
                        next
                    end if
                end if
            end if

            ' Update available subtitle options
            if pref.key = "subtitle_stream" then
                pref.options.Clear()
                if selectedMedia <> invalid then
                    streams = selectedMedia.parts[0].GetStreamsOfType(PlexStreamClass().TYPE_SUBTITLE)
                    if streams.Count() > 0 then
                        for each stream in streams
                            pref.options.Push({title: stream.GetTitle(), value: stream.Get("id")})
                        next
                    end if
                end if
            end if
        end for

    end if
end sub

sub preplayLoadContext()
    ' Load context for the preplay (<< >> buttons)
    path = m.requestItem.GetAllItemsPath()
    if m.items = invalid and path <> invalid then
        request = createPlexRequest(m.server, m.requestItem.GetAllItemsPath())
        context = request.CreateRequestContext("preplay_context", createCallable("OnContextResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

sub preplayOnFwdButton(item=invalid as dynamic)
    if m.curIndex = invalid or m.items = invalid then return
    m.curIndex = m.curIndex + 1
    if m.curIndex > m.items.Count()-1 then
        m.curIndex = 0
    end if
    m.requestItem = m.items[m.curIndex]

    if m.requestItem <> invalid then
        m.Refresh()
    end if
end sub

sub preplayOnRevButton(item=invalid as dynamic)
    if m.curIndex = invalid or m.items = invalid then return
    m.curIndex = m.curIndex - 1
    if m.curIndex < 0 then
        m.curIndex = m.items.Count() - 1
    end if
    m.requestItem = m.items[m.curIndex]

    if m.requestItem <> invalid then
        m.Refresh()
    end if
end sub

sub preplaySetRefreshCache(key as string, component as object)
    if m[key] = invalid then return
    m[key].region = m.refreshCache[key]
    m.refreshCache[key] = invalid
end sub
