function GridScreen() as object
    if m.GridScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Grid Screen"

        ' Methods
        obj.Show = gsShow
        obj.Init = gsInit
        obj.OnGridResponse = gsOnGridResponse
        obj.OnJumpResponse = gsOnJumpResponse
        obj.HandleCommand = gsHandleCommand
        obj.GetComponents = gsGetComponents
        obj.OnFocusIn = gsOnFocusIn

        ' Shifting Methods
        obj.CalculateShift = gsCalculateShift
        obj.ShiftComponents = gsShiftComponents

        ' Grid Methods
        obj.GetGridChunks = gsGetGridChunks
        obj.CreateGridChunk = gsCreateGridChunk
        obj.LoadGridChunk = gsLoadGridChunk
        obj.OnLoadGridChunk = gsOnLoadGridChunk
        obj.ChunkIsLoaded = gsChunkIsLoaded

        m.GridScreen = obj
    end if

    return m.GridScreen
end function

sub gsInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' use default path if not overridden
    if m.path = invalid then
        m.path = m.item.GetAbsolutePath("key")
    end if
    m.server = m.item.GetServer()

    m.gridContainer = CreateObject("roAssociativeArray")
    m.jumpContainer = CreateObject("roAssociativeArray")
    m.placeholders = CreateObject("roList")
    m.jumpItems = CreateObject("roList")

    ' lazy style loading. We might allow the user to modify this, but the different platforms
    ' seem to need a different style to make them work a little better. The Roku 3 is about
    ' the only platform that can keep up with background tasks without causing lag in the UI.
    ' 0: load after key release (non Roku 3)
    ' 1: load inline (Roku 3)
    if appSettings().GetGlobal("animationFull") then
        m.lazyStyle = 1
        m.chunkSize = 100
        m.chunkLoadLimit = 2
    else
        m.lazyStyle = 0
        m.chunkSize = 26
        m.chunkLoadLimit = 5
    end if

    ' use a smaller chunk for the inital load size. This may need to vary
    ' depending on the grid type (artwork, poster)
    m.chunkSizeInitial = 16
end sub

function createGridScreen(item as object, path=invalid as dynamic, rows=2 as integer, orientation=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GridScreen())

    obj.item = item
    obj.path = path

    obj.Init()

    ' TODO(rob): we need a better way to determine orientation, or we might just need to
    ' always set it when calling the grid screen
    containerType = item.Get("type")
    if orientation <> invalid then
        obj.orientation = orientation
    else if containerType = invalid then
        obj.orientation=ComponentClass().ORIENTATION_LANDSCAPE
    else if containerType = "movie" or containerType = "show" or containerType = "episode" or containerType = "mixed" then
        obj.orientation=ComponentClass().ORIENTATION_PORTRAIT
    else if containerType = "photo" or containerType = "artist" or containerType = "album" then
        obj.orientation=ComponentClass().ORIENTATION_SQUARE
    else
        obj.orientation = ComponentClass().ORIENTATION_LANDSCAPE
    end if
    Debug("GridScreen: containerType=" + tostr(containerType) + ", orientation=" + tostr(obj.orientation))

    ' how should we handle these variables?
    obj.rows = rows
    obj.spacing = 10
    obj.height = 450

    return obj
end function

sub gsShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create requests for the size of the endpoint
    if m.gridContainer.request = invalid then
        request = createPlexRequest(m.server, m.path)
        request.AddHeader("X-Plex-Container-Start", "0")
        request.AddHeader("X-Plex-Container-Size", "0")

        context = request.CreateRequestContext("grid", createCallable("OnGridResponse", m))
        Application().StartRequest(request, context)
        m.gridContainer = context

        ' create requests for the jump items (only if we are using the ALL endpoint)
        if m.jumpContainer.request = invalid and instr(1, m.path, "/all") > 0 and not instr(1, m.path, "sort=") > 0 then
            ' support filtered endpoints (replace /all with /firstCharacter)
            regex = CreateObject("roRegex", "/all", "")
            jumpUrl = regex.Replace(m.path, "/firstCharacter")
            request = createPlexRequest(m.server, jumpUrl)
            context = request.CreateRequestContext("jump", createCallable("OnJumpResponse", m))
            Application().StartRequest(request, context)
            m.jumpContainer = context
        else
            m.jumpContainer.response = {}
        end if
    end if

    if m.gridContainer.response <> invalid and m.jumpContainer.response <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)
    end if
end sub

' Handle jump response (firstCharacter)
function gsOnJumpResponse(request as object, response as object, context as object) as object
    response.ParseResponse()
    context.response = response

    m.jumpItems.clear()
    incr = 0
    for each item in response.items
        m.jumpItems.push({
            index: incr,
            key: item.Get("key")
            title: item.Get("title")
            size: item.GetInt("size")
        })
        incr = incr + item.GetInt("size")
    end for

    m.show()
end function

' Handle initial response from the endpoint request
function gsOnGridResponse(request as object, response as object, context as object) as object
    response.ParseResponse()
    context.response = response
    m.container = response.container

    ' obtain the contentType and viewGroup for UI decisions (overlay, orientation)
    m.contentType = firstOf(m.container.Get("type"), m.item.type)
    m.viewGroup = m.container.Get("viewGroup", "")

    m.totalSize = response.container.getint("totalSize")
    if m.totalSize < m.chunkSizeInitial then m.chunkSizeInitial = m.totalSize
    ' TODO(rob): we should use 3/4 height for landscape and square orientation
    if m.totalSize < 20 and m.orientation = ComponentClass().ORIENTATION_PORTRAIT then m.rows = 1
    placeholder = {
        start: 0,
        size: m.chunkSizeInitial,
        path: request.path,
    }
    m.placeholders.push(placeholder)

    for index = m.chunkSizeInitial to m.totalsize-1 step m.chunkSize
        size = m.chunkSize
        if index + size > m.totalsize then
            size = size - ((index + size) - m.totalsize)
        end if
        placeholder = {
            start: index,
            size: size,
            path: request.path,
        }
        m.placeholders.push(placeholder)
    end for

    m.show()
end function

function gsHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "jump_button" then
        for each component in m.shiftableComponents
            if component.jumpIndex = item.metadata.index then
                m.FocusItemManually(component)
                exit for
            end if
        next
    else if not ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
        handled = false
    end if

    return handled
end function

sub gsGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

    ' *** Grid Header *** '
    if m.item.Get("key", "") = "all" and m.container.Get("librarySectionTitle") <> invalid then
        title = m.container.Get("librarySectionTitle")
    else if m.viewGroup = "episode" then
        title = m.container.Get("title1", "") + " / " + m.container.Get("title2", "")
    else
        title = m.item.GetSingleLineTitle()
    end if
    label = createLabel(ucase(title), FontRegistry().font16)
    label.height = FontRegistry().font16.getOneLineHeight()
    label.width = FontRegistry().font16.getOneLineWidth(label.text, 1280)
    label.SetFrame(50, 120 - m.spacing - label.height, label.width, label.height)
    m.components.Push(label)

    ' *** Grid *** '
    hbox = createHBox(false, false, false, 10)
    hbox.SetFrame(50, 120, 2000*2000, m.height)

    ' Grid Chunks / Placeholders
    chunks = m.GetGridChunks()
    if chunks.count() > 0 then
        for index = 0 to chunks.count()-1
            hbox.AddComponent(chunks[index])
        end for
    end if
    m.components.Push(hbox)

    ' TODO(rob) determine how many chunks to initially load (xml data)
    if m.chunkLoadLimit = invalid then
        m.LoadGridChunk(chunks, 0, chunks.count())
    else
        m.LoadGridChunk(chunks, 0, m.chunkLoadLimit)
    end if

    ' *** Jump Box *** '
    m.jumpBox = createJumpBox(m.jumpItems, FontRegistry().font14, 120 + m.height, 5)
    m.components.Push(m.jumpBox)

    ' set the placement of the description box (manualComponent)
    m.DescriptionBox = createDescriptionBox(m)
    m.DescriptionBox.setFrame(50, 630, 1280-50, 100)
end sub

function gsCreateGridChunk(placeholder as object) as dynamic
    if placeholder = invalid or placeholder.size = invalid then return invalid

    grid = createGrid(m.orientation, m.rows, m.spacing)
    grid.height = m.height

    ' set the properties needed to lazyload the chunk
    grid.placeholder = placeholder
    grid.loadStatus = 0

    for index = 0 to placeholder.size-1
        card = createCardPlaceholder(m.contentType)
        card.SetFocusable(invalid)
        if m.focusedItem = invalid then m.focusedItem = card
        card.jumpIndex = placeholder.start + index
        grid.AddComponent(card)
    end for

    return grid
end function

function gsGetGridChunks() as object
    components = []

    for each placeholder in m.placeholders
        gridChunk = m.CreateGridChunk(placeholder)
        if gridChunk <> invalid then
            components.push(gridChunk)
        end if
    end for

    return components
end function

sub gsOnFocusIn(toFocus as object, lastFocus=invalid as dynamic)
    ApplyFunc(ComponentsScreen().OnFocusIn, m, [toFocus, lastFocus])
    m.jumpBox.OnFocusIn(toFocus)
end sub

' ************ shifting ****************'
sub gsCalculateShift(toFocus as object, refocus=invalid as dynamic)
    if toFocus.fixed = true then return

    ' load the grid chunk if the focused items chunk isn't loaded yet
    if m.lazyStyle = 1 and m.ChunkIsLoaded(tofocus.parent) = false then
        m.LoadGridChunk([tofocus.parent])
    end if

    ' TODO(rob): safeRight/safeLeft should be global/appsettings
    if m.shift = invalid then
        m.shift = {
            safeRight: 1230
            safeLeft: 50
            demandX: int( (1280/toFocus.width)/2) * toFocus.width
        }
    end if
    shift = { x: 0, y:0 }
    shift.Append(m.shift)

    focusRect = computeRect(toFocus)
    ' reuse the last position on refocus
    if refocus <> invalid and focusRect.left <> refocus.left then
        shift.x = refocus.left - focusRect.left
    ' shift the component to the "middle" if off screen
    else if focusRect.right > shift.safeRight then
        shift.x = (focusRect.left - shift.demandX) * -1
    else if focusRect.left < shift.safeLeft then
        shift.x = shift.demandX - focusRect.left
    end if

    if (shift.x <> 0 or shift.y <> 0) then
        m.shiftComponents(shift)
    end if
end sub

sub gsShiftComponents(shift as object)
    ' disable any lazyLoad timer
    m.lazyLoadTimer.active = false
    m.lazyLoadTimer.components = invalid
    m.lazyLoadTimer.chunks = invalid

    ' If we are shifting by a lot, we'll need to "jump" and clear some components
    ' as we cannot animate it (for real) due to memory limitations (and speed).
    if shift.x > 1280 or shift.x < -1280 then
        ' cancel any pending textures before we have a large shift
        TextureManager().CancelAll(false)

        ' Two Passes:
        '  1. Get a list of components on the screen after shift
        '      while unloading components offscreen
        '  2: Recalculate the shift (first last grid check) and
        '     shift all coponents without shifting sprites. Then
        '     fire off events to lazy load if needed.

        ' Pass 1
        onScreen = CreateObject("roList")
        for each comp in m.shiftableComponents
            if comp.IsOnScreen(shift.x, shift.x) then
                onScreen.push(comp)
            end if
        end for

        ' Pass 2
        shift.x = m.CalculateFirstOrLast(onScreen, shift)
        onScreen.clear()
        loadChunks = []
        for each comp in m.shiftableComponents
            comp.ShiftPosition(shift.x, shift.y, false)
            if comp.IsOnScreen() then
                comp.ShiftPosition(0, 0)
                onScreen.push(comp)
                if m.ChunkIsLoaded(comp.parent) = false then
                    m.loadGridChunk([comp.parent])
                end if
            else if comp.sprite <> invalid or comp.region <> invalid then
                comp.Unload()
            end if
        end for

        m.onScreenComponents = onScreen

        ' Test memory cleanup by calling a DrawAll and Stop
        ' and run r2d2_bitmaps on port 8080
        ' m.screen.drawall()
        ' stop

        m.LazyLoadExec(onScreen)
        return
    end if

    ' TODO(rob) the logic below has only been testing shifting the x axis.
    Debug("shift components by: " + tostr(shift.x) + "," + tostr(shift.y))
    perfTimer().mark()

    ' partShift: on screen or will be after shift (animate/scroll, partial shifting)
    ' fullShift: off screen before/after shifting (no animation, shift in full)
    curX = m.focusedItem.x
    curWidth = m.focusedItem.width
    partShift = CreateObject("roList")
    fullShift = CreateObject("roList")

    ' this is quicker than using IsOnScreen() for each component
    triggerLazyLoad = false
    ' minX/maxX: are all components on screen during shift
    minX = curWidth*-1 + abs(shift.x)*-1
    maxX = (1280 + curWidth) + abs(shift.x)
    ' llminX/llmaxX: lazy load any componenet within this range if not loaded
    llminX = m.ll_trigger*-1 + abs(shift.x)*-1
    llmaxX = (m.ll_trigger) + abs(shift.x)

    chunksToLoad = CreateObject("roList")
    for each component in m.shiftableComponents
        compX = component.x+shift.x
        if compX > minX and compX < maxX then
            if m.ChunkIsLoaded(component.parent) = false then
                if m.lazyStyle = 1 then
                    m.loadGridChunk([component.parent])
                else
                    chunksToLoad.Push(component.parent)
                end if
            end if
            partShift.push(component)
        else if triggerLazyLoad = false and compX > llminX and compX < llmaxX and component.SpriteIsLoaded() = false then
            triggerLazyLoad = true
            fullShift.push(component)
        else
            fullShift.push(component)
        end if
    end for
    perfTimer().Log("Determined shiftable items: " + "onscreen=" + tostr(partShift.count()) + ", offScreen=" + tostr(fullShift.count()))

    ' set the onScreen components (helper for the manual Focus)
    m.OnScreenComponents = partShift

    ' verify we are not shifting the components to far (first or last component). This
    ' will modify shift.x based on the first or last component viewable on screen. It
    ' should be quick to iterate partShift (on screen components after shifting).
    shift.x = m.CalculateFirstOrLast(partShift, shift)

    ' return if we calculated zero shift
    if shift.x = 0 and shift.y = 0 then return

    ' hide the focus box before we shift
    m.screen.hideFocus()

    ' lazy-load any components that will be on-screen after we shift
    ' and cancel any pending texture requests
    TextureManager().CancelAll(false)
    m.LazyLoadExec(partShift)

    AnimateShift(shift, partShift, m.screen)
    perfTimer().Log("Shifted ON screen items, expect *high* ms  (partShift)")

    ' draw the focus directly after shifting all on screen components
    m.screen.DrawFocus(m.focusedItem, true)

    ' shift all off screen components. This will set the x,y postition and
    ' unload the components if offscreen by enough pixels (ll_unload)
    for each comp in fullShift
        comp.ShiftPosition(shift.x, shift.y, false)
    end for
    perfTimer().Log("Shifted OFF screen items (fullShift)")

    ' lazy-load any components off screen, but within our range (ll_trigger)
    ' create a timer to load when the user has stopped shifting (LazyLoadOnTimer)
    lazyLoad = CreateObject("roList")
    if triggerLazyLoad = true then
        perfTimer().Mark()
        ' add any off screen component withing range
        for each candidate in fullShift
            if m.ChunkIsLoaded(candidate.parent) = true and candidate.SpriteIsLoaded() = false and candidate.IsOnScreen(0, 0, m.ll_load) then
                lazyLoad.Push(candidate)
            end if
        end for
        perfTimer().Log("Determined lazy load components (off screen): total=" + tostr(lazyLoad.count()))
    end if

    if lazyLoad.count() > 0 or chunksToLoad.count() > 0 then
        m.lazyLoadTimer.active = true
        m.lazyLoadTimer.components = lazyLoad
        if chunksToLoad.count() > 0 then
            m.lazyLoadTimer.chunks = chunksToLoad
            m.lazyLoadTimer.SetDuration(100)
        else
            m.lazyLoadTimer.SetDuration(m.ll_timerDur)
        end if
        Application().AddTimer(m.lazyLoadTimer, createCallable("LazyLoadOnTimer", m))
        m.lazyLoadTimer.mark()
    end if
end sub

function gsOnLoadGridChunk(request as object, response as object, context as object) as object
    response.ParseResponse()
    items = response.items

    ' replace the gridChunk component objects with valid data
    gridChunk = context.gridChunk
    for index = 0 to items.count()-1
        item = items[index]
        gridItem = gridChunk.components[index]
        if item <> invalid and gridItem <> invalid then
            ' reinit the card - set metadata and plexObject and focusability
            contentType = item.Get("type", "")
            viewGroup = item.container.Get("viewGroup", "")

            ' TODO(rob): handle the viewstate overlays differently (cleaner...)
            if contentType = "album" or contentType = "artist" then
                gridItem.ReInit(item, item.GetOverlayTitle())
            else
                if contentType = "episode" and viewGroup = contentType and item.Get("index") <> invalid then
                    title = "Episode " + item.Get("index")
                else
                    title = item.GetOverlayTitle()
                end if
                gridItem.ReInit(item, title, item.GetViewOffsetPercentage(), item.GetUnwatchedCount(), item.IsUnwatched())
            end if
            gridItem.setMetadata(item.attrs)
            gridItem.plexObject = item
            gridItem.SetFocusable("show_item")

            ' update focused item if we are replacing the context
            if m.focusedItem <> invalid and m.focuseditem.equals(gridItem) then
                m.focusedItem = gridItem
                m.FocusItemManually(m.focusedItem)
            end if

            ' redraw the component, only within the loading area (ll_load)
            if gridItem.IsOnScreen(0, 0, m.ll_load) then
                gridItem.draw()
            end if
        end if
    end for

    ' set the grid chunk load status complete
    gridChunk.loadStatus = 2

    ' continue loading next chunk if applicable
    if context.loadNext > 0 then
        m.LoadGridChunk(context.gridChunks, context.nextIndex, context.loadNext)
    end if
end function

' request the Grid chunk from the PMS
sub gsLoadGridChunk(gridChunks as object, offset=0 as integer, loadMax=0 as integer)
    gridChunk = gridChunks[offset]
    if gridChunk = invalid then return
    if gridChunk.loadStatus <> 0 then
        Debug("Ignore load request. Current status=" + tostr(gridChunk.loadStatus))
        return
    end if

    Debug("Loading Grid Chunk: start=" + tostr(gridChunk.placeholder.start) + ", size=" + tostr(gridChunk.placeholder.size))
    request = createPlexRequest(m.server, gridChunk.placeholder.path)
    request.AddHeader("X-Plex-Container-Start", tostr(gridChunk.placeholder.start))
    request.AddHeader("X-Plex-Container-Size", tostr(gridChunk.placeholder.size))
    context = request.CreateRequestContext("grid", createCallable("OnLoadGridChunk", m))
    context.gridChunk = gridChunk

    ' next grid chunk to load
    context.gridChunks = gridChunks
    context.nextIndex = offset+1
    context.loadNext = loadMax-1

    gridChunk.loadStatus = 1

    Application().StartRequest(request, context)
end sub

function gsChunkIsLoaded(grid as object) as boolean
    ' 0: not loaded
    ' 1: loading/pending
    ' 2: loaded
    return (grid.loadStatus = 2)
end function
