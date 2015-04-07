function SeasonScreen() as object
    if m.SeasonScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContextListScreen())

        obj.screenName = "Episodes Screen"

        ' Methods
        obj.InitItem = seasonInitItem
        obj.GetComponents = seasonGetComponents
        obj.HandleCommand = seasonHandleCommand

        ' Methods overrides
        obj.LoadContext = seasonLoadContext

        m.SeasonScreen = obj
    end if

    return m.SeasonScreen
end function

function createSeasonScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SeasonScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub seasonGetComponents()
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

    ' *** season title ***
    lineHeight = FontRegistry().NORMAL.GetOneLineHeight()
    text = m.item.getlongertitle(" / ")
    seasonTitle = createLabel(text, FontRegistry().NORMAL)
    seasonTitle.SetFrame(m.specs.xOffset, m.specs.yOffset - m.specs.childSpacing - lineHeight, m.specs.parentWidth, lineHeight)
    m.components.Push(seasonTitle)

    ' *** season image ***
    m.image = createCard(m.item, invalid, invalid, m.item.GetUnwatchedCount())
    m.image.EnableFade()
    m.image.SetOrientation(m.image.ORIENTATION_PORTRAIT)
    m.image.SetFrame(m.specs.xOffset, m.specs.yOffset, m.specs.parentWidth, m.specs.parentHeight)
    m.components.Push(m.image)
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

    m.trackActions = createButtonGrid(1, 1)
    m.listPrefs.width = m.listPrefs.width - m.trackActions.GetPreferredWidth()

    ' *** season Items *** '
    trackCount = m.children.Count()
    ' create a shared region for the separator
    sepRegion = CreateRegion(m.listPrefs.width, 1, Colors().Separator)
    for index = 0 to trackCount - 1
        item = m.children[index]
        track = createTrack(item, FontRegistry().NORMAL, FontRegistry().NORMAL, m.customFonts.trackStatus, trackCount, true, true)
        track.Append(m.listPrefs)
        track.plexObject = item
        track.trackIndex = index
        if not item.Has("index") then
            track.SetIndex(index + 1)
        end if
        track.SetFocusable("show_item")
        m.itemList.AddComponent(track)
        if m.focusedItem = invalid then m.focusedItem = track

        if index < trackCount - 1 then
            track.AddSeparator(sepRegion)
        end if
    end for
    m.components.Push(m.itemList)

    ' *** Track actions ***
    actions = CreateObject("roList")
    actions.Push({text: Glyphs().EYE, command: "toggle_watched", font: m.customFonts.trackActions, zOrderInit: -1, commandCallback: createCallable("Refresh", m) })
    buttonFields = {trackAction: true}
    m.trackActions.AddButtons(actions, buttonFields, m)
    m.components.Push(m.trackActions)

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

sub seasonInitItem()
    ApplyFunc(ContextListScreen().InitItem, m)

    m.specs.Append({
        parentHeight:417
        parentWidth: 283
    })

    m.player = VideoPlayer()
    m.listPrefs.width = 677
    m.listPrefs.height = 120
end sub

sub seasonLoadContext()
    if m.context = invalid then
        if m.item.GetContextPath(false) <> invalid then
            request = createPlexRequest(m.server, m.item.GetContextPath(false))
            context = request.CreateRequestContext("preplay_context", createCallable("OnContextResponse", m))
            context.hubIdentifier = m.requestItem.container.Get("hubIdentifier")
            Application().StartRequest(request, context)
        end if
    end if
end sub

function seasonHandleCommand(command as string, item as dynamic) as boolean
    ' If it was a track action, make sure it has the last focused track set as its item
    if item <> invalid and item.trackAction = true then
        item.plexObject = m.focusedListItem.plexObject
    end if

    if command = "go_to_show" then
        Application().PushScreen(createPreplayContextScreen(m.item, m.item.Get("parentKey")))
        return true
    else if command = "toggle_watched" then
        m.SetRefocusItem(item.plexObject)
        m.itemPath = m.item.GetItemPath()
    end if

    return ApplyFunc(ContextListScreen().HandleCommand, m, [command, item])
end function
