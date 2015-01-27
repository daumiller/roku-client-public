function ScrollbarClass()
    if m.ScrollbarClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "Scrollbar"

        obj.Show = scrollbarShow
        obj.Draw = scrollbarDraw
        obj.Move = scrollbarMove
        obj.Hide = scrollbarHide

        m.ScrollbarClass = obj
    end if

    return m.ScrollbarClass
end function

function createScrollbar(yOffset as object, contentHeight as integer, containerHeight as integer, zOrder=ZOrders().SCROLLBAR as integer, offset=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ScrollbarClass())

    obj.Init()

    obj.fgColor = Colors().ScrollbarFg
    obj.bgColor = Colors().ScrollbarBg

    obj.yOffset = yOffset
    obj.contentHeight = contentHeight - yOffset
    obj.containerHeight = containerHeight - yOffset
    obj.scrollbarHeight = obj.contentHeight * obj.contentHeight / obj.containerHeight
    obj.height = obj.contentHeight

    obj.scrollbarY = 0
    obj.offset = iif(offset = invalid, 0, offset)
    obj.zOrder = zOrder
    obj.zOrderInit = -1

    ' Default shifting rules
    obj.fixed = true
    obj.fixedVertical = true
    obj.fixedHorizontal = true

    return obj
end function

function scrollbarDraw() as object
    ApplyFunc(ComponentClass().Draw, m)
    m.region.DrawRect(0, m.scrollbarY, m.width, m.scrollbarHeight, m.fgColor)

    return [m]
end function

sub scrollbarMove(toFocus as object, isFirst=false as boolean, isLast=false as boolean)
    if m.sprite = invalid then return

    if isFirst then
        m.scrollbarY = 0
    else if isLast then
        m.scrollbarY = m.contentHeight - m.scrollbarHeight
    else
        focusY = toFocus.origY + (toFocus.height/2) - m.yOffset
        m.scrollbarY = int((focusY / (m.containerHeight-m.offset)) * (m.contentHeight - m.scrollbarHeight))
    end if

    m.Draw()
end sub

sub scrollbarHide()
    if m.sprite <> invalid then
        m.sprite.setZ(-1)
    end if
end sub

sub scrollbarShow()
    if m.sprite <> invalid then
        m.sprite.setZ(m.zOrder)
    end if
end sub
