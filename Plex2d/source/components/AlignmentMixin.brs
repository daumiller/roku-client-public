function AlignmentMixin() as object
    if m.AlignmentMixin = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.ALIGN_TOP = 0
        obj.ALIGN_MIDDLE = 1
        obj.ALIGN_BOTTOM = 2
        obj.JUSTIFY_LEFT = 0
        obj.JUSTIFY_CENTER = 1
        obj.JUSTIFY_RIGHT = 2

        ' Properties
        obj.halign = obj.JUSTIFY_LEFT
        obj.valign = obj.ALIGN_TOP

        ' Methods
        obj.GetXOffsetAlignment = alignGetXOffsetAlignment
        obj.GetYOffsetAlignment = alignGetYOffsetAlignment

        m.AlignmentMixin = obj
    end if

    return m.AlignmentMixin
end function

function alignGetXOffsetAlignment(displayWidth as integer) as integer
    contentArea = m.GetContentArea()

    if m.halign = m.JUSTIFY_CENTER then
        return int((m.width - displayWidth) / 2)
    else if m.halign = m.JUSTIFY_RIGHT then
        return contentArea.width - displayWidth + contentArea.x
    else
        return contentArea.x
    end if
end function

function alignGetYOffsetAlignment(displayHeight as integer) as integer
    contentArea = m.GetContentArea()

    if m.valign = m.ALIGN_MIDDLE then
        return int((m.height - displayHeight) / 2)
    else if m.valign = m.ALIGN_BOTTOM then
        return contentArea.height - displayHeight + contentArea.y
    else
        return contentArea.y
    end if
end function
