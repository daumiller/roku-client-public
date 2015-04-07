function ContextListScreen() as object
    if m.ContextListScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PreplayScreen())

        obj.screenName = "Context List Screen"

        ' Methods
        obj.InitItem = clInitItem
        obj.Init = clInit
        obj.Show = clShow
        obj.ResetInit = clResetInit
        obj.Refresh = clRefresh
        obj.OnChildResponse = clOnChildResponse
        obj.HandleCommand = clHandleCommand
        obj.GetButtons = clGetButtons
        obj.OnFocusIn = clOnFocusIn

        ' Remote button methods
        obj.OnPlayButton = clOnPlayButton

        m.ContextListScreen = obj
    end if

    return m.ContextListScreen
end function

function createContextListScreen(item as object, path=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ContextListScreen())

    obj.requestItem = item
    obj.path = path

    obj.Init()

    return obj
end function

sub clInit()
    ApplyFunc(PreplayScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts = {
        glyphs: FontRegistry().GetIconFont(32),
        trackStatus: FontRegistry().GetIconFont(20),
        trackActions: FontRegistry().GetIconFont(18)
    }

    m.ResetInit(m.path)
end sub

sub clResetInit(path=invalid as dynamic)
    m.DisableListeners(true)
    m.server = m.requestItem.GetServer()

    ' path override (optional)
    if path <> invalid then
        m.path = path
        m.childrenPath = m.path + iif(m.requestItem.type = "playlist", "/items", "/children")
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

sub clShow()
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

            m.screen.DrawLock()
            ApplyFunc(ComponentsScreen().Show, m)
            m.screen.DrawUnlock()

            ' TODO(rob): This works just like the other preplay screens, but do we want
            ' the << >> buttons to scroll quicker through the vertical list? We might
            ' just want to keep this consistent, and it may be irrelevant once we have
            ' support for scrolling acceleration.

            ' Load context for << >> navigation
            m.LoadContext()
        else
            dialog = createDialog("Unable to load", "Sorry, we couldn't load the requested item.", m)
            dialog.AddButton("OK", "close_screen")
            dialog.HandleButton = preplayDialogHandleButton
            dialog.Show()
        end if
    end if
end sub

sub clOnChildResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response
    context.items = response.items
    children = response.items

    ' duration calculation until PMS supplies it.
    m.duration = 0
    m.children.Clear()
    if context.items.Count() > 0 then
        for each item in context.items
            m.duration = m.duration + item.GetInt("duration")
            m.children.Push(item)
        end for
    end if

    m.Show()
end sub

function clGetButtons() as object
    components = createObject("roList")

    buttons = createObject("roList")
    buttons.Push({text: Glyphs().PLAY, command: "play"})
    buttons.Push({text: Glyphs().SHUFFLE, command: "shuffle"})

    buttonHeight = 50
    for each button in buttons
        btn = createButton(button.text, m.customFonts.glyphs, button.command)
        btn.SetColor(Colors().Text, Colors().Button)
        btn.width = 100
        btn.height = buttonHeight
        btn.fixed = false
        btn.DisableNonParentExit("down")
        if m.focusedItem = invalid then m.focusedItem = btn
        components.Push(btn)
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

    ' manual pivots and commands
    if m.item.Get("type", "") = "season" then
        manualPivotsAndCommands = [
            {command: "go_to_show", text: "Go to show"}
        ]
        for each pivot in manualPivotsAndCommands
            option = {}
            option.Append(pivot)
            option.Append(optionPrefs)
            btn.options.push(option)
        end for
    end if

    if m.item.relatedItems <> invalid then
        for each item in m.item.relatedItems
            option = {
                text: item.GetSingleLineTitle(),
                command: "show_grid",
                plexObject: item,
            }
            option.Append(optionPrefs)
            btn.options.Push(option)
        end for
    end if

    if btn.options.Count() > 0 then
        components.Push(btn)
    end if

    return components
end function

function clHandleCommand(command as string, item as dynamic) as boolean
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

sub clOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
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
    if m.trackActions <> invalid then
        if toFocus <> invalid and toFocus.hasTrackActions = true then
            rect = computeRect(toFocus)
            m.trackActions.SetPosition(rect.right + 1, rect.up + int((rect.height - m.trackActions.GetPreferredHeight()) / 2))
            m.trackActions.SetVisible(true)
            m.focusedListItem = toFocus

            ' Toggle some of our track actions based on the current track
            m.trackActions.SetPlexObject(toFocus.plexObject)
        else
            m.trackActions.SetVisible(false)
        end if
    end if
end sub

sub clOnPlayButton(item=invalid as dynamic)
    m.HandleCommand("play", item)
end sub

sub clRefresh(request=invalid as dynamic, response=invalid as dynamic, context=invalid as dynamic)
    if m.itemPath <> invalid then
        m.ResetInit(m.itemPath)
        ApplyFunc(PreplayScreen().Refresh, m)
        m.refocus = invalid
    end if
end sub

sub clInitItem()
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
        zOrder: 2,
        hasTrackActions: true
    }
end sub
