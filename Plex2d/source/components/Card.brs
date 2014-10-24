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

function createCard(imageSource as dynamic, text=invalid as dynamic, watchedPercentage=invalid as dynamic, unwatchedCount=invalid as dynamic, unwatched=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.Init(imageSource, text, watchedPercentage, unwatchedCount, unwatched)

    ' TODO(schuyler): Lots, presumably. We need to expose some of the options
    ' of our children. Does the overlay have multiple lines of text? Does the
    ' image have a placeholder?

    return obj
end function

function createCardPlaceholder() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardClass())

    obj.bgcolor = Colors().CardBkgClr

    obj.Init()

    return obj
end function

sub cardInit(imageSource=invalid as dynamic, text=invalid as dynamic, watchedPercentage=invalid as dynamic, unwatchedCount=invalid as dynamic, unwatched=false as boolean)
    ApplyFunc(CompositeClass().Init, m)
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
        m.unwatched.SetFrame(0, m.height - m.unwatched.GetPreferredHeight(), m.width, m.unwatched.GetPreferredHeight())
    end if

    if m.unwatchedCount <> invalid then
        if m.overlay <> invalid then
            yPos = int(m.overlay.y + (m.overlay.height/2 - m.unwatchedCount.GetPreferredHeight()/2))
        else
            yPos = m.height - m.unwatchedCount.GetPreferredHeight() - 5
        end if
        m.unwatchedCount.SetFrame(m.width - m.unwatchedCount.GetPreferredWidth() - 5, yPos, m.unwatchedCount.GetPreferredWidth(), m.unwatchedCount.GetPreferredHeight())
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
        m.AddComponent(m.image)
    end if

    if text <> invalid then
        m.overlay = createLabel(text, FontRegistry().font16)
        m.overlay.SetPadding(5, 5, 5, 10)
        m.overlay.SetColor(&hffffffff, Colors().ScrDrkOverlayClr)
        m.AddComponent(m.overlay)
    end if

    if watchedPercentage <> invalid and watchedPercentage > 0 then
        m.progress = createProgressBar(watchedPercentage, Colors().ScrVeryDrkOverlayClr , Colors().PlexAltClr)
        m.AddComponent(m.progress)
    end if

    if unwatchedCount <> invalid and unwatchedCount > 0 then
        m.unwatchedCount = createLabel(tostr(unwatchedCount), FontRegistry().font16)
        m.unwatchedCount.SetPadding(0, 5, 0, 5)
        m.unwatchedCount.SetColor(&hffffffff, Colors().PlexAltClr)
        m.AddComponent(m.unwatchedCount)
    else if unwatched then
        m.unwatched = createIndicator(Colors().PlexAltClr, FontRegistry().font16.GetOneLineHeight(), 10)
        m.AddComponent(m.unwatched)
    end if

end sub

sub cardSetOrientation(orientation as integer)
    ApplyFunc(CompositeClass().SetOrientation, m, [orientation])
    if m.image <> invalid then
        m.image.SetOrientation(orientation)
    end if
end sub
