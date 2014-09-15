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

        m.AlignmentMixin = obj
    end if

    return m.AlignmentMixin
end function
