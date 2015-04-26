function AlbumScreen() as object
    if m.AlbumScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PreplayScreen())

        obj.screenName = "Album Screen"

        ' Methods
        obj.Init = albumInit
        obj.Show = albumShow
        obj.ResetInit = albumResetInit
        obj.Refresh = albumRefresh
        obj.OnChildResponse = albumOnChildResponse
        obj.GetComponents = albumGetComponents
        obj.HandleCommand = albumHandleCommand
        obj.GetButtons = albumGetButtons
        obj.OnFocusIn = albumOnFocusIn
        obj.SetNowPlaying = albumSetNowPlaying
        obj.GetTrackComponent = albumGetTrackComponent
        obj.ToggleSummary = albumToggleSummary

        ' Listener Methods
        obj.OnPlay = albumOnPlay
        obj.OnStop = albumOnStop
        obj.OnPause = albumOnPause
        obj.OnResume = albumOnResume

        ' Remote button methods
        obj.OnPlayButton = albumOnPlayButton

        m.AlbumScreen = obj
    end if

    return m.AlbumScreen
end function

function createAlbumScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(AlbumScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub albumInit()
    ApplyFunc(PreplayScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(32),
        trackStatus: FontRegistry().GetIconFont(20),
        trackActions: FontRegistry().GetIconFont(18)
    }

    m.ResetInit(m.path)

    ' Set up audio player listeners
    m.DisableListeners()
    m.player = AudioPlayer()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
end sub

sub albumResetInit(path=invalid as dynamic)
    m.server = m.requestItem.GetServer()

    ' path override (optional)
    if path <> invalid then
        m.path = path
        m.childrenPath = m.path + "/children"
    else
        m.path = m.requestItem.GetItemPath()
        m.childrenPath = m.requestItem.GetAbsolutePath("key")
    end if

    m.childrenPath = m.childrenPath + "?includeRelated=1&excludeAllLeaves=1"
    m.parentPath = m.path + "?includeRelated=1&includeRelatedCount=0&includeExtras=1"

    m.requestContext = invalid
    m.childRequestContext = invalid
    m.children = CreateObject("roList")
    m.summaryVisible = false
end sub

sub albumShow()
    if not Application().IsActiveScreen(m) then return

    requests = CreateObject("roList")
    if m.requestContext = invalid then
        request = createPlexRequest(m.server, m.parentPath)
        m.requestContext = request.CreateRequestContext("preplay_item", createCallable("OnResponse", m))
        requests.Push({request: request, context: m.requestContext})
    end if

    if m.childRequestContext = invalid then
        request = createPlexRequest(m.server, m.childrenPath)
        m.childRequestContext = request.CreateRequestContext("preplay_item", createCallable("OnChildResponse", m))
        requests.Push({request: request, context: m.childRequestContext})
    end if

    for each request in requests
        Application().StartRequest(request.request, request.context)
    end for

    if m.requestContext.response <> invalid and m.childRequestContext.response <> invalid then
        if m.item <> invalid then
            ApplyFunc(ComponentsScreen().Show, m)
            m.ToggleSummary()
        else
            dialog = createDialog("Unable to load", "Sorry, we couldn't load the requested item.", m)
            dialog.AddButton("OK", "close_screen")
            dialog.HandleButton = preplayDialogHandleButton
            dialog.Show()
        end if
    end if
end sub

sub albumGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' set the duration, unless the PMS supplies it.
    if m.item.Get("duration") = invalid and m.duration > 0 then
        m.item.Set("duration", m.duration.toStr())
    end if

    ' *** Background Artwork *** '
    m.background = createBackgroundImage(m.item)
    m.background.thumbAttr = ["art", "parentThumb", "thumb"]
    m.components.Push(m.background)
    m.SetRefreshCache("background", m.background)

    ' *** HEADER *** '
    header = createHeader(m)
    m.components.Push(header)

    yOffset = 140
    xOffset = 50
    parentSpacing = 30
    parentHeight = 434
    parentWidth = parentHeight
    childSpacing = 10

    ' *** Buttons *** '
    vbButtons = createVBox(false, false, false, childSpacing)
    vbButtons.SetFrame(xOffset, yOffset, 100, 720 - yOffset)
    vbButtons.ignoreFirstLast = true
    for each comp in m.GetButtons()
        vbButtons.AddComponent(comp)
    end for
    m.components.Push(vbButtons)
    xOffset = xOffset + parentSpacing + vbButtons.width

    ' *** Artist title ***
    lineHeight = FontRegistry().NORMAL.GetOneLineHeight()
    artistTitle = createLabel(ucase(m.item.Get("parentTitle")), FontRegistry().NORMAL)
    artistTitle.SetFrame(xOffset, yOffset - childSpacing - (lineHeight*2), parentWidth, lineHeight)
    m.components.push(artistTitle)

    ' *** Album title ***
    albumTitle = createLabel(ucase(m.item.Get("title")), FontRegistry().NORMAL)
    albumTitle.SetFrame(xOffset, yOffset - childSpacing - lineHeight, parentWidth, lineHeight)
    albumTitle.SetColor(Colors().TextDim)
    m.components.push(albumTitle)

    ' *** Album image ***
    m.album = createImage(m.item, parentWidth, parentHeight)
    m.album.fade = true
    m.album.cache = true
    m.album.SetOrientation(m.album.ORIENTATION_SQUARE)
    m.album.SetFrame(xOffset, yOffset, parentWidth, parentHeight)
    m.components.push(m.album)
    m.SetRefreshCache("album", m.album)

    ' xOffset share with Summary and Track list
    xOffset = xOffset + parentSpacing + parentWidth
    width = 1230 - xOffset

    ' *** REVIEW: title and summary *** '
    m.summaryTitle = createLabel("REVIEW", FontRegistry().NORMAL)
    height = m.summaryTitle.font.GetOneLineHeight()
    m.summaryTitle.SetFrame(xOffset, yOffset - childSpacing - height, m.summaryTitle.GetPreferredWidth(), height)
    m.summaryTitle.zOrderInit = -1
    m.components.push(m.summaryTitle)

    m.summary = createTextArea(m.item.Get("summary", ""), FontRegistry().NORMAL, 0)
    m.summary.SetFrame(xOffset, yOffset, width, parentHeight)
    m.summary.SetColor(Colors().Text, Colors().OverlayDark, Colors().OverlayMed)
    m.summary.SetPadding(10, 10, 10, 15)
    m.summary.halign = m.summary.JUSTIFY_LEFT
    m.summary.zOrderInit = -1
    m.components.push(m.summary)

    ' Create a component for our track actions now in order to reserve space
    ' for it. We'll add the buttons later.
    m.trackActions = createButtonGrid(1, 1)

    ' *** Track List Area *** '
    padding = 20
    trackPrefs = {
        background: Colors().GetAlpha(&hffffffff, 10),
        width: 1230 - xOffset - padding - m.trackActions.GetPreferredWidth(),
        height: 50,
        fixed: false,
        focusBG: true,
        zOrder: 2,
        hasTrackActions: true
    }

    m.trackBG = createBlock(trackPrefs.background)
    m.trackBG.zOrder = trackPrefs.zOrder
    m.trackBG.setFrame(xOffset, header.GetPreferredHeight(), 1280 - xOffset, 720 - header.GetPreferredHeight())
    m.components.Push(m.trackBG)

    ' TODO(rob): HD/SD note. We need to set some contstants for safe viewable areas of the
    ' screen. We have arbitrarily picked 50px. e.g. x=50, w=1230, so we'll assume the same
    ' for y and height, e.g. y=50, h=670.

    trackListY = header.GetPreferredHeight() + CompositorScreen().focusPixels
    trackListH = AppSettings().GetHeight() - trackListY
    m.trackList = createVBox(false, false, false, 0)
    m.trackList.SetFrame(xOffset + padding, trackListY, trackPrefs.width + m.trackActions.GetPreferredWidth(), trackListH - padding)
    m.trackList.SetScrollable(trackListH / 2, true, true, invalid)
    m.trackList.stopShiftIfInView = true
    m.trackList.scrollOverflow = true

    ' *** Tracks *** '
    trackCount = m.children.Count()
    ' create a shared region for the separator
    sepRegion = CreateRegion(trackPrefs.width, 1, Colors().Separator)
    for index = 0 to trackCount - 1
        item = m.children[index]
        track = createTrack(item, FontRegistry().NORMAL, FontRegistry().SMALL, m.customFonts.trackStatus, trackCount)
        track.Append(trackPrefs)
        track.DisableNonParentExit("down")
        track.plexObject = item
        track.trackIndex = index
        track.SetFocusable("play")
        m.trackList.AddComponent(track)
        if m.focusedItem = invalid then m.focusedItem = track

        if index < trackCount - 1 then
            track.AddSeparator(sepRegion)
        end if
    end for
    m.components.Push(m.trackList)

    ' *** Track actions *** '
    actions = createObject("roList")
    moreOptions = createObject("roList")

    moreOptions.Push({text: "Play next", command: "play_next"})
    moreOptions.Push({text: "Add to queue", command: "add_to_queue"})
    moreOptions.Push({text: "Play music video", command: "play_music_video", visibleCallable: createCallable(ItemHasMusicVideo, invalid)})
    moreOptions.Push({text: "Plex Mix", command: "play_plex_mix", visibleCallable: createCallable(ItemHasPlexMix, invalid)})

    actions.Push({text: Glyphs().ELLIPSIS, type: "dropDown", position: "down", options: moreOptions, font: m.customFonts.trackActions, zorderInit: -1})

    buttonFields = {trackAction: true}
    m.trackActions.AddButtons(actions, buttonFields, m)
    m.components.Push(m.trackActions)

    ' Set the focus to the current AudioPlayer track, if applicable.
    component = m.GetTrackComponent(m.player.GetCurrentItem())
    if component <> invalid then
        m.focusedItem = component
        if m.player.isPlaying then
            m.OnPlay(m.player, component.plexObject)
        else if m.player.isPaused then
            m.OnPause(m.player, component.plexObject)
        end if
    end if

    ' Background of focused item.
    ' note: we cannot just change the background of the track composite due
    ' to the aliasing issues.
    m.focusBG = createBlock(Colors().GetAlpha("Black", 60))
    m.focusBG.setFrame(0, 0, trackPrefs.width, trackPrefs.height)
    m.focusBG.fixed = false
    m.focusBG.zOrderInit = -1
    m.components.Push(m.focusBG)

    ' Static description box
    title = JoinArray([m.item.Get("year", ""), m.item.GetChildCountString()], " / ")
    descBox = createStaticDescriptionBox(title, m.item.GetDuration())
    descBox.setFrame(50, 630, 1280-50, 100)
    m.components.Push(descBox)
end sub

sub albumOnChildResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response
    context.items = response.items
    children = response.items

    ' duration calculation until PMS supplies it.
    m.duration = 0
    m.children.Clear()
    if context.items.count() > 0 then
        for each item in context.items
            m.duration = m.duration + item.GetInt("duration")
            m.children.push(item)
        end for
    end if

    m.Show()
end sub

function albumGetButtons() as object
    components = createObject("roList")

    buttonHeight = 50
    optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: buttonHeight
        padding: { right: 10, left: 10, top: 0, bottom: 0 }
        font: FontRegistry().NORMAL,
    }

    buttons = createObject("roList")
    buttons.push({text: Glyphs().PLAY, command: "play"})
    buttons.push({text: Glyphs().SHUFFLE, command: "shuffle"})
    if m.item.Get("summary", "") <> "" then
        buttons.push({text: Glyphs().INFO, command: "summary"})
    end if

    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        components.push(btn)
    end for

    ' more/pivots drop down
    btn = createDropDownButton(Glyphs().MORE, m.customFonts.glyphs, m)
    btn.SetDropDownPosition("right")
    components.push(btn)

    ' manual pivots and commands
    manualPivotsAndCommands = [
        {command: "play_next", text: "Play Next", closeOverlay: true},
        {command: "add_to_queue", text: "Add to Queue", closeOverlay: true},
        {command: "go_to_artist", text: "Go to Artist"},
    ]
    for each pivot in manualPivotsAndCommands
        option = {}
        option.Append(pivot)
        option.Append(optionPrefs)
        btn.options.push(option)
    end for

    if m.item.relatedItems <> invalid then
        for each item in m.item.relatedItems
            option = {
                text: item.GetSingleLineTitle(),
                command: "show_grid",
                plexObject: item,
            }
            option.Append(optionPrefs)
            btn.options.push(option)
        end for
    end if

    for each component in components
        component.SetColor(Colors().Text, Colors().Button)
        component.width = 100
        component.height = buttonHeight
        component.DisableNonParentExit("down")
        if m.focusedItem = invalid then m.focusedItem = component
    end for

    return components
end function

function albumHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    ' If it was a track action, make sure it has the last focused track set as its item
    if item <> invalid and item.trackAction = true then
        item.plexObject = m.focusedTrack.plexObject
        m.overlayScreen.Peek().Close()
    end if

    if command = "play" or command = "shuffle" then
        ' start content from requested index, or from the beginning.
        if item <> invalid then
            trackIndex = validint(item.trackIndex)
        else
            trackIndex = 0
        end if

        plexItem = m.children[trackIndex]
        if plexItem <> invalid then
            options = createPlayOptions()
            options.shuffle = (command = "shuffle")
            pq = createPlayQueueForItem(plexItem, options)
            m.player.SetPlayQueue(pq, true)
        end if
    else if command = "summary" then
        m.summaryVisible = not m.summaryVisible = true
        m.ToggleSummary()
    else if command = "go_to_artist" then
        Application().PushScreen(createArtistScreen(m.item, m.item.Get("parentKey")))
    else
        return ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
    end if

    return handled
end function

sub albumOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])

    ' Ignore further processing if we are focused on a track action
    if toFocus <> invalid and toFocus.parent <> invalid and toFocus.parent.ClassName = "ButtonGrid" then return

    ' Focus background (anti-alias workaround)
    if toFocus <> invalid and toFocus.focusBG = true then
        m.focusBG.sprite.MoveTo(toFocus.x, toFocus.y)
        m.focusBG.sprite.SetZ(1)
    else
        m.focusBG.sprite.SetZ(-1)
    end if

    ' Track Actions visibility
    if toFocus <> invalid and toFocus.hasTrackActions = true then
        rect = computeRect(toFocus)
        m.trackActions.SetPosition(rect.right + 1, rect.up + int((rect.height - m.trackActions.GetPreferredHeight()) / 2))
        m.trackActions.SetVisible(true)
        m.focusedTrack = toFocus

        ' Toggle some of our track actions based on the current track
        m.trackActions.SetPlexObject(toFocus.plexObject)
    else
        m.trackActions.SetVisible(false)
    end if
end sub

sub albumSetNowPlaying(plexObject as object, status=true as boolean)
    if not Application().IsActiveScreen(m) then return

    if m.paused <> invalid and m.paused.plexObject.Get("key") <> plexObject.Get("key") then
        m.paused.SetPlaying(false)
        m.paused = invalid
    end if

    if m.playing <> invalid and m.playing.plexObject.Get("key") <> plexObject.Get("key") then
        m.playing.SetPlaying(false)
        m.playing = invalid
    end if

    component = m.GetTrackComponent(plexObject)
    if component <> invalid then
        component.SetPlaying(status)
        m.playing = iif(status, component, invalid)
    end if
end sub

sub albumOnPlay(player as object, item as object)
    m.SetNowPlaying(item, true)
end sub

sub albumOnStop(player as object, item as object)
    m.SetNowPlaying(item, false)
end sub

sub albumOnPause(player as object, item as object)
    m.paused = m.GetTrackComponent(item)
    m.SetNowPlaying(item, false)
end sub

sub albumOnResume(player as object, item as object)
    m.paused = invalid
    m.SetNowPlaying(item, true)
end sub

function albumGetTrackComponent(plexObject as dynamic) as dynamic
    if plexObject = invalid or m.item = invalid then return invalid

    ' ignore checking for child if parent is different
    if m.item.Get("ratingKey") <> plexObject.Get("parentRatingKey") then return invalid

    ' locate the component by the plexObect and return
    for each track in m.trackList.components
        if track.plexObject <> invalid and plexObject.Get("key") = track.plexObject.Get("key") then
            return track
        end if
    end for

    return invalid
end function

sub albumOnPlayButton(item=invalid as dynamic)
    m.HandleCommand("play", item)
end sub

sub albumToggleSummary()
    Debug("toggle summary: summaryVisible=" + tostr(m.summaryVisible))

    ' toggle summary
    m.summaryTitle.SetVisible(m.summaryVisible)
    m.summary.SetVisible(m.summaryVisible)

    ' toggle track list
    visible = m.summaryVisible = false
    m.trackBG.SetVisible(visible)
    for each component in m.trackList.components
        component.ToggleFocusable(visible)
        if component.IsOnScreen() then component.SetVisible(visible)
    end for

    m.RefreshAvailableComponents()

    ' invalidate focus sibling and last focus item
    m.focusedItem.SetFocusSibling("right", invalid)
    m.lastFocusedItem = invalid

    m.screen.DrawAll()
end sub

sub albumRefresh(request=invalid as dynamic, response=invalid as dynamic, context=invalid as dynamic)
    if m.itemPath <> invalid then
        m.ResetInit(m.itemPath)
        ApplyFunc(PreplayScreen().Refresh, m)
    end if
end sub
