function CardClass() as object
    if m.CardClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.ClassName = "Card"

        obj.alphaEnable = true

        ' Methods
        obj.Init = cardInit
        obj.Reinit = cardReinit
        obj.InitComponents = cardInitComponents
        obj.PerformLayout = cardPerformLayout
        obj.SetOrientation = cardSetOrientation

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

function createCardPlaceholder() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.bgcolor = Colors().CardBkgClr

    obj.Init(invalid, invalid)

    return obj
end function

sub cardInit(imageSource=invalid as dynamic, text=invalid as dynamic)
    ApplyFunc(CompositeClass().Init, m)
    m.InitComponents(imageSource, text)
end sub

sub cardPerformLayout()
    m.needsLayout = false

    ' Since we're a composite, the coordinates of our children are relative to
    ' our own x,y.

    if m.image <> invalid then
        m.image.SetFrame(0, 0, m.width, m.height)
    end if

    if m.overlay <> invalid then
        m.overlay.SetFrame(0, m.height - m.overlay.GetPreferredHeight(), m.width, m.overlay.GetPreferredHeight())
    end if
end sub

' destroy and reinit the components for the card (lazy-loading)
sub cardReinit(imageSource=invalid as dynamic, text=invalid as dynamic)
    for each component in m.components
        component.destroy()
    end for
    m.components.clear()
    m.InitComponents(imageSource, text)
end sub

sub cardInitComponents(imageSource=invalid as dynamic, text=invalid as dynamic)
    if imageSource <> invalid then
        m.image = createImage(imageSource)
        m.AddComponent(m.image)
    end if

    if text <> invalid then
        m.overlay = createLabel(text, FontRegistry().font16)
        m.overlay.SetPadding(10)
        m.overlay.SetColor(&hffffffff, &h000000e0)
        m.AddComponent(m.overlay)
    end if
end sub

sub cardSetOrientation(orientation as integer)
    ApplyFunc(CompositeClass().SetOrientation, m, [orientation])
    if m.image <> invalid then
        m.image.SetOrientation(orientation)
    end if
end sub
