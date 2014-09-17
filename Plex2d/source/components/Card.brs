function CardClass() as object
    if m.CardClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoxClass())
        obj.ClassName = "Card"

        ' Methods
        obj.PerformLayout = CardPerformLayout

        m.CardClass = obj
    end if

    return m.CardClass
end function

function createCard() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.Init()

    obj.homogeneous = false
    obj.expand = false
    obj.fill = false
    obj.spacing = 0

    return obj
end function

sub cardPerformLayout()
    m.needsLayout = false
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    m.components.Reset()

    while m.components.IsNext()
        component = m.components.Next()

        component.SetFrame(m.x + component.offsetX, m.y + component.offsetY, component.width, component.height)
    end while
end sub
