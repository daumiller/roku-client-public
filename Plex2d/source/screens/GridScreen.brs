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
        obj.GetComponents = gsGetComponents
        obj.AfterItemFocused = gsAfterItemFocused

        ' Shifting Methods
        obj.CalculateShift = gsCalculateShift
        obj.ShiftComponents = gsShiftComponents
        obj.CalculateFirstOrLast = gsCalculateFirstOrLast

        ' Grid Methods
        obj.GetGridChunks = gsGetGridChunks
        obj.CreateGridChunk = gsCreateGridChunk
        obj.LoadGridChunk = gsLoadGridChunk
        obj.OnLoadGridChunk = gsOnLoadGridChunk
        obj.ChunkIsLoaded = gsChunkIsLoaded

        ' Description Box
        obj.DescriptionBox = gsDescriptionBox

        m.GridScreen = obj
    end if

    return m.GridScreen
end function

sub gsInit()
    ApplyFunc(ComponentsScreen().Init, m)

    m.gridContainer = CreateObject("roAssociativeArray")
    m.jumpContainer = CreateObject("roAssociativeArray")
    m.placeholders = CreateObject("roList")
    m.shiftableComponents = CreateObject("roList")

    ' lazy style loading. We might allow the user to modify this, but the different platforms
    ' seem to need a different style to make them work a little better. The Roku 3 is about
    ' the only platform that can keep up with background tasks without causing lag in the UI.
    ' 0: load after key release (non Roku 3)
    ' 1: load inline (Roku 3)
    if appSettings().GetGlobal("animationFull") then
        m.lazyStyle = 1
        m.chunkSize = 200
    else
        m.lazyStyle = 0
        m.chunkSize = 30
        m.chunkLoadLimit = 10
    end if

    ' use a smaller chunk for the inital load size. This may need to vary
    ' depending on the grid type (artwork, poster)
    m.chunkSizeInitial = 16
end sub

function createGridScreen(item as object, rows=2 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GridScreen())

    obj.Init()

    obj.item = item
    obj.server = item.container.server

    ' how should we handle these variables?
    obj.rows = rows
    obj.orientation = 1
    obj.spacing = 10
    obj.height = 450

    return obj
end function

sub gsShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create requests for the size of the endpoint
    if m.gridContainer.request = invalid then
        request = createPlexRequest(m.server, m.item.container.getAbsolutePath(m.item.Get("key")))
        request.AddHeader("X-Plex-Container-Start", "0")
        request.AddHeader("X-Plex-Container-Size", "0")

        context = request.CreateRequestContext("grid", createCallable("OnGridResponse", m))
        Application().StartRequest(request, context)
        m.gridContainer = context
    end if

    ' create requests for the size of the endpoint
    if m.jumpContainer.request = invalid then
        request = createPlexRequest(m.server, m.item.container.getAbsolutePath("firstCharacter"))
        context = request.CreateRequestContext("jump", createCallable("OnJumpResponse", m))
        Application().StartRequest(request, context)
        m.jumpContainer = context
    end if

    if m.gridContainer.response <> invalid and m.jumpContainer.response <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)

        ' obtain a list of the shiftable components now (cache it)
        for each component in m.components
            component.GetShiftableItems(m.shiftableComponents, m.shiftableComponents)
        end for
    end if
end sub

' Handle jump response (firstCharacter)
function gsOnJumpResponse(request as object, response as object, context as object) as object
    response.ParseResponse()
    context.response = response

    m.jump = createObject("roList")
    m.jumpKeys = {}
    incr = 0
    for each item in response.items
        m.jumpKeys[item.Get("key")] = m.jump.count()
        m.jump.push({
            index: incr,
            key: item.Get("key")
            title: item.Get("title")
            size: item.GetInt("size")
        })
        incr = incr + item.GetInt("size")
    end for
end function

' Handle initial response from the endpoint request
function gsOnGridResponse(request as object, response as object, context as object) as object
    response.ParseResponse()
    context.response = response

    m.totalSize = response.container.getint("totalSize")

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

sub gsGetComponents()
    m.components.Clear()
    m.focusedItem = invalid

    ' *** HEADER *** '
    m.components.Push(createHeader(m))

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
    hbJump = createHBox(false, false, false, 5)
    font = FontRegistry().font14
    btnHeight = font.getOneLineHeight()
    jumpWidth = 0
    for each jump in m.jump
        button = createButton(jump.title, font, "jump_button")
        button.SetColor(&hc0c0c0c0)
        button.width = btnHeight
        button.height = btnHeight
        button.SetMetadata(jump)
        hbJump.AddComponent(button)
        jumpWidth = jumpWidth + button.width + hbJump.spacing
    end for
    xOffset = int(1280/2 - jumpWidth/2)
    hbJump.SetFrame(xOffset, 120 + m.height, jumpWidth, 50)
    m.components.Push(hbJump)

    ' set the placement of the description box (manualComponent)
    m.DescriptionBox().setFrame(50, 630, 1280-50, 100)
end sub

function gsCreateGridChunk(placeholder as object) as dynamic
    if placeholder = invalid or placeholder.size = invalid then return invalid

    grid = createGrid(m.orientation, m.rows, m.spacing)
    grid.height = m.height

    ' set the properties needed to lazyload the chunk
    grid.placeholder = placeholder
    grid.loadStatus = 0

    for index = 0 to placeholder.size-1
        card = createCardPlaceholder()
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

function gsDescriptionBox() as object
    if m.GridDescriptionBox = invalid then
        obj = CreateObject("roAssociativeArray")

        ' default placement: use m.setFrame to override
        obj.x = 50
        obj.y = 630
        obj.width = 500
        obj.height = 100
        obj.spacing = 0

        ' default fonts/colors
        obj.line1 = { font: FontRegistry().font18b, color: Colors().TextClr}
        obj.line2 = { font: FontRegistry().font18, color: &hc0c0c0c0 }

        ' methods
        obj.SetFrame = compSetFrame
        obj.Show = gsDescriptionBoxShow
        obj.Hide = gsDescriptionBoxHide
        obj.IsDisplayed = function() : return (m.components.count() > 0) : end function

        m.GridDescriptionBox = obj
    end if

    ' Initialize the manual components outside
    m.GridDescriptionBox.components = m.GetManualComponents("GridDescriptionBox")

    return m.GridDescriptionBox
end function

function gsDescriptionBoxHide() as boolean
    pendingDraw = false
    if m.IsDisplayed() then
        pendingDraw = true
        for each comp in m.components
            comp.Destroy()
        end for
        m.components.clear()
    end if

    return pendingDraw
end function

function gsDescriptionBoxShow(item as object) as boolean
    pendingDraw = m.Hide()
    if item.plexObject = invalid then return pendingDraw

    ' *** Component Description *** '
    compDesc = createVBox(false, false, false, m.spacing)
    compDesc.SetFrame(m.x, m.y, m.width, m.height)

    label = createLabel(item.plexObject.getlongertitle(), m.line1.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.line1.color)
    compDesc.AddComponent(label)

    line2 = []
    line2.push(item.plexObject.GetOriginallyAvailableAt())
    if line2.peek()  = "" then
        line2.pop()
        line2.push(item.plexObject.GetAddedAt())
    end if
    line2.push(item.plexObject.GetDuration())
    if item.plexObject.type = "episode" then
        line2.unshift(item.plexObject.Get("title"))
    end if

    label = createLabel(joinArray(line2, " / "), m.line2.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.line2.color)
    compDesc.AddComponent(label)

    m.components.push(compDesc)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    return (pendingDraw or m.IsDisplayed())
end function

sub gsAfterItemFocused(item as object)
    if item.plexObject = invalid or item.plexObject.islibrarysection() then
        pendingDraw = m.DescriptionBox().Hide()
    else
        pendingDraw = m.DescriptionBox().Show(item)
    end if

    if pendingDraw then m.screen.DrawAll()
end sub

' ************ shifting ****************'
sub gsCalculateShift(toFocus as object)
    if toFocus.fixed = true then return

    ' load the grid chunk if the focused items chunk isn't loaded yet
    if m.lazyStyle = 1 and m.ChunkIsLoaded(tofocus.parent) = false then
        m.LoadGridChunk([tofocus.parent])
    end if

    ' TODO(rob) handle vertical shifting. revisit safeLeft/safeRight - we can't
    ' just assume these arbitary numbers are right.
    if m.shift = invalid then
        m.shift = {
            safeRight: 1230
            safeLeft: 50
            demandX: int( (1280/toFocus.width)/2) * toFocus.width
        }
    end if
    shift = { x: 0, y:0 }
    shift.Append(m.shift)

    ' shift the component so the "middle" if off screen
    focusRect = computeRect(toFocus)
    if focusRect.right > shift.safeRight then
        shift.x = (focusRect.left - shift.demandX) * -1
    else if focusRect.left < shift.safeLeft then
        shift.x = shift.demandX - focusRect.left
    end if

    if (shift.x <> 0 or shift.y <> 0) then
        TextureManager().CancelAll()
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
    m.LazyLoadExec(partShift)

    ' Calculate the FPS shift amount. 15 fps seems to be a workable arbitrary number.
    ' Verify the px shifting are > than the fps, otherwise it's sluggish (non Roku3)
    fps = 15
    if shift.x <> 0 and abs(shift.x / fps) < fps then
        fps = int(abs(shift.x / fps))
    else if shift.y <> 0 and abs(shift.y / fps) < fps then
        fps = int(abs(shift.y / fps))
    end if
    if fps = 0 then fps = 1

    ' TODO(rob) just a quick hack for slower roku's
    if appSettings().GetGlobal("animationFull") = false then fps = int(fps / 1.5)
    if fps = 0 then fps = 1

    if shift.x < 0 then
        xd = int((shift.x / fps) + .9)
    else if shift.x > 0 then
        xd = int(shift.x / fps)
    else
        xd = 0
    end if

    if shift.y < 0 then
        yd = int((shift.y / fps) + .9)
    else if shift.y > 0 then
        yd = int(shift.y / fps)
    else
        yd = 0
    end if

    ' total px shifted to verfy we shifted the exact amount (when shifting partially)
    xd_shifted = 0
    yd_shifted = 0

    ' TODO(rob) only animate shifts if on screen (or will be after shift)
    for x=1 To fps
        xd_shifted = xd_shifted + xd
        yd_shifted = yd_shifted + yd

        ' we need to make sure we shifted the shift_xd amount,
        ' since can't move pixel by pixel
        if x = fps then
            if xd_shifted <> shift.x then
                if xd < 0 then
                    xd = xd + (shift.x - xd_shifted)
                else
                    xd = xd + (shift.x - xd_shifted)
                end if
            end if
            if yd_shifted <> shift.y then
                if yd < 0 then
                    yd = yd + (shift.y - yd_shifted)
                else
                    yd = yd + (shift.y - yd_shifted)
                end if
            end if
        end if

        for each comp in partShift
            comp.ShiftPosition(xd, yd)
        end for
        ' draw each shift after all components are shifted
        m.screen.drawAll()
    end for
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
            ' TODO(rob): proper image transcoding + how we determine the correct image type to use

            attrs = item.attrs
            thumb = firstOfArr([attrs.grandparentThumb, attrs.parentThumb, attrs.thumb, attrs.art, attrs.composite, ""])
            image = { url: m.server.BuildUrl(thumb, true), server: m.server }

            ' reinit the card - set metadata and plexObject and focusability
            gridItem.ReInit(image, item.GetSingleLineTitle())
            gridItem.setMetadata(item.attrs)
            gridItem.plexObject = item
            gridItem.SetFocusable("card")

            ' update focused item if we are replacing the context
            if m.focuseditem.equals(gridItem) then
                m.focusedItem = gridItem
                m.OnItemFocused(m.focusedItem)
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

function gsCalculateFirstOrLast(components as object, shift as object) as integer
    minMax = {}
    for each comp in components
        focusRect = computeRect(comp)
        if minMax.right = invalid or focusRect.right > minMax.right then minMax.right = focusRect.right
        if minMax.left = invalid or focusRect.left < minMax.left then minMax.left = focusRect.left
    end for

    ' ALL Components fit on screen, ignore shifting.
    if minMax.right <= shift.safeRight and minMax.left >= shift.safeLeft then return 0

    minMax.right = minMax.right + shift.x
    minMax.left = minMax.left + shift.x
    if minMax.right < shift.safeRight then
        shift.x = shift.x - (minMax.right - shift.safeRight)
    else if minMax.left > shift.safeLeft then
        shift.x = shift.x + (shift.safeLeft - minMax.left)
    end if
    perfTimer().Log("verified first/last on-screen component offsets: left=" + tostr(minMax.left) + ", right=" + tostr(minMax.right))

    return shift.x
end function
