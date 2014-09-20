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
    bmp = CreateObject("roBitmap", {width: m.width, height: m.height, alphaEnable: m.alphaEnable})
    bmp.Clear(m.bgColor)

    m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
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
    m.x = x
    m.y = y
    m.width = width
    m.height = height
end sub

sub compSetPosition(x as integer, y as integer)
    m.x = x
    m.y = y
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
    if m.focusable then
        arr.Push(m)
    end if
end sub

sub compDestroy()
    ' Clean up anything that could result in circular references.
    m.Off(invalid, invalid)

    ' Clean any objects in memory (bitmaps, regions and sprites)
    m.region = invalid
    m.bitmap = invalid
    m.sprite = invalid
    if m.components <> invalid then
        for each comp in m.components
            comp.destroy()
        end for
    end if
end sub
