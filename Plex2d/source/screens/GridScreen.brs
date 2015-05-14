function GridScreen() as object
    if m.GridScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Grid Screen"

        ' Methods
        obj.Show = gsShow
        obj.Init = gsInit
        obj.OnGridResponse = gsOnGridResponse
        obj.OnSortResponse = gsOnSortResponse
        obj.OnJumpResponse = gsOnJumpResponse
        obj.HandleCommand = gsHandleCommand
        obj.GetComponents = gsGetComponents
        obj.OnFocusIn = gsOnFocusIn

        ' Shifting Methods
        obj.CalculateShift = gsCalculateShift
        obj.ShiftComponents = gsShiftComponents
        obj.OnFwdButton = gsOnFwdButton
        obj.OnRevButton = gsOnRevButton
        obj.AdvancePage = gsAdvancePage

        ' Grid Methods
        obj.GetGridChunks = gsGetGridChunks
        obj.CreateGridChunk = gsCreateGridChunk
        obj.LoadGridChunk = gsLoadGridChunk
        obj.OnLoadGridChunk = gsOnLoadGridChunk
        obj.ChunkIsLoaded = gsChunkIsLoaded

        ' Refresh methods
        obj.Refresh = gsRefresh
        obj.ResetInit = gsResetInit

        obj.SetRefocusItem = gsSetRefocusItem

        m.GridScreen = obj
    end if

    return m.GridScreen
end function

sub gsInit()
    ApplyFunc(ComponentsScreen().Init, m)

    m.spacing = 10
    m.height = 445
    m.xPadding = 50
    m.yOffset = 125
    m.displayWidth = AppSettings().GetWidth()
    m.displayHeight = AppSettings().GetHeight()

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

    m.ResetInit(m.path)
end sub

function createGridScreen(item as object, path=invalid as dynamic, rows=2 as integer, orientation=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GridScreen())

    obj.item = item
    obj.path = path

    ' TODO(rob): we need a better way to determine orientation, or we might just need to
    ' always set it when calling the grid screen
    obj.containerType = firstOf(item.container.Get("type"), item.Get("type"))

    ' Prefer the specific item type if mixed
    if obj.containerType = "mixed" then obj.containerType = firstOf(item.Get("type"), obj.containerType)

    ' Handle endpoints where the container type is invalid and the item type is an episode.
    ' e.g. "home.ondeck" which are all episodes, but we display them as portrait (mixed)
    if item.container.Get("type") = invalid and item.Get("type") = "episode" then
        obj.containerType = "mixed"
    end if

    ' Force episodes and seasons into their own screen
    if obj.containerType = "episode" or obj.containerType = "season" then
        return createSeasonScreen(item, path)
    end if

    if orientation <> invalid then
        obj.orientation = orientation
    else if obj.containerType = invalid then
        obj.orientation = ComponentClass().ORIENTATION_LANDSCAPE
    else if obj.containerType = "movie" or obj.containerType = "show" or obj.containerType = "mixed" then
        obj.orientation = ComponentClass().ORIENTATION_PORTRAIT
    else if obj.containerType = "photo" or obj.containerType = "photoalbum" then
        obj.orientation = ComponentClass().ORIENTATION_SQUARE
    else if obj.containerType = "artist" or obj.containerType = "album" or obj.containerType = "playlist" then
        obj.orientation = ComponentClass().ORIENTATION_SQUARE
    else
        obj.orientation = ComponentClass().ORIENTATION_LANDSCAPE
    end if

    obj.Init()
    obj.rows = rows

    Debug("GridScreen: containerType=" + tostr(obj.containerType) + ", orientation=" + tostr(obj.orientation))

    return obj
end function

sub gsShow()
    if NOT Application().IsActiveScreen(m) then return

    requests = CreateObject("roList")

    ' Create request for the default sort, unless we already have a sort
    if m.sortContainer.request = invalid then
        if m.sectionPath <> invalid and instr(1, m.path, "/all") > 0 and instr(1, m.path, "sort=") = 0 then
            itemType = CreateObject("roRegex", "type=\d+", "").Match(m.path)[0]
            request = createPlexRequest(m.server, m.sectionPath + JoinArray(["/sorts", itemType], "?"))
            m.sortContainer = request.CreateRequestContext("sort", createCallable("OnSortResponse", m))
            requests.Push({request: request, context: m.sortContainer})
        else
            m.sortContainer.response = {}
        end if
    end if

    ' Create request for the size of the endpoint (after we determine the default sort)
    if m.sortContainer.response <> invalid and m.gridContainer.request = invalid then
        request = createPlexRequest(m.server, m.path)
        request.AddHeader("X-Plex-Container-Start", "0")
        request.AddHeader("X-Plex-Container-Size", "0")

        m.gridContainer = request.CreateRequestContext("grid", createCallable("OnGridResponse", m))
        requests.Push({request: request, context: m.gridContainer})
    end if

    ' Create request for the jump items (only if we are using the ALL endpoint)
    if m.jumpContainer.request = invalid then
        jumpSortSupported = instr(1, m.path, "/all") > 0 and (instr(1, m.path, "sort=") = 0 or instr(1, m.path, "sort=titleSort") > 0)
        if jumpSortSupported then
            ' support filtered endpoints (replace /all with /firstCharacter)
            regex = CreateObject("roRegex", "/(\w+)(\?|$)", "")
            jumpUrl = regex.Replace(m.path, "/firstCharacter\2")
            request = createPlexRequest(m.server, jumpUrl)
            m.jumpContainer = request.CreateRequestContext("jump", createCallable("OnJumpResponse", m))
            requests.Push({request: request, context: m.jumpContainer})
        else
            m.jumpContainer.response = {}
        end if
    end if

    for each request in requests
        Application().StartRequest(request.request, request.context)
    end for

    if m.gridContainer.response <> invalid and m.jumpContainer.response <> invalid and m.sortContainer.response <> invalid then
        if m.gridContainer.response.container.GetFirst(["totalSize", "size"], "0").toInt() = 0 then
            if m.filterBox <> invalid then
                ' If we have a filterBox, then our filter is too limited, so we'll need
                ' to clear the filters refresh the grid
                title = "No matching content"
                text = "There is no content matching your active filter."
                m.ShowFailure(title, text, false)

                m.Refresh(m.filterBox.filters.BuildPath(true), false)
            else
                title = "No content available in this library"
                text = "Please add content and/or check that " + chr(34) + "Include in dashboard" + chr(34) + " is enabled.".
                m.ShowFailure(title, text)
            end if
        else
            ApplyFunc(ComponentsScreen().Show, m)
        end if
    end if
end sub

' Handle jump response (firstCharacter)
sub gsOnJumpResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response

    m.jumpItems.Clear()

    ' Ignore jump list if we only have 1 item.
    ' TODO(rob): We may want to ignore the jump list based
    ' on the `incr` count (total items)
    '
    if response.items.Count() > 1
        ' Reverse the jump list for descending title sort
        if instr(1, request.GetUrl(), "titleSort:desc") > 0 then
            items = CreateObject("roList")
            for each item in response.items
                items.Unshift(item)
            end for
        else
            items = response.items
        end if

        incr = 0
        for each item in items
            m.jumpItems.push({
                index: incr,
                key: item.Get("key")
                title: item.Get("title")
                size: item.GetInt("size")
            })
            incr = incr + item.GetInt("size")
        end for
    end if

    m.Show()
end sub

' Handle initial response from the endpoint request
sub gsOnGridResponse(request as object, response as object, context as object)
    ' Show a failure and pop the screen if the request failed.
    if not response.IsSuccess() then
        m.ShowFailure()
        return
    end if

    response.ParseResponse()
    context.response = response
    m.container = response.container

    ' obtain the contentType and viewGroup for UI decisions (overlay, orientation)
    m.contentType = firstOf(m.container.Get("type"), m.containerType)
    m.viewGroup = m.container.Get("viewGroup", "")
    m.hasMixedParents = (m.container.Get("mixedParents", "") = "1")

    m.totalSize = response.container.GetInt("totalSize")
    if m.totalSize < m.chunkSizeInitial then m.chunkSizeInitial = m.totalSize

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

    m.Show()
end sub

function gsHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    if command = "jump_button" then
        for each component in m.shiftableComponents
            if component.jumpIndex = item.metadata.index then
                m.FocusItemManually(component)
                exit for
            end if
        next
    else
        return ApplyFunc(ComponentsScreen().HandleCommand, m, [command, item])
    end if

    return handled
end function

sub gsGetComponents()
    ' Calculate our grid chunks before destroying components. This will
    ' allow us to show a loading modal for larger/slower grids. The
    ' focused items is calculated here, so we'll need to retain it.
    chunks = m.GetGridChunks()
    focusedItem = m.focusedItem

    m.DestroyComponents()
    m.focusedItem = focusedItem

    ' *** HEADER *** '
    header = createHeader(m)
    m.components.Push(header)

    ' *** Grid Header *** '

    ' Set m.gridTitle to retain the same title on refresh
    if m.gridTitle = invalid then
        if m.filterBox <> invalid and m.filterBox.filters.IsModified() then
            m.gridTitle = m.container.GetFirst(["librarySectionTitle"], "Custom Filter")
        else if left(m.item.Get("key", ""), 3) = "all" and m.container.Get("librarySectionTitle") <> invalid then
            m.gridTitle = m.container.Get("librarySectionTitle")
        else if m.viewGroup = "episode" and not m.hasMixedParents then
            title = m.container.Get("title1", "") + " / " + m.container.Get("title2", "")
        else
            title = m.item.GetSingleLineTitle()
        end if
    end if
    label = createLabel(ucase(firstOf(m.gridTitle, title)), FontRegistry().NORMAL)
    label.height = FontRegistry().NORMAL.getOneLineHeight()
    label.width = FontRegistry().NORMAL.getOneLineWidth(label.text, m.displayWidth)
    label.SetFrame(m.xPadding, m.yOffset - m.spacing - label.height, label.width, label.height)
    m.components.Push(label)

    ' *** Filter box *** '
    m.filterBox = createFilterBox(FontRegistry().NORMAL, m.item, m, 70)
    m.filterBox.SetPosition(1230, m.yOffset - m.spacing - FontRegistry().NORMAL.getOneLineHeight())
    m.components.Push(m.filterBox)

    ' *** Grid *** '
    gridBox = createHBox(false, false, false, m.spacing, false)
    gridBox.SetFrame(m.xPadding, m.yOffset, 0, m.height)

    ' Grid Chunks / Placeholders
    if chunks.Count() > 0 then
        for index = 0 to chunks.Count()-1
            gridBox.AddComponent(chunks[index])
        end for
    end if
    m.components.Push(gridBox)

    ' TODO(rob) determine how many chunks to initially load (xml data)
    if m.chunkLoadLimit = invalid then
        m.LoadGridChunk(chunks, 0, chunks.Count())
    else
        m.LoadGridChunk(chunks, 0, m.chunkLoadLimit)
    end if

    ' *** Jump Box *** '
    m.jumpBox = createJumpBox(m.jumpItems, FontRegistry().MEDIUM, gridBox.y + m.height, m.spacing)
    m.components.Push(m.jumpBox)

    ' set the placement of the description box (manualComponent)
    m.DescriptionBox = createDescriptionBox(m)
    m.DescriptionBox.setFrame(m.xPadding, 630, m.displayWidth - m.xPadding, m.displayHeight - 630)

    ' *** Focus layer helpers *** '

    ' Focus layer between the header and filter box. This will ensure we always go
    ' to the filterbox when pressing down from the headers
    '
    focusBox = createFocusBox(0, computeRect(header).down, m.displayWidth, 1)
    focusBox.SetFocusManual(m.filterBox, "down")
    m.components.Push(focusBox)

    ' Focus layer between the filter box and grid. We always want to retain where
    ' we came from in both directions (up/down)
    '
    focusBox = createFocusBox(0, gridBox.y - 2, m.displayWidth, 1)
    focusBox.SetFocusManual(m.filterBox, "up")
    focusBox.SetFocusManual(gridBox, "down")
    m.components.Push(focusBox)

    ' Focus layer between the grid and the jump box. This will ensure we always return
    ' to the grid item we came from. The jumpbox has its own focus logic (for now).
    '
    focusBox = createFocusBox(0, computeRect(gridBox).down + 1, m.displayWidth, 1)
    focusBox.SetFocusManual(gridBox, "up")
    focusBox.SetFocusManual(m.jumpbox, "down")
    m.components.Push(focusBox)
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
    m.focusedItem = invalid

    components = []
    for each placeholder in m.placeholders
        Application().CheckLoadingModal()
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
    forceLoad = not toFocus.SpriteIsLoaded()

    ' allow the component to override the method. e.g. VBox vertical scrolling
    ' * shiftableParent for containers in containers (e.g. users screen: vbox -> hbox -> component)
    ' * continue with the standard container shift (horizontal scroll), after override
    if toFocus.shiftableParent <> invalid and type(toFocus.shiftableParent.CalculateShift) = "roFunction" then
        toFocus.shiftableParent.CalculateShift(toFocus, refocus, m)
    else if toFocus.parent <> invalid and type(toFocus.parent.CalculateShift) = "roFunction" then
        toFocus.parent.CalculateShift(toFocus, refocus, m)
    end if

    ' load the grid chunk if the focused items chunk isn't loaded yet
    if m.lazyStyle = 1 and m.ChunkIsLoaded(tofocus.parent) = false then
        m.LoadGridChunk([tofocus.parent])
    end if

    ' TODO(rob): safeRight/safeLeft should be global/appsettings
    if m.shift = invalid then
        m.shift = {
            safeRight: m.displayWidth - m.xPadding,
            safeLeft: m.xPadding,
            demandX: int(m.displayWidth/2 - toFocus.width/2)
        }
    end if
    shift = {x: 0, y:0, toFocus: toFocus}
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

    if forceLoad or (shift.x <> 0 or shift.y <> 0) then
        m.shiftComponents(shift, refocus, forceLoad)
    end if
end sub

sub gsShiftComponents(shift as object, refocus=invalid as dynamic, forceLoad=false as boolean)
    ' Ignore any shift, but continue to verify everything is loaded (forceLoad)
    ignoreShift = (shift.x = 0 and forceLoad)

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
            if comp.IsOnScreen(shift.x, shift.y) then
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

    ' partShift: on screen or will be after shift (animate/scroll, partial shifting)
    ' fullShift: off screen before/after shifting (no animation, shift in full)
    curX = m.focusedItem.x
    curWidth = m.focusedItem.width
    partShift = CreateObject("roList")
    fullShift = CreateObject("roList")

    ' this is quicker than using IsOnScreen() for each component
    triggerLazyLoad = false
    ' minX/maxX: are all components on screen during shift
    minX = (curWidth * -1) + (abs(shift.x) * -1)
    maxX = 1280 + curWidth + abs(shift.x)
    ' llminX/llmaxX: lazy load any component within this range if not loaded
    llminX = (m.ll_triggerX * -1) + (abs(shift.x) * -1)
    llmaxX = m.ll_triggerX + abs(shift.x)

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
    Debug("Determined shiftable items: " + "onscreen=" + tostr(partShift.Count()) + ", offScreen=" + tostr(fullShift.Count()))

    ' set the onScreen components (helper for the manual Focus)
    m.onScreenComponents = partShift

    ' lazy-load any components that will be on-screen after we shift
    ' and cancel any pending texture requests
    TextureManager().CancelAll(false)
    m.LazyLoadExec(partShift)

    if ignoreShift then
        m.LazyLoadExec([shift.toFocus])
    else
        ' verify we are not shifting the components to far (first or last component). This
        ' will modify shift.x based on the first or last component viewable on screen. It
        ' should be quick to iterate partShift (on screen components after shifting).
        ' return if we calculated zero shift, or a very minimal shift
        shift.x = m.CalculateFirstOrLast(partShift, shift)
        if abs(shift.x) < 5 and abs(shift.y) < 5 then return

        Debug("shift components by: " + tostr(shift.x) + "," + tostr(shift.y))

        ' hide the focus box before we shift
        m.screen.HideFocus()

        if refocus = invalid then
            AnimateShift(shift, partShift, m.screen)
        else
            for each component in partShift
                component.ShiftPosition(shift.x, shift.y, true)
            end for
        end if

        ' draw the focus directly after shifting all on screen components
        if m.DrawFocusOnRelease <> true then
            m.screen.DrawFocus(m.focusedItem, true)
        end if

        ' shift all off screen components. This will set the x,y postition and
        ' unload the components if offscreen by enough pixels (ll_unloadX)
        for each comp in fullShift
            comp.ShiftPosition(shift.x, shift.y, false)
        end for
    end if

    ' lazy-load any components off screen within our range (ll_triggerX)
    ' create a timer to load when the user has stopped shifting (LazyLoadOnTimer)
    lazyLoad = CreateObject("roList")
    if triggerLazyLoad = true then
        ' add any off screen component withing range
        for each candidate in fullShift
            if m.ChunkIsLoaded(candidate.parent) = true and candidate.SpriteIsLoaded() = false and candidate.IsOnScreen(0, 0, m.ll_loadX, m.ll_loadY) then
                lazyLoad.Push(candidate)
            end if
        end for
        Debug("Determined lazy load components (off screen): total=" + tostr(lazyLoad.Count()))
    end if

    if lazyLoad.Count() > 0 or chunksToLoad.Count() > 0 then
        m.lazyLoadTimer.active = true
        m.lazyLoadTimer.components = lazyLoad
        if chunksToLoad.Count() > 0 then
            m.lazyLoadTimer.chunks = chunksToLoad
            m.lazyLoadTimer.SetDuration(100)
        else
            m.lazyLoadTimer.SetDuration(m.ll_timerDur)
        end if
        Application().AddTimer(m.lazyLoadTimer, createCallable("LazyLoadOnTimer", m))
        m.lazyLoadTimer.Mark()
    end if
end sub

function gsOnLoadGridChunk(request as object, response as object, context as object) as object
    response.ParseResponse()
    items = response.items

    ' replace the gridChunk component objects with valid data
    gridChunk = context.gridChunk
    for index = 0 to items.Count()-1
        item = items[index]
        gridItem = gridChunk.components[index]
        if item <> invalid and gridItem <> invalid then
            ' reinit the card - set metadata and plexObject and focusability
            contentType = item.Get("type", "")
            viewGroup = item.container.Get("viewGroup", "")

            ' TODO(rob): handle the viewstate overlays differently (cleaner...)
            thumbAttrs = invalid
            ' specific types having no view states
            if contentType = "album" or contentType = "artist" or contentType = "playlist" or contentType = "photoalbum" or contentType = "photo" then
                gridItem.ReInit(item, item.GetOverlayTitle())
            else
                if contentType = "episode" and viewGroup = contentType and not m.hasMixedParents then
                    thumbAttrs = ["thumb", "art"]
                    if item.Get("index") <> invalid then
                        title = "Episode " + item.Get("index")
                    else
                        title = item.GetOverlayTitle()
                    end if
                else
                    title = item.GetOverlayTitle()
                end if
                gridItem.ReInit(item, title, item.GetViewOffsetPercentage(), item.GetUnwatchedCount(), item.IsUnwatched())
            end if
            gridItem.SetThumbAttr(thumbAttrs)
            gridItem.plexObject = item
            gridItem.SetOrientation(m.orientation)
            gridItem.SetFocusable("show_item")

            ' update focused item if we are replacing the context
            if m.focusedItem <> invalid and m.focuseditem.equals(gridItem) then
                m.focusedItem = gridItem
                m.FocusItemManually(m.focusedItem)
            end if

            ' redraw the component, only within the loading area (ll_load*)
            if gridItem.IsOnScreen(0, 0, m.ll_loadX, m.ll_loadY) then
                gridItem.Draw()
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
    return (grid.loadStatus = invalid or grid.loadStatus = 2)
end function

sub gsOnFwdButton(item=invalid as dynamic)
    m.AdvancePage(1)
end sub

sub gsOnRevButton(item=invalid as dynamic)
    m.AdvancePage(-1)
end sub

sub gsAdvancePage(delta as integer)
    ' focus to the first of last item if current focus is fixed
    if m.focusedItem.fixed then
        delta = delta * -1
        total = m.shiftableComponents.Count() - 1
        loop = iif(delta > 0, { start: 0, finish: total }, { start: total, finish: 0 })
        for index = loop.start to loop.finish step delta
            if m.shiftableComponents[index].focusable = true then
                m.FocusItemManually(m.shiftableComponents[index], false)
                exit for
            end if
        end for

        return
    end if

    ' Locate the closest component 1 screen away
    xOffset = m.focusedItem.x + ( (m.displayWidth - m.xPadding*2) * delta)
    for each comp in m.shiftableComponents
        if comp.focusable = true then
            lastComponent = comp
            if delta > 0 and comp.x + comp.width >= xOffset then
                m.FocusItemManually(comp, false)
                return
            else if delta < 0 and comp.x >= xOffset then
                m.FocusItemManually(comp, false)
                return
            end if
        end if
    end for
    m.FocusItemManually(lastComponent, false)
end sub

sub gsRefresh(path=invalid as dynamic, stickyFocus=true as boolean)
    TextureManager().RemoveTextureByScreenId(m.screenID)
    m.CancelRequests()

    m.ResetInit(path)

    if stickyFocus then
        m.SetRefocusItem(m.focusedItem)
    else
        m.Delete("refocus")
    end if

    ' Close any overlay screen (drop downs)
    m.CloseOverlays()

    Application().ShowLoadingModal(m)

    ' Encourage some extra memory cleanup
    RunGC()

    m.Show()
end sub

sub gsResetInit(path=invalid as dynamic)
    m.DisableListeners(true)
    m.server = m.item.GetServer()

    ' Update the items key if path is specified
    if path <> invalid then
        m.item.Set("key", path)
    end if

    m.path = m.item.GetAbsolutePath("key")
    m.sectionPath = m.item.GetSectionPath()
    ' Retain the original path for use when refreshing/resetting
    if m.originalPath = invalid then
        m.originalPath = m.path
    end if

    m.gridContainer = CreateObject("roAssociativeArray")
    m.sortContainer = CreateObject("roAssociativeArray")
    m.jumpContainer = CreateObject("roAssociativeArray")
    m.placeholders = CreateObject("roList")
    m.jumpItems = CreateObject("roList")

    ' use a smaller chunk for the inital load size. This may need to vary
    ' depending on the grid type (artwork, poster)
    m.chunkSizeInitial = 16
end sub

' Use the jumpIndex to refocus a grid. It's unique and mostly accurate on refresh.
sub gsSetRefocusItem(item=invalid as dynamic, keys=["jumpIndex"])
    ApplyFunc(ComponentsScreen().SetRefocusItem, m, [item, keys])
end sub

sub gsOnSortResponse(request as object, response as object, context as object)
    response.ParseResponse()
    context.response = response

    ' Append the default sort to the path
    if instr(1, request.path, "sort=") = 0 then
        for each item in response.items
            if item.Has("default") then
                m.path = AddUrlParam(m.path, "sort=" + item.Get("key"))
                Debug("Added default sort: " + m.path)
                exit for
            end if
        end for
    end if

    m.Show()
end sub
