function ComponentClass() as object
    if m.ComponentClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(EventsMixin())

        m.nextComponentId = 1

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
        obj.bgColor = Colors().ScrBkgClr
        obj.fgColor = Colors().TextClr

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
        obj.SetDimensions = compSetDimensions
        obj.SetFocusSibling = compSetFocusSibling
        obj.GetFocusSibling = compGetFocusSibling
        obj.SetFocusable = compSetFocusable
        obj.GetFocusableItems = compGetFocusableItems
        obj.Destroy = compDestroy
        obj.Unload = compUnload
        obj.SpriteIsLoaded = compSpriteIsLoaded

        ' shifting methods
        obj.ShiftPosition = compShiftPosition
        obj.GetShiftableItems = compGetShiftableItems
        obj.IsOnScreen = compIsOnScreen

        obj.ToString = compToString
        obj.Equals = compEquals

        m.ComponentClass = obj
    end if

    return m.ComponentClass
end function

sub componentInit()
    ' Assign a unique ID to all components
    m.id = GetGlobalAA()["nextComponentId"]
    GetGlobalAA().AddReplace("nextComponentId", m.id + 1)

    m.focusSiblings = {}
end sub

sub compInitRegion()
    perfTimer().mark()
    ' performance++ clear and resuse a region
    if m.region <> invalid then
        m.region.clear(m.bgColor)
        msg = "clear and reuse"
    else
        bmp = CreateObject("roBitmap", {width: m.width, height: m.height, alphaEnable: m.alphaEnable})
        bmp.Clear(m.bgColor)
        m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
        msg = "new bitmap/region"
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
        ' remove lazy load status if applicable, and retain any other keys
        if m.sprite.getData() <> invalid and m.sprite.getData().lazyLoad <> invalid then
            m.sprite.getData().lazyLoad = invalid
        end if
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
    m.x = x
    m.y = y
    m.width = width
    m.height = height
end sub

sub compSetPosition(x as integer, y as integer)
    m.x = x
    m.y = y
end sub

sub compShiftPosition(deltaX=0 as integer, deltaY=0 as integer, shiftSprite = true as boolean)
    ' ignore shifting fixed components
    if m.fixed = true then return

    ' set the componets new coords
    m.x = m.x + deltaX
    m.y = m.y + deltaY

    ' ignore shifting the sprite (normally off screen), and unload if applicable
    if shiftSprite = false then
        if m.sprite <> invalid and NOT m.IsOnScreen(0, 0, ComponentsScreen().ll_unload) then
            m.unload()
        end if
        return
    end if

    if m.sprite <> invalid then
        if m.IsOnScreen() then
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
    return m.focusSiblings[direction]
end function

function compToString() as string
    return tostr(m.ClassName) + " " + tostr(m.width) + "x" + tostr(m.height) + " at (" + tostr(m.x) + ", " + tostr(m.y) + ") id=" + tostr(m.id)
end function

function compEquals(other as object) as boolean
    return (m.id = other.id)
end function

sub compSetFocusable(command = invalid as dynamic)
    m.focusable = true
    m.selectable = (command <> invalid)
    m.command = command
end sub

sub compGetFocusableItems(arr as object)
    ' check if the component is focusable and on the screen (or off by a little)
    if m.focusable and m.IsOnScreen(0, 0, int(1280/4)) then
        arr.Push(m)
    end if
end sub

sub compGetShiftableItems(partShift as object, fullShift as object, lazyLoad=invalid as dynamic, deltaX=0 as integer, deltaY=0 as integer)
    ' all components are fixed by default. You must set fixed = false in
    ' either the Components Class or directly on the component
    if NOT(m.fixed = false) then return

    if lazyLoad <> invalid and lazyLoad.trigger = invalid and m.SpriteIsLoaded() = false and m.IsOnScreen(0, 0, ComponentsScreen().ll_trigger) then
        lazyLoad.trigger = true
    end if

    ' obtain a list of shiftable items, either on screen now, or on screen after the shifted amount
    if m.IsOnScreen() or m.IsOnscreen(deltaX, deltaY) then
        partShift.Push(m)
    else
        fullShift.Push(m)
    end if
end sub

' testing - used for shifting, unloading component from memory. We may be able to use
' the destory method, but I wanted something specific for now to unload.
'  @nest: is just for debug print
sub compUnload(nest=0 as integer)
    Debug(string(nest," ") + "-- unload component " + tostr(m))

    ' Clean any objects in memory (bitmaps, regions and sprites)
    m.region = invalid
    m.bitmap = invalid
    if m.sprite <> invalid then m.sprite.remove()
    m.sprite = invalid

    ' cancel any pending request
    if m.TextureRequest <> invalid then TextureManager().CancelTexture(m.TextureRequest)
    ' remove any associated texture
    if m.source <> invalid then TextureManager().RemoveTexture(m.source)

    ' iterate through any children
    if m.components <> invalid then
        for each comp in m.components
            comp.unload(nest+1)
        end for
    end if
end sub

sub compDestroy()
    ' Clean up anything that could result in circular references.
    m.Off(invalid, invalid)

    ' Clean any objects in memory (bitmaps, regions and sprites)
    m.region = invalid
    m.bitmap = invalid
    if m.sprite <> invalid then
        m.sprite.remove()
        m.sprite = invalid
    end if
    if m.components <> invalid then
        for each comp in m.components
            comp.destroy()
        end for
    end if
end sub

' TODO(rob) vertical check + HD2SD
function compIsOnScreen(deltaX=0 as integer, deltaY=0 as integer, safeOffset=0 as integer) as boolean
    rect = {
        x: m.x+deltaX
        y: m.y+deltaY
        width:  m.width
        height: m.height
    }
    rect = computeRect(rect)

    ' set the screens safe area (allow offset)
    screenLeft = 0 - safeOffset
    screenRight = 1280 + safeOffset

    if rect.right >= screenLeft and rect.left <= screenRight then
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

    ' not loaded if sprites data contains a lazyLoad key
    if m.sprite.getData() <> invalid and m.sprite.getData().lazyLoad = true then return false

    ' anything else we will consider loaded
    return true
end function
