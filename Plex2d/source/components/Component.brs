function ComponentClass() as object
    if m.ComponentClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(EventsMixin())
        obj.Append(ListenersMixin())

        m.nextComponentId = 1
        m.uniqComponentId = 1

        ' STATIC
        obj.ORIENTATION_SQUARE = 0
        obj.ORIENTATION_PORTRAIT = 1
        obj.ORIENTATION_LANDSCAPE = 2

        ' Properties
        obj.x = 0
        obj.y = 0
        obj.width = 0
        obj.height = 0
        obj.offsetX = 0
        obj.offsetY = 0
        obj.preferredWidth = invalid
        obj.preferredHeight = invalid

        obj.alphaEnable = false
        obj.bgColor = Colors().Background
        obj.fgColor = Colors().Text

        obj.focusable = false
        obj.selectable = false
        obj.command = invalid

        obj.fixed = true

        ' Methods
        obj.Init = componentInit
        obj.InitRegion = compInitRegion
        obj.Draw = compDraw
        obj.Redraw = compRedraw
        obj.GetPreferredWidth = compGetPreferredWidth
        obj.GetPreferredHeight = compGetPreferredHeight
        obj.GetContentArea = compGetContentArea
        obj.SetFrame = compSetFrame
        obj.SetPosition = compSetPosition
        obj.SetVisibility = compSetVisibility
        obj.SetVisible = compSetVisible
        obj.SetDimensions = compSetDimensions
        obj.SetFocusSibling = compSetFocusSibling
        obj.GetFocusSibling = compGetFocusSibling
        obj.SetFocusable = compSetFocusable
        obj.ToggleFocusable = compToggleFocusable
        obj.GetFocusableItems = compGetFocusableItems
        obj.Destroy = compDestroy
        obj.DestroyComponents = compDestroyComponents
        obj.Unload = compUnload
        obj.SpriteIsLoaded = compSpriteIsLoaded
        obj.SetMetadata = compSetMetadata
        obj.GetWidthForOrientation = compGetWidthForOrientation

        ' no-op methods
        obj.OnBlur = function(arg=invalid) : Verbose("OnBlur:no-op") : end function
        obj.OnFocus = function() : Verbose("OnFocus:no-op") : end function

        ' shifting methods
        obj.ShiftPosition = compShiftPosition
        obj.GetShiftableItems = compGetShiftableItems
        obj.IsOnScreen = compIsOnScreen

        obj.ToString = compToString
        obj.Equals = compEquals

        obj.IsPendingTexture = compIsPendingTexture

        obj.SetOrientation = compSetOrientation

        m.ComponentClass = obj
    end if

    return m.ComponentClass
end function

sub componentInit()
    ' Assign a unique ID to all components (per screen)
    m.id = GetGlobalAA()["nextComponentId"]
    GetGlobalAA().AddReplace("nextComponentId", m.id + 1)

    m.uniqId = GetGlobalAA()["uniqComponentId"]
    GetGlobalAA().AddReplace("uniqComponentId", m.uniqId + 1)

    m.focusSiblings = {}
end sub

sub compInitRegion()
    perfTimer().mark()
    if m.region <> invalid then
        m.region.clear(m.bgColor)
        msg = "clear and reuse"
    else
        bmp = CreateObject("roBitmap", {width: m.width, height: m.height, alphaEnable: m.alphaEnable})
        bmp.Clear(m.bgColor)
        m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
        msg = "new bitmap/region"
    end if

    if m.roundedCorners = true then
        ' Create the rounded corner bitmap (only one is required)
        cbmp = CreateObject("roBitmap", { width: 8, height: 8, alphaEnable: false})
        cbmp.Clear(m.bgColor)
        cbmp.DrawRect(0, 0, 6, 1, Colors().Transparent)
        cbmp.DrawRect(0, 1, 4, 1, Colors().Transparent)
        cbmp.DrawRect(0, 2, 3, 1, Colors().Transparent)
        cbmp.DrawRect(0, 3, 2, 1, Colors().Transparent)
        cbmp.DrawRect(0, 4, 1, 1, Colors().Transparent)
        cbmp.DrawRect(0, 5, 1, 1, Colors().Transparent)
        cbmp.DrawRect(6, 0, 1, 1, Colors().GetAlpha(m.bgColor, 50))
        cbmp.DrawRect(7, 0, 1, 1, Colors().GetAlpha(m.bgColor, 70))
        cbmp.DrawRect(8, 0, 1, 1, Colors().GetAlpha(m.bgColor, 90))
        cbmp.DrawRect(4, 1, 1, 1, Colors().GetAlpha(m.bgColor, 40))
        cbmp.DrawRect(5, 1, 1, 1, Colors().GetAlpha(m.bgColor, 90))
        cbmp.DrawRect(3, 2, 1, 1, Colors().GetAlpha(m.bgColor, 70))
        cbmp.DrawRect(2, 3, 1, 1, Colors().GetAlpha(m.bgColor, 70))
        cbmp.DrawRect(1, 4, 1, 1, Colors().GetAlpha(m.bgColor, 50))
        cbmp.DrawRect(1, 5, 1, 1, Colors().GetAlpha(m.bgColor, 95))
        cbmp.DrawRect(0, 6, 1, 1, Colors().GetAlpha(m.bgColor, 50))
        cbmp.DrawRect(0, 7, 1, 1, Colors().GetAlpha(m.bgColor, 70))
        cbmp.DrawRect(0, 8, 1, 1, Colors().GetAlpha(m.bgColor, 90))

        ' Draw the rounded bitmap to each corner or the region (rotate on the fly)
        m.region.DrawRotatedObject(0, 0, 0, cbmp)
        m.region.DrawRotatedObject(m.region.GetWidth(), 0, 270, cbmp)
        m.region.DrawRotatedObject(m.region.GetWidth(), m.region.GetHeight(), 180, cbmp)
        m.region.DrawRotatedObject(0, m.region.GetHeight(), 90, cbmp)
    end if

    PerfTimer().Log("compInitRegion:: " + msg + " " + tostr(m.region.getWidth()) + "x" + tostr(m.region.getHeight()))
end sub

function compDraw() as object
    m.InitRegion()

    return [m]
end function

sub compRedraw()
    ' If our component was rendered directly into a sprite, then we may be
    ' asked to redraw ourselves into that sprite. If we're part of a more
    ' complicated composite then this shouldn't be called, but we'll notice
    ' that we don't have a sprite and simply do nothing.

    if m.sprite <> invalid then
        m.sprite.SetRegion(m.region)
        CompositorScreen().DrawAll()
    end if
end sub

function compGetPreferredWidth() as integer
    return firstOf(m.preferredWidth, m.width)
end function

function compGetPreferredHeight() as integer
    return firstOf(m.preferredHeight, m.height)
end function

function compGetContentArea() as object
    if m.contentArea = invalid then
        m.contentArea = {
            x: 0,
            y: 0,
            width: m.width,
            height: m.height
        }
    end if

    return m.contentArea
end function

sub compSetFrame(x as integer, y as integer, width as integer, height as integer)
    m.SetPosition(x, y)
    m.SetDimensions(width, height)
end sub

sub compSetPosition(x as integer, y as integer)
    m.x = x
    m.y = y
    m.origX = x
    m.origY = y

    ' move the sprite components sprite if applicable
    if m.sprite <> invalid and (m.x <> m.sprite.GetX() or m.y <> m.sprite.GetY()) then
        m.sprite.moveTo(m.x, m.y)
    end if
end sub

sub compSetVisible(visible=true as boolean)
    if m.sprite = invalid then return

    if visible then
        zOrder = firstOf(m.zOrder, 1)
    else
        zOrder = -1
    end if

    if m.sprite.GetZ() <> zOrder then
        m.sprite.SetZ(zOrder)
    end if
end sub

sub compSetVisibility(left=invalid as dynamic, right=invalid as dynamic, up=invalid as dynamic, down=invalid as dynamic)
    if m.sprite = invalid then return
    rect = computeRect(m)

    if left <> invalid and rect.left < left then
        m.sprite.SetZ(-1)
        return
    end if

    if right <> invalid and rect.right > right then
        m.sprite.SetZ(-1)
        return
    end if

    if up <> invalid and rect.up < up then
        m.sprite.SetZ(-1)
        return
    end if

    if down <> invalid and rect.down > down then
        m.sprite.SetZ(-1)
        return
    end if

    m.SetVisible(true)
end sub

sub compShiftPosition(deltaX=0 as integer, deltaY=0 as integer, shiftSprite=true as boolean)
    ' ignore shifting fixed components
    if m.fixed = true or (m.fixedVertical = true and m.fixedHorizontal = true) then return

    ' ignore vertical shift
    if m.fixedVertical = true then deltaY = 0

    ' ignore horizontal shift
    if m.fixedHorizontal = true then deltaX = 0

    ' set the components new coords
    m.x = m.x + deltaX
    m.y = m.y + deltaY

    ' ignore shifting the sprite (normally off screen), and unload if applicable
    if shiftSprite = false then
        if m.sprite <> invalid and NOT m.IsOnScreen(0, 0, ComponentsScreen().ll_unloadX, ComponentsScreen().ll_unloadY) then
            m.Unload()
        end if
        return
    end if

    if m.sprite <> invalid then
        ' Ignore setting zOrder for scrollable parents. e.g. VBOX vertical
        ' scroll. Just move the sprite as the parent handles visibility.
        parent = firstOf(m.shiftableParent, m.parent)
        if parent <> invalid and parent.isVScrollable = true then
            m.sprite.moveTo(m.x, m.y)
        else if m.IsOnScreen() then
            m.sprite.moveTo(m.x, m.y)
            ' TODO(rob) we should be using the components orig zOrder? (n/a)
            if m.sprite.getZ() < 0 then m.sprite.setZ(1)
        else
            ' hide the sprite (off screen), do not render, but still in memory
            if m.sprite.getZ() > -1 then m.sprite.setZ(-1)
        end if
    end if

    ' note lazy-loading is done after shifPosition (compShiftComponents)
end sub

sub compSetDimensions(width as integer, height as integer)
    m.width = width
    m.height = height
end sub

sub compSetFocusSibling(direction as string, component as dynamic)
    if component <> invalid then
        m.focusSiblings[direction] = component
    else
        m.focusSiblings.Delete(direction)
    end if
end sub

function compGetFocusSibling(direction as string) as dynamic
    if m.focusSiblings[direction] <> invalid and m.focusSiblings[direction].focusable = true then
        return m.focusSiblings[direction]
    end if
    return invalid
end function

function compToString() as string
    return tostr(m.ClassName) + " " + tostr(m.width) + "x" + tostr(m.height) + " at (" + tostr(m.x) + ", " + tostr(m.y) + ") id=" + tostr(m.id)
end function

function compEquals(other=invalid as dynamic) as boolean
    return (other <> invalid and m.uniqId = other.uniqId)
end function

sub compSetFocusable(command=invalid as dynamic, focusable=true as boolean)
    m.focusable = focusable
    m.selectable = (command <> invalid)
    m.command = command
end sub

sub compGetFocusableItems(arr as object)
    ' check if the component is focusable and on the screen (or off by a little)
    if m.focusable and m.IsOnScreen(0, 0, int(AppSettings().GetWidth()/4)) then
        arr.Push(m)
    end if
end sub

sub compGetShiftableItems(partShift as object, fullShift as object, lazyLoad=invalid as dynamic, deltaX=0 as integer, deltaY=0 as integer)
    ' all components are fixed by default. You must set fixed = false in
    ' either the Components Class or directly on the component
    if m.fixed <> false then return

    if lazyLoad <> invalid and lazyLoad.trigger = invalid and m.SpriteIsLoaded() = false and m.IsOnScreen(0, 0, ComponentsScreen().ll_triggerX, ComponentsScreen().ll_triggerY) then
        lazyLoad.trigger = true
    end if

    ' obtain a list of shiftable items, either on screen now, or on screen after the shifted amount
    ' any sprite with a zOrder > -1 is considered onScreen (this is quick)

    if deltaX = 0 and deltaY = 0 then
        if m.sprite <> invalid and m.sprite.GetZ() > -1 then
            partShift.Push(m)
        else
            fullShift.Push(m)
        end if
    else
        if m.sprite <> invalid and m.sprite.GetZ() > -1 then
            partShift.Push(m)
        else if m.IsOnscreen(deltaX, deltaY) then
            partShift.Push(m)
        else
            fullShift.Push(m)
        end if
    end if
end sub

' testing - used for shifting, unloading component from memory. We may be able to use
' the destory method, but I wanted something specific for now to unload.
'  @nest: is just for debug print
sub compUnload(nest=0 as integer)
    ' Ignore fixed components, but only at the first layer. E.G. we still want to unload
    ' all children of a non-fixed components. Use destroy() to "unload" fixed components
    ' TODO(rob): I need to reevaluated this. We should unload any component, regardless of
    ' being fixed or not. This must of been a (incorrect) workaround to some issue.
    if m.fixed = true and nest = 0 then return

    Verbose(string(nest, " ") + "Unload component " + tostr(m))

    ' Clean any objects in memory (bitmaps, regions and sprites)
    m.bitmap = invalid
    if m.isSharedRegion <> true then
        m.region = invalid
    end if
    if m.sprite <> invalid then
        m.sprite.Remove()
        m.sprite = invalid
    end if

    ' cancel any pending request
    TextureManager().CancelTexture(m.TextureRequest)
    ' remove any associated texture
    TextureManager().RemoveTexture(m.source)

    ' iterate through any children
    if m.components <> invalid then
        for each comp in m.components
            comp.Unload(nest + 1)
        end for
    end if
end sub

sub compDestroy()
    ' Clean up anything that could result in circular references.
    m.Off(invalid, invalid)
    m.DisableListeners()

    ' Clean any objects in memory (bitmaps, regions, sprites and fonts)
    m.font = invalid
    m.bitmap = invalid
    m.region = invalid
    if m.sprite <> invalid then
        m.sprite.Remove()
        m.sprite = invalid
    end if

    if m.customFonts <> invalid then
        m.customFonts.Clear()
    end if

    if m.components <> invalid then
        for each comp in m.components
            comp.destroy()
        end for
    end if
end sub

function compIsOnScreen(deltaX=0 as integer, deltaY=0 as integer, safeXOffset=0 as integer, safeYOffset=0) as boolean
    rect = {
        x: m.x + deltaX
        y: m.y + deltaY
        width:  m.width
        height: m.height
    }
    rect = computeRect(rect)

    ' set the screens safe area (allow offset)
    displaySize = AppSettings().GetGlobal("displaySize")
    screenLeft = safeXOffset * -1
    screenRight = displaySize.w + safeXOffset
    screenUp = safeYOffset * -1
    screenDown = displaySize.h + safeYOffset

    ' Verify the opposite side of the safe area is within range
    if rect.right >= screenLeft and rect.left <= screenRight and rect.down >= screenUp and rect.up <= screenDown then
        return true
    else
        return false
    end if
end function

' quick and easy check to know if the components sprite is loaded
' useful for lazy loading images/composites
function compSpriteIsLoaded() as boolean
    ' not loaded if sprite is invalid
    if m.sprite = invalid return false

    ' check if any child component is loading
    if m.IsPendingTexture() then return false

    ' anything else we will consider loaded
    return true
end function

' TODO(schuyler): This is (at least sometimes?) being used to keep a copy of a
' PlexObject's attributes. Should we just keep a reference to the PlexObject
' instead?
sub compSetMetadata(metadata=invalid as dynamic)
    m.metadata = metadata
end sub

function compIsPendingTexture() as boolean
    return (m.pendingTexture = true)
end function

sub compSetOrientation(orientation as integer)
    m.orientation = orientation
end sub

function compGetWidthForOrientation(orientation as integer, height as integer) as integer
    if orientation = m.ORIENTATION_SQUARE then
        return height
    else if orientation = m.ORIENTATION_LANDSCAPE then
        return int(height * 1.777)
    else if orientation = m.ORIENTATION_PORTRAIT then
        return int(height * 0.679)
    else
        Fatal("Unknown hub orientation: " + tostr(orientation))
    end if
end function

sub compToggleFocusable(visible=true as boolean)
    if not visible and m.focusable = true then
        m.SetFocusable(m.command, visible)
        m.wasFocusable = true
    else if visible and m.wasFocusable = true then
        m.SetFocusable(m.command, visible)
    end if
end sub
