function ScrollbarClass()
    if m.ScrollbarClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "Scrollbar"

        obj.Move = scrollbarMove
        obj.Show = scrollbarShow
        obj.Hide = scrollbarHide

        m.ScrollbarClass = obj
    end if

    return m.ScrollbarClass
end function

function createScrollbar(yOffset as object, contentHeight as integer, containerHeight as integer, visZOrder=999 as integer) as object
    ' TODO(rob): use a custom image, or some better non blocky scrollbar
    obj = createBlock(&hffffff30)
    obj.Append(ScrollbarClass())

    obj.yOffset = yOffset
    obj.contentHeight = contentHeight - yOffset
    obj.containerHeight = containerHeight - yOffset
    obj.height = obj.contentHeight * obj.contentHeight / obj.containerHeight
    obj.zOrderInit = -1
    obj.visZOrder = visZOrder

    return obj
end function

sub scrollbarMove(toFocus as object, delta=0 as integer)
    if m.delta = invalid then m.delta = 0
    m.delta = m.delta + delta

    rect = computeRect(toFocus)
    focusY = rect.up + rect.height/2 - m.yOffset + m.delta*-1
    m.y = (focusY / m.containerHeight) * (m.contentHeight - m.height) + m.yOffset
    if m.sprite <> invalid then
        m.sprite.moveTo(m.x, m.y)
    end if
end sub

sub scrollbarHide()
    if m.sprite <> invalid then
        m.sprite.setZ(-1)
    end if
end sub

sub scrollbarShow()
    if m.sprite <> invalid then
        m.sprite.setZ(m.visZOrder)
    end if
end sub
