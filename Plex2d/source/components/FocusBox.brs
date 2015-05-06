function FocusBoxClass() as object
    if m.FocusBoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoxClass())
        obj.ClassName = "FocusBox"

        ' Methods
        obj.PerformLayout = focusboxPerformLayout

        ' Constants
        obj.homogeneous = false
        obj.expand = false
        obj.fill = false
        obj.spacing = 0
        obj.resizable = false

        m.FocusBoxClass = obj
    end if

    return m.FocusBoxClass
end function

function createFocusBox(x as integer, y as integer, width as integer, height as integer, isVisible=false as boolean)
    obj = CreateObject("roAssociativeArray")
    obj.Append(FocusBoxClass())

    obj.Init()

    obj.SetFrame(x, y, width, height)
    obj.SetFocusManual()
    obj.isVisible = isVisible

    return obj
end function

sub focusboxPerformLayout()
    m.needsLayout = false

    ' Show the focus box to debug placement
    if m.isVisible then
        m.DestroyComponents()
        comp = createBlock(Colors().Orange)
        comp.SetFrame(m.x, m.y, m.width, m.height)
        m.components.Push(comp)
    end if
end sub
