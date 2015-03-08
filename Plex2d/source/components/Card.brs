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
        obj.SetThumbAttr = cardSetThumbAttr

        m.CardClass = obj
    end if

    return m.CardClass
end function

function createCard(imageSource as dynamic, text=invalid as dynamic, watchedPercentage=invalid as dynamic, unwatchedCount=invalid as dynamic, unwatched=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.Init(imageSource, text, watchedPercentage, unwatchedCount, unwatched)

    return obj
end function

function createCardPlaceholder(contentType=dynamic as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.bgcolor = Colors().Card

    obj.Init()

    return obj
end function

sub cardInit(imageSource=invalid as dynamic, text=invalid as dynamic, watchedPercentage=invalid as dynamic, unwatchedCount=invalid as dynamic, unwatched=false as boolean)
    ApplyFunc(CompositeClass().Init, m)

    m.innerBorderFocus = true

    m.overlayPadding =  {
        top: 5,
        right: 5,
        bottom: 5,
        left: 10,
    }
    m.unwatchedPadding = {
        top: 0,
        right: 6,
        bottom: 0,
        left: 6,
    }

    m.InitComponents(imageSource, text, watchedPercentage, unwatchedCount, unwatched)
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

    if m.unwatched <> invalid then
        m.unwatched.SetFrame(0, 0, m.width, m.unwatched.GetPreferredHeight())
    end if

    if m.unwatchedCount <> invalid then
        m.unwatchedCount.SetFrame(m.width - m.unwatchedCount.GetPreferredWidth(), 0, m.unwatchedCount.GetPreferredWidth(), m.unwatchedCount.GetPreferredHeight())
    end if

    if m.progress <> invalid and m.progress.percent > 0 then
        height = 5
        if m.overlay <> invalid then
            yPos = m.overlay.y - height
        else
            yPos = m.height - height
        end if
        m.progress.SetFrame(0, yPos , m.width, height)
    end if
end sub

' destroy and reinit the components for the card (lazy-loading)
sub cardReinit(imageSource=invalid as dynamic, text=invalid as dynamic, watchedPercentage=invalid as dynamic, unwatchedCount=invalid as dynamic, unwatched=false as boolean)
    m.DestroyComponents()
    m.InitComponents(imageSource, text, watchedPercentage, unwatchedCount, unwatched)
end sub

sub cardInitComponents(imageSource=invalid as dynamic, text=invalid as dynamic, watchedPercentage=invalid as dynamic, unwatchedCount=invalid as dynamic, unwatched=false as boolean)
    if imageSource <> invalid then
        m.image = createImage(imageSource)
        m.image.fixed = false
        m.AddComponent(m.image)
    end if

    if text <> invalid then
        m.overlay = createLabel(text, FontRegistry().NORMAL)
        m.overlay.SetPadding(m.overlayPadding.top, m.overlayPadding.right, m.overlayPadding.bottom, m.overlayPadding.left)
        m.overlay.SetColor(Colors().Text, Colors().OverlayDark)
        m.AddComponent(m.overlay)
    end if

    if watchedPercentage <> invalid and watchedPercentage > 0 then
        m.progress = createProgressBar(watchedPercentage, Colors().OverlayVeryDark , Colors().Orange)
        m.AddComponent(m.progress)
    else if unwatchedCount <> invalid and unwatchedCount > 0 then
        label = iif(unwatchedCount < 10, " " + tostr(unwatchedCount) + " ", tostr(unwatchedCount))
        m.unwatchedCount = createLabel(label, FontRegistry().NORMAL)
        m.unwatchedCount.SetPadding(m.unwatchedPadding.top, m.unwatchedPadding.right, m.unwatchedPadding.bottom, m.unwatchedPadding.left)
        border = cint(m.unwatchedCount.GetPreferredHeight() * .02)
        m.unwatchedCount.SetBorder(Colors().IndicatorBorder, 0, 0, border, border)
        m.unwatchedCount.SetColor(Colors().Text, Colors().Orange)
        m.unwatchedCount.valign = m.unwatchedCount.ALIGN_MIDDLE
        m.unwatchedCount.halign = m.unwatchedCount.JUSTIFY_CENTER
        m.AddComponent(m.unwatchedCount)
    else if unwatched then
        m.unwatched = createIndicator(Colors().Orange, FontRegistry().NORMAL.GetOneLineHeight())
        m.unwatched.valign = m.unwatched.ALIGN_TOP
        m.unwatched.halign = m.unwatched.JUSTIFY_RIGHT
        m.AddComponent(m.unwatched)
    end if

end sub

sub cardSetThumbAttr(thumbAttr=invalid as dynamic)
    if m.image <> invalid then
        m.image.thumbAttr = thumbAttr
    end if
end sub

sub cardSetOrientation(orientation as integer)
    ApplyFunc(CompositeClass().SetOrientation, m, [orientation])
    if m.image <> invalid then
        m.image.SetOrientation(orientation)
    end if
end sub
