function PaddingMixin() as object
    if m.PaddingMixin = invalid then
        obj = CreateObject("roAssociativeArray")

        ' obj.padding will be set as necessary

        ' Methods
        obj.SetPadding = paddingSetPadding
        obj.GetContentArea = paddingGetContentArea

        m.PaddingMixin = obj
    end if

    return m.PaddingMixin
end function

sub paddingSetPadding(pTop as integer, pRight=invalid as dynamic, pBottom=invalid as dynamic, pLeft=invalid as dynamic)
    ' Order of parameters and default values is borrowed from CSS.
    pRight = firstOf(pRight, pTop)
    pBottom = firstOf(pBottom, pTop)
    pLeft = firstOf(pLeft, pRight)

    m.padding = {
        left: pLeft,
        right: pRight,
        top: pTop,
        bottom: pBottom
    }

    m.contentArea = invalid
end sub

function paddingGetContentArea() as object
    if m.contentArea = invalid then
        if m.padding = invalid then
            m.padding = {left: 0, right: 0, top: 0, bottom: 0}
        end if

        m.contentArea = {
            x: m.padding.left,
            y: m.padding.top,
            width: m.width - m.padding.left - m.padding.right,
            height: m.height - m.padding.top - m.padding.bottom
        }
    end if

    return m.contentArea
end function
