function PlaylistScreen() as object
    if m.PlaylistScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PreplayScreen())

        obj.screenName = "Playlist Screen"

        ' Methods
        obj.Init = playlistInit
        obj.InitItem = playlistInitItem
        obj.Show = playlistShow
        obj.ResetInit = playlistResetInit
        obj.Refresh = playlistRefresh
        obj.OnChildResponse = playlistOnChildResponse
        obj.GetComponents = playlistGetComponents
        obj.HandleCommand = playlistHandleCommand
        obj.GetButtons = playlistGetButtons
        obj.OnFocusIn = playlistOnFocusIn
        obj.GetListComponent = playlistGetListComponent
        obj.SetNowPlaying = playlistSetNowPlaying

        ' Listener Methods
        obj.OnPlay = playlistOnPlay
        obj.OnStop = playlistOnStop
        obj.OnPause = playlistOnPause
        obj.OnResume = playlistOnResume

        ' Remote button methods
        obj.OnPlayButton = playlistOnPlayButton

        m.PlaylistScreen = obj
    end if

    return m.PlaylistScreen
end function

function createPlaylistScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlaylistScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub playlistInit()
    ApplyFunc(PreplayScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(32)
        trackStatus: FontRegistry().GetIconFont(20)
    }

    m.ResetInit(m.path)
end sub

sub playlistResetInit(path=invalid as dynamic)
    m.DisableListeners(true)
    m.server = m.requestItem.GetServer()

    ' path override (optional)
    if path <> invalid then
        m.path = path
        m.childrenPath = m.path + "/items"
    else
        m.path = m.requestItem.GetItemPath()
        m.childrenPath = m.requestItem.GetAbsolutePath("key")
    end if

    m.childrenPath = m.childrenPath + "?excludeAllLeaves=1"
    m.parentPath = m.path + "?includeRelated=1&includeRelatedCount=0&includeExtras=1"

    m.requestContext = invalid
    m.childRequestContext = invalid
    m.children = CreateObject("roList")
end sub

sub playlistShow()
    if not Application().IsActiveScreen(m) then return

    requests = CreateObject("roList")
    if m.requestContext = invalid then
        request = createPlexRequest(m.server, m.parentPath)
        m.requestContext = request.CreateRequestContext("preplay_item", createCallable("OnResponse", m))
        requests.Push({request: request, context: m.requestContext})
    end if

    if m.childRequestContext = invalid then
        request = createPlexRequest(m.server, m.childrenPath)
        ' TODO(rob): Remove this limit, which requires lazy loading chunks (grid screen)
        request.AddHeader("X-Plex-Container-Start", "0")
        request.AddHeader("X-Plex-Container-Size", "500")
        m.childRequestContext = request.CreateRequestContext("preplay_item", createCallable("OnChildResponse", m))
        requests.Push({request: request, context: m.childRequestContext})
    end if

    for each request in requests
        Application().StartRequest(request.request, request.context)
    end for

    if m.requestContext.response <> invalid and m.childRequestContext.response <> invalid then
        if m.item <> invalid then
            m.InitItem()

            ApplyFunc(ComponentsScreen().Show, m)

            ' TODO(rob): This works just like the other preplay screens, but do we want
            ' the << >> buttons to scroll quicker through the vertical list? We might
            ' just want to keep this consistent, and it may be irrelevant once we have
            ' support for scrolling acceleration.

            ' Load context for << >> navigation
            m.LoadContext()
        else
            dialog = createDialog("Unable to load", "Sorry, we couldn't load the requested playlist.", m)
            dialog.AddButton("OK", "close_screen")
            dialog.HandleButton = preplayDialogHandleButton
            dialog.Show()
        end if
    end if
end sub

sub playlistOnChildResponse(request as object, response as object, context as object)
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

sub playlistGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' set the duration, unless the PMS supplies it.
    if m.item.Get("duration") = invalid and m.duration > 0 then
        m.item.Set("duration", m.duration.toStr())
    end if

    ' *** Background Artwork *** '
    m.background = createBackgroundImage(m.item)
    m.background.thumbAttr = ["composite", "art", "parentThumb", "thumb"]
    m.components.Push(m.background)
    m.SetRefreshCache("background", m.background)

    ' *** HEADER *** '
    m.header = createHeader(m)
    m.components.Push(m.header)

    ' *** Buttons *** '
    vbButtons = createVBox(false, false, false, m.specs.childSpacing)
    vbButtons.SetFrame(m.specs.xOffset, m.specs.yOffset, 100, 720 - m.specs.yOffset)
    vbButtons.ignoreFirstLast = true
    for each comp in m.GetButtons()
        vbButtons.AddComponent(comp)
    end for
    m.components.Push(vbButtons)
    m.specs.xOffset = m.specs.xOffset + m.specs.parentSpacing + vbButtons.width

    ' *** playlist title ***
    lineHeight = FontRegistry().NORMAL.GetOneLineHeight()
    playlistTitle = createLabel("PLAYLISTS / " + ucase(m.item.Get("title")), FontRegistry().NORMAL)
    playlistTitle.SetFrame(m.specs.xOffset, m.specs.yOffset - m.specs.childSpacing - lineHeight, m.specs.parentWidth, lineHeight)
    m.components.push(playlistTitle)

    ' *** playlist image ***
    m.image = createImage(m.item, m.specs.parentWidth, m.specs.parentHeight)
    m.image.fade = true
    m.image.cache = true
    m.image.SetOrientation(m.image.ORIENTATION_SQUARE)
    m.image.SetFrame(m.specs.xOffset, m.specs.yOffset, m.specs.parentWidth, m.specs.parentHeight)
    m.components.push(m.image)
    m.SetRefreshCache("image", m.image)

    ' xOffset share with Summary and Track list
    m.specs.xOffset = m.specs.xOffset + m.specs.parentSpacing + m.specs.parentWidth
    m.trackBG = createBlock(m.listPrefs.background)
    m.trackBG.zOrder = m.listPrefs.zOrder
    m.trackBG.setFrame(m.specs.xOffset, m.header.GetPreferredHeight(), 1280 - m.specs.xOffset, 720 - m.header.GetPreferredHeight())
    m.components.Push(m.trackBG)

    ' TODO(rob): HD/SD note. We need to set some contstants for safe viewable areas of the
    ' screen. We have arbitrarily picked 50px. e.g. x=50, w=1230, so we'll assume the same
    ' for y and height, e.g. y=50, h=670.

    itemListY = m.header.GetPreferredHeight() + m.specs.childSpacing
    itemListH = AppSettings().GetHeight() - itemListY
    m.itemList = createVBox(false, false, false, 0)
    m.itemList.SetFrame(m.specs.xOffset + m.specs.parentSpacing, itemListY, m.listPrefs.width, itemListH)
    m.itemList.SetScrollable(AppSettings().GetHeight() / 2, true, true, invalid)
    m.itemList.stopShiftIfInView = true
    m.itemList.scrollOverflow = true

    ' *** Playlist Items *** '
    trackCount = m.children.Count()
    ' create a shared region for the separator
    sepRegion = CreateRegion(m.listPrefs.width, 1, Colors().OverlayDark)
    for index = 0 to trackCount - 1
        item = m.children[index]
        track = createTrack(item, FontRegistry().NORMAL, FontRegistry().NORMAL, m.customFonts.trackStatus, trackCount, true)
        track.Append(m.listPrefs)
        track.plexObject = item
        track.trackIndex = index
        track.SetIndex(index + 1)
        track.SetFocusable("play")
        m.itemList.AddComponent(track)
        if m.focusedItem = invalid then m.focusedItem = track

        if index < trackCount - 1 then
            sep = createBlock(Colors().OverlayDark)
            sep.Append(m.listPrefs)
            sep.region = sepRegion
            sep.height = 1
            m.itemList.AddComponent(sep)
        end if
    end for
    m.components.Push(m.itemList)

    ' Set the focus to the current AudioPlayer track, if applicable.
    component = m.GetListComponent(m.player.GetCurrentItem())
    if component <> invalid then
        m.focusedItem = component
        if m.player.isPlaying then
            m.OnPlay(m.player, component.plexObject)
        else if m.player.isPaused then
            m.OnPause(m.player, component.plexObject)
        end if
    end if

    ' Background of focused item. We cannot just change the background
    ' of the track composite due to the aliasing issues.
    m.focusBG = createBlock(Colors().GetAlpha("Black", 60))
    m.focusBG.setFrame(0, 0, m.listPrefs.width, m.listPrefs.height)
    m.focusBG.fixed = false
    m.focusBG.zOrderInit = -1
    m.components.Push(m.focusBG)

    ' Static description box
    descBox = createStaticDescriptionBox(m.item.GetChildCountString(), m.item.GetDuration())
    descBox.setFrame(50, 630, 1280-50, 100)
    m.components.Push(descBox)
end sub

function playlistGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")
    buttons.push({text: Glyphs().PLAY, command: "play"})
    buttons.push({text: Glyphs().SHUFFLE, command: "shuffle"})

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
        font: FontRegistry().NORMAL,
    }

    btn = createDropDownButton(Glyphs().MORE, m.customFonts.glyphs, buttonHeight * 5, m)
    btn.SetDropDownPosition("right")
    btn.SetColor(Colors().Text, Colors().Button)
    btn.width = 100
    btn.height = buttonHeight
    if m.focusedItem = invalid then m.focusedItem = btn

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

    if btn.options.Count() > 0 then
        components.push(btn)
    end if

    return components
end function

function playlistHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "play" or command = "shuffle" then
        ' start content from requested index, or from the beginning.

        options = createPlayOptions()
        options.shuffle = (command = "shuffle")

        if item <> invalid and item.plexObject <> invalid then
            options.key = item.plexObject.Get("key")
        end if

        pq = createPlayQueueForItem(m.item, options)
        m.player.SetPlayQueue(pq, true)
    else
        return ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
    end if

    return handled
end function

sub playlistOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])

    if toFocus <> invalid and toFocus.focusBG = true then
        m.focusBG.sprite.MoveTo(toFocus.x, toFocus.y)
        m.focusBG.sprite.SetZ(1)
    else
        m.focusBG.sprite.SetZ(-1)
    end if
end sub

sub playlistOnPlayButton(item=invalid as dynamic)
    m.HandleCommand("play", item)
end sub

sub playlistRefresh(request=invalid as dynamic, response=invalid as dynamic, context=invalid as dynamic)
    if m.itemPath <> invalid then
        m.ResetInit(m.itemPath)
        ApplyFunc(PreplayScreen().Refresh, m)
        m.refocus = invalid
    end if
end sub

sub playlistInitItem() as object
    ' These may change per item and since we use the same screen when context
    ' switching (REV/REW), we'll have to modify them after we have set m.item.

    m.specs = {
        yOffset: 125, ' TODO(rob): this should be 148?, but that means our header height is wrong everywhere.
        xOffset: 50,  ' TODO(rob): apprently our safe offsets are +/- 40 (not 50)
        parentSpacing: 40,
        parentHeight: 283,
        parentWidth: 283,
        childSpacing: 10,
    }

    m.listPrefs = {
        background: Colors().GetAlpha(&hffffffff, 10),
        fixed: false,
        focusBG: true,
        zOrder: 2
    }

    if m.item.Get("playlistType") = "audio" then
        m.player = AudioPlayer()

        m.listPrefs.width = 635
        m.listPrefs.height = 73

        m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
        m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
        m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
        m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    else
        m.player = VideoPlayer()

        m.listPrefs.width = 677
        m.listPrefs.height = 120
    end if
end sub

sub playlistOnPlay(player as object, item as object)
    m.SetNowPlaying(item, true)
end sub

sub playlistOnStop(player as object, item as object)
    m.SetNowPlaying(item, false)
end sub

sub playlistOnPause(player as object, item as object)
    m.paused = m.GetListComponent(item)
    m.SetNowPlaying(item, false)
end sub

sub playlistOnResume(player as object, item as object)
    m.paused = invalid
    m.SetNowPlaying(item, true)
end sub

sub playlistSetNowPlaying(plexObject as object, status=true as boolean)
    if not Application().IsActiveScreen(m) then return

    if m.paused <> invalid and m.paused.plexObject.Get("key") <> plexObject.Get("key") then
        m.paused.SetPlaying(false)
        m.paused = invalid
    end if

    if m.playing <> invalid and m.playing.plexObject.Get("key") <> plexObject.Get("key") then
        m.playing.SetPlaying(false)
        m.playing = invalid
    end if

    component = m.GetListComponent(plexObject)
    if component <> invalid then
        component.SetPlaying(status)
        m.playing = iif(status, component, invalid)
    end if
end sub

function playlistGetListComponent(plexObject as dynamic) as dynamic
    if plexObject = invalid or m.item = invalid then return invalid

    ' locate the component by the plexObect and return
    for each track in m.itemList.components
        if track.plexObject <> invalid and plexObject.Get("key") = track.plexObject.Get("key") then
            return track
        end if
    end for

    return invalid
end function
