function ComponentClass() as object
    if m.ComponentClass = invalid then
        obj = CreateObject("roAssociativeArray")

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
        obj.SetFocusSibling = compSetFocusSibling
        obj.GetFocusSibling = compGetFocusSibling
        obj.SetFocusable = compSetFocusable

        obj.ToString = compToString

        m.ComponentClass = obj
    end if

    return m.ComponentClass
end function

sub componentInit()
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
    if m.sprite <> invalid then
        ' TODO(schuyler): Is this the clever solution or a hack?
        m.sprite.SetDrawableFlag(true)
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
    return tostr(m.ClassName) + " " + tostr(m.width) + "x" + tostr(m.height) + " at (" + tostr(m.x) + ", " + tostr(m.y) + ")"
end function

sub compSetFocusable(command = invalid as dynamic)
    m.focusable = true
    m.selectable = (command <> invalid)
    m.command = command
end sub
