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
        obj.OnKeyPress = albumOnKeyPress

        ' Now Playing timer
        obj.OnNowPlayingTimer = albumOnNowPlayingTimer

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

sub albumShow()
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

            ' Create a timer for polling to see if the code has been linked.
            m.NowPlayingTimer = createTimer("poll")
            m.NowPlayingTimer.SetDuration(1000, true)
            Application().AddTimer(m.NowPlayingTimer, createCallable("OnNowPlayingTimer", m))
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

    yOffset = 125
    xOffset = 50
    parentSpacing = 30
    parentHeight = 434
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

    ' *** album title and image ***
    albumTitle = createLabel(ucase(m.item.GetLongerTitle(" / ")), FontRegistry().Font16)
    albumHeight = albumTitle.font.GetOneLineHeight()
    albumTitle.fixed = false
    albumTitle.SetFrame(xOffset, yOffset - childSpacing - albumHeight, albumTitle.GetPreferredWidth(), albumHeight)
    m.components.push(albumTitle)

    album = createImage(m.item, parentHeight, parentHeight)
    album.fixed = false
    album.SetFrame(xOffset, yOffset, parentHeight, parentHeight)
    m.components.push(album)

    ' xOffset share with Summary and Track list
    xOffset = xOffset + parentSpacing + parentHeight

    ' *** REVIEW: title and summary *** '
    m.summaryTitle = createLabel("REVIEW", FontRegistry().Font16)
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
    m.trackBG.setFrame(xOffset, header.GetPreferredHeight(), 1280 - xOffset, 720)
    m.components.Push(m.trackBG)

    m.trackList = createVBox(false, false, false, 0)
    m.trackList.SetScrollable(720 + trackPrefs.height, 720 / 2, true, true, invalid)
    m.trackList.scrollOverflow = true
    m.trackList.SetFrame(xOffset + padding, header.GetPreferredHeight() + padding, trackPrefs.width, 720)

    ' *** Tracks *** '
    playingItem = AudioPlayer().GetItemPlaying()

    trackCount = m.children.Count()
    for index = 0 to trackCount - 1
        item = m.children[index]
        track = createTrack(item, FontRegistry().Font16, FontRegistry().GetIconFont(16), trackCount)
        track.Append(trackPrefs)
        track.plexObject = item
        track.trackIndex = index
        track.SetFocusable("play")
        if m.focusedItem = invalid then m.focusedItem = track
        m.trackList.AddComponent(track)

        if playingItem <> invalid and playingItem.Get("key") = track.plexObject.Get("key") then
            track.SetPlaying(true)
            m.focusedItem = track
        end if

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

    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = 50
        btn.fixed = false
        btn.disallowExit = { down: true }
        if m.focusedItem = invalid then m.focusedItem = btn
        components.push(btn)
    end for

    ' more/pivots drop down
    optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: btn.height
        padding: { right: 10, left: 10, top: 0, bottom: 0 }
        font: FontRegistry().font16,
    }

    btn = createDropDown(Glyphs().MORE, m.customFonts.glyphs, int(720 * .80), m)
    btn.SetDropDownPosition("right")
    btn.SetColor(Colors().Text, Colors().Button)
    btn.width = 100
    btn.height = 47
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

    if command = "play" then
        ' TODO(rob): hook into the audio player (logic will obviously change)

        if m.playing <> invalid then m.playing.SetPlaying(false, true)

        ' start content from requested index, or at the beginning.
        trackContext = m.children
        if item.trackIndex <> invalid then
            component = item
            trackIndex = item.trackIndex
        else
            trackIndex = 0
            component = m.trackList.components[0]
            m.OnFocus(component)
        end if
        m.playing = component

        if AudioPlayer().isPlaying and AudioPlayer().curIndex = trackIndex then
            AudioPlayer().Pause()
        else if AudioPlayer().isPaused and AudioPlayer().curIndex = trackIndex
            AudioPlayer().Resume()
            component.SetPlaying(true, true)
        else
            AudioPlayer().SetContext(trackContext, trackIndex, true)
            component.SetPlaying(true, true)
        end if
    else if command = "summary" then
        m.summaryVisible = not m.summaryVisible = true
        Debug("toggle summary: summaryVisible=" + tostr(m.summaryVisible))

        ' toggle summary
        m.summaryTitle.SetVisible(m.summaryVisible)
        m.summary.SetVisible(m.summaryVisible)

        ' toggle track list
        visible = m.summaryVisible = false
        m.trackBG.SetVisible(visible)
        for each component in m.trackList.components
            component.focusable = visible
            if component.IsOnScreen() then component.SetVisible(visible)
        end for

        ' invalidate focus sibling and last focus item
        m.focusedItem.SetFocusSibling("right", invalid)
        m.lastFocusedItem = invalid

        m.screen.DrawAll()
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

sub albumOnNowPlayingTimer(timer as dynamic)
    if not Application().IsActiveScreen(m) or not AudioPlayer().isPlaying then return

    playingItem = AudioPlayer().GetItemPlaying()
    playingParentKey = playingItem.Get("parentRatingKey")

    ' failsafe to set the now playing object. this should be set on creation now
    ' when a music item is already playing.
    if m.playing = invalid then
        m.playing = m.trackList.components[0]
    end if

    screenItem = m.playing.plexObject
    screenParentKey = screenItem.Get("parentRatingKey")

    ' TODO(rob): update the mini player? The mini player will probably need to be part
    ' of the header, as all screens will probably show the mini player..

    ' ignore updating playing item if the screens context <> playing context (browsing)
    if playingParentKey <> screenParentKey then return

    ' update the UI with the track change
    if playingItem.Get("key") <> screenItem.Get("key") then
        for each track in m.trackList.components
            if track.plexObject <> invalid and playingItem.Get("key") = track.plexObject.Get("key") then
                if m.playing <> invalid then m.playing.SetPlaying(false, true)
                track.SetPlaying(true, true)
                m.playing = track
                exit for
            end if
        end for
    end if
end sub

sub albumOnKeyPress(keyCode as integer, repeat as boolean)
    if keyCode = m.kp_FWD or keyCode = m.kp_REV then
        delta = iif(keyCode = m.kp_FWD, 1, -1)
        AudioPlayer().Seek(10000 * delta, true)
    else
        ApplyFunc(ComponentsScreen().OnKeyPress, m, [keyCode, repeat])
    end if
end sub
