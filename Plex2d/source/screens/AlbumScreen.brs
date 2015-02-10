function AlbumScreen() as object
    if m.AlbumScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PreplayScreen())

        obj.screenName = "Album Screen"

        ' Methods
        obj.Init = albumInit
        obj.Show = albumShow
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
        obj.OnFwdButton = albumOnFwdButton
        obj.OnRevButton = albumOnRevButton

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
        glyphs: FontRegistry().GetIconFont(32)
        trackStatus: FontRegistry().GetIconFont(16)
    }

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
    m.summaryVisible = false

    ' Set up audio player listeners
    m.DisableListeners()
    m.player = AudioPlayer()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
end sub

sub albumShow()
    if not Application().IsActiveScreen(m) then return

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
    background = createImage(m.item, 1280, 720, { blur: 15, opacity: 60, background: Colors().ToHexString("Background") })
    background.zOrderInit = 0
    background.thumbAttr = ["art", "parentThumb", "thumb"]
    background.SetOrientation(background.ORIENTATION_LANDSCAPE)
    m.components.Push(background)

    background = createBlock(Colors().OverlayDark)
    background.zOrderInit = 0
    background.setFrame(0, 72, 1280, 720)
    m.components.Push(background)

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
    lineHeight = FontRegistry().Font16.GetOneLineHeight()
    artistTitle = createLabel(ucase(m.item.Get("parentTitle")), FontRegistry().Font16)
    artistTitle.SetFrame(xOffset, yOffset - childSpacing - (lineHeight*2), parentWidth, lineHeight)
    m.components.push(artistTitle)

    ' *** Album title ***
    albumTitle = createLabel(ucase(m.item.Get("title")), FontRegistry().Font16)
    albumTitle.SetFrame(xOffset, yOffset - childSpacing - lineHeight, parentWidth, lineHeight)
    albumTitle.SetColor(Colors().TextDim)
    m.components.push(albumTitle)

    ' *** Album image ***
    album = createImage(m.item, parentWidth, parentHeight)
    album.thumbAttr = ["thumb", "art", "parentThumb"]
    album.SetFrame(xOffset, yOffset, parentWidth, parentHeight)
    m.components.push(album)

    ' xOffset share with Summary and Track list
    xOffset = xOffset + parentSpacing + parentWidth
    width = 1230 - xOffset

    ' *** REVIEW: title and summary *** '
    m.summaryTitle = createLabel("REVIEW", FontRegistry().Font16)
    height = m.summaryTitle.font.GetOneLineHeight()
    m.summaryTitle.SetFrame(xOffset, yOffset - childSpacing - height, m.summaryTitle.GetPreferredWidth(), height)
    m.summaryTitle.zOrderInit = -1
    m.components.push(m.summaryTitle)

    m.summary = createTextArea(m.item.Get("summary", ""), FontRegistry().Font16, 0)
    m.summary.SetFrame(xOffset, yOffset, width, parentHeight)
    m.summary.SetColor(Colors().Text, Colors().OverlayDark, Colors().OverlayMed)
    m.summary.SetPadding(10, 10, 10, 15)
    m.summary.halign = m.summary.JUSTIFY_LEFT
    m.summary.zOrderInit = -1
    m.components.push(m.summary)

    ' *** Track List Area *** '
    padding = 20
    trackPrefs = {
        background: &hffffff10,
        width: 1230 - xOffset - padding,
        height: 50,
        fixed: false,
        focusBG: true,
        disallowExit: { down: true },
        zOrder: 2
    }

    m.trackBG = createBlock(trackPrefs.background)
    m.trackBG.zOrder = trackPrefs.zOrder
    m.trackBG.setFrame(xOffset, header.GetPreferredHeight(), 1280 - xOffset, 720 - header.GetPreferredHeight())
    m.components.Push(m.trackBG)

    ' TODO(rob): HD/SD note. We need to set some contstants for safe viewable areas of the
    ' screen. We have arbitrarily picked 50px. e.g. x=50, w=1230, so we'll assume the same
    ' for y and height, e.g. y=50, h=670.

    trackListY = header.GetPreferredHeight() + padding
    trackListH = 670 - trackListY
    m.trackList = createVBox(false, false, false, 0)
    m.trackList.SetFrame(xOffset + padding, trackListY, trackPrefs.width, trackListH)
    m.trackList.SetScrollable(trackListH / 2, true, true, invalid)
    m.trackList.stopShiftIfInView = true
    m.trackList.scrollOverflow = true

    ' *** Tracks *** '
    trackCount = m.children.Count()
    for index = 0 to trackCount - 1
        item = m.children[index]
        track = createTrack(item, FontRegistry().Font16, FontRegistry().Font12, m.customFonts.trackStatus, trackCount)
        track.Append(trackPrefs)
        track.plexObject = item
        track.trackIndex = index
        track.SetFocusable("play")
        m.trackList.AddComponent(track)
        if m.focusedItem = invalid then m.focusedItem = track

        if index < trackCount - 1 then
            sep = createBlock(Colors().OverlayDark)
            sep.height = 1
            sep.width = trackPrefs.width
            sep.fixed = trackPrefs.fixed
            sep.zOrder = trackPrefs.zOrder
            m.trackList.AddComponent(sep)
        end if
    end for
    m.components.Push(m.trackList)

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
    m.focusBG = createBlock(Colors().OverlayDark)
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

    if context.items.count() > 0 then
        for each item in context.items
            m.duration = m.duration + item.GetInt("duration")
            m.children.push(item)
        end for
    end if

    m.show()
end sub

function albumGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")
    buttons.push({text: Glyphs().PLAY, command: "play"})
    buttons.push({text: Glyphs().SHUFFLE, command: "shuffle"})
    if m.item.Get("summary", "") <> "" then
        buttons.push({text: Glyphs().INFO, command: "summary"})
    end if

    buttonHeight = 50
    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = buttonHeight
        btn.fixed = false
        btn.disallowExit = { down: true }
        if m.focusedItem = invalid then m.focusedItem = btn
        components.push(btn)
    end for

    ' more/pivots drop down
    optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: buttonHeight
        padding: { right: 10, left: 10, top: 0, bottom: 0 }
        font: FontRegistry().font16,
    }

    btn = createDropDown(Glyphs().MORE, m.customFonts.glyphs, buttonHeight * 5, m)
    btn.SetDropDownPosition("right")
    btn.SetColor(Colors().Text, Colors().Button)
    btn.width = 100
    btn.height = buttonHeight
    if m.focusedItem = invalid then m.focusedItem = btn

    ' manual pivots
    manualPivots = [
        {command: "go_to_artist", text: "Go to Artist"},
    ]
    for each pivot in manualPivots
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
    components.push(btn)

    return components
end function

function albumHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    ' TODO(schuyler): The shuffle support here is just a PoC. It's not clever
    ' about focusing the component that is actually chosen first.
    if command = "play" or command = "shuffle" then
        ' TODO(rob): create now playing screen

        ' start content from requested index, or from the beginning.
        trackContext = m.children
        if item <> invalid and item.trackIndex <> invalid then
            component = item
            trackIndex = item.trackIndex
            key = item.plexObject.Get("key")
        else
            trackIndex = 0
            key = invalid
            component = m.trackList.components[0]
        end if

        if component.Equals(m.paused) or component.Equals(m.playing) then
            Application().PushScreen(createNowPlayingScreen(m.player.GetCurrentItem()))
        else
            plexItem = trackContext[trackIndex]
            options = {}

            if command = "shuffle" then
                options["shuffle"] = "1"
            end if

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

    if toFocus <> invalid and toFocus.focusBG = true then
        m.focusBG.sprite.MoveTo(toFocus.x, toFocus.y)
        m.focusBG.sprite.SetZ(1)
    else
        m.focusBG.sprite.SetZ(-1)
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
    if m.player.IsActive() then
        m.player.OnPlayButton()
    else
        m.HandleCommand("play", item)
    end if
end sub

sub albumOnFwdButton(item=invalid as dynamic)
    m.player.OnFwdButton()
end sub

sub albumOnRevButton(item=invalid as dynamic)
    m.player.OnRevButton()
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

    ' invalidate focus sibling and last focus item
    m.focusedItem.SetFocusSibling("right", invalid)
    m.lastFocusedItem = invalid

    m.screen.DrawAll()
end sub
