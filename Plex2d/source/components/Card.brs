function CardClass() as object
    if m.CardClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.ClassName = "Card"

        obj.alphaEnable = true

        ' Methods
        obj.Init = cardInit
        obj.PerformLayout = cardPerformLayout

        m.CardClass = obj
    end if

    return m.CardClass
end function

function createCard(imageSource as dynamic, text as string) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.Init(imageSource, text)

    ' TODO(schuyler): Lots, presumably. We need to expose some of the options
    ' of our children. Does the overlay have multiple lines of text? Does the
    ' image have a placeholder?

    return obj
end function

sub cardInit(imageSource as dynamic, text as string)
    ApplyFunc(CompositeClass().Init, m)

    m.image = createImage(imageSource)

    m.overlay = createLabel(text, FontRegistry().font16)
    m.overlay.SetPadding(10)
    m.overlay.SetColor(&hffffffff, &h000000e0)

    m.AddComponent(m.image)
    m.AddComponent(m.overlay)
end sub

sub cardPerformLayout()
    m.needsLayout = false

    ' Since we're a composite, the coordinates of our children are relative to
    ' our own x,y.

    m.image.SetFrame(0, 0, m.width, m.height)

    m.overlay.SetFrame(0, m.height - m.overlay.GetPreferredHeight(), m.width, m.overlay.GetPreferredHeight())
end sub
