' TODO(rob): Generalize this, maybe ContextListItem as Schuyler mentioned.
' I think we might prefer to have separate methods to create the list item
' as well.
'
function TrackClass() as object
    if m.TrackClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.ClassName = "Track"

        obj.alphaEnable = false

        ' Methods
        obj.Init = trackInit
        obj.InitComponents = trackInitComponents
        obj.PerformLayout = trackPerformLayout
        obj.SetPlaying = trackSetPlaying
        obj.SetIndex = trackSetIndex
        obj.AdvanceIndex = trackAdvanceIndex
        obj.AddSeparator = trackAddSeparator

        m.TrackClass = obj
    end if

    return m.TrackClass
end function

function createTrack(item as object, titleFont as object, subtitleFont as object, glyphFont as object, trackCount=1 as integer, isMixed=false as boolean, isSeason=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(TrackClass())

    obj.plexObject = item
    obj.bgColor = (Colors().Text and &hffffff00)
    obj.isPlaying = false
    obj.isPaused = false
    obj.trackCount = trackCount
    obj.isMixed = isMixed
    obj.isSeason = isSeason
    obj.innerBorderFocus = true

    obj.Init(titleFont, subtitleFont, glyphFont)

    return obj
end function

sub trackInit(titleFont as object, subtitleFont as object, glyphFont=invalid as dynamic)
    ApplyFunc(CompositeClass().Init, m)

    ' These need to be references, otherwise it will reserve a chunk
    ' of memory per font for every track
    m.customFonts = {
        index: FontRegistry().LARGE,
        title: titleFont,
        subtitle: subtitleFont,
        glyph: glyphFont,
    }

    m.padding =  {
        top: 0,
        right: 5,
        bottom: 0,
        left: 5,
    }

    m.InitComponents()
end sub

sub trackSetIndex(index as integer, redraw=false as boolean)
    if m.index.text = tostr(index) then return

    ' Only redraw/resize during SetText if we have a region
    reinit = (m.index.region <> invalid)
    m.index.SetText(tostr(index), reinit, reinit)

    if redraw then m.Draw()
end sub

sub trackAdvanceIndex(delta=1 as integer, redraw=false as boolean)
    ' Index is changing, so we must redraw/resize during SetText
    m.index.SetText(tostr(m.index.text.toInt() + delta), true, true)

    if redraw then m.Draw()
end sub

sub trackSetPlaying(playing=true as boolean)
    m.isPlaying = playing
    m.isPaused = AudioPlayer().isPaused

    draw = (m.region <> invalid)

    ' Set the composites background color to anti-alias.
    if m.isPlaying or m.isPaused then
        fgColor = Colors().Orange
        m.bgColor = Colors().GetAlpha("Black", 40)
    else
        fgColor = Colors().Text
        m.bgColor = (fgColor and &hffffff00)
    end if

    for each comp in m.components
        if comp.SetColor <> invalid and comp.SetText <> invalid then
            if comp.Equals(m.index) then
                if m.isPlaying or m.isPaused then
                    if comp.origText = invalid then comp.origText = comp.text
                    comp.font = m.customFonts.glyph
                    comp.SetText(iif(m.isPlaying, Glyphs().PLAY, Glyphs().PAUSE), false, true)
                else
                    comp.font = m.customFonts.index
                    if comp.origText <> invalid then comp.SetText(comp.origText, false, true)
                end if
            end if
            comp.SetColor(iif(comp.Equals(m.subtitle), comp.fgColor, fgColor), m.bgColor)

            if draw then comp.Draw(true)
        end if
    end for

    if draw then
        m.Draw()
        m.Trigger("redraw", [m])
    end if
end sub

sub trackInitComponents()
    item = m.plexObject

    ' show the track index of the play queue, unless it's a single album
    if m.isMixed = true then
        trackIndex = item.GetFirst(["playQueueIndex", "index"], "")
    else
        trackIndex = item.Get("index", "")
    end if

    m.index = createLabel(trackIndex, m.customFonts.index)
    m.index.valign = m.index.ALIGN_MIDDLE
    m.index.SetPadding(0, m.padding.right, 0, m.padding.left)
    m.AddComponent(m.index)

    ' Include an image for mixed content or video items
    if m.isMixed = true or item.IsVideoItem() then
        m.trackImage = createImage(m.plexObject, m.height, m.height)
        if item.type = "track" then
            m.trackImage.SetOrientation(ComponentClass().ORIENTATION_SQUARE)
        else
            m.trackImage.SetOrientation(ComponentClass().ORIENTATION_LANDSCAPE)
            if item.type = "episode" then
                m.trackImage.thumbAttr = ["thumb", "art"]
            end if
        end if
        m.trackImage.cache = true
        m.AddComponent(m.trackImage)
    end if

    ' Include watched status overlays for video items
    if m.trackImage <> invalid and item.IsVideoItem() then
        if item.GetViewOffsetPercentage() > 0 then
            m.progress = createProgressBar(item.GetViewOffsetPercentage(), Colors().OverlayVeryDark , Colors().Orange)
            m.AddComponent(m.progress)
        else if item.IsUnwatched() then
            m.unwatched = createIndicator(Colors().Orange, FontRegistry().NORMAL.GetOneLineHeight())
            m.unwatched.valign = m.unwatched.ALIGN_TOP
            m.unwatched.halign = m.unwatched.JUSTIFY_RIGHT
            m.AddComponent(m.unwatched)
        end if
    end if

    m.title = createLabel(item.Get("title", ""), m.customFonts.title)
    m.title.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.title)

    if item.type = "track" then
        if m.IsMixed or item.GetBool("isVarious") then
            if m.IsMixed then
                subtitle = joinArray([item.Get("trackArtist"), item.Get("parentTitle")], " / ")
            else
                subtitle = item.Get("trackArtist", "")
            end if
            m.subtitle = createLabel(subtitle, m.customFonts.subtitle)
            m.subtitle.SetColor(Colors().TextMed)
            m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
            m.AddComponent(m.subtitle)
        end if
        m.time = createLabel(item.GetDuration(), m.customFonts.title)
        m.time.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
        m.AddComponent(m.time)
    else
        if item.type = "episode" then
            if m.isSeason then
                subtitle = item.GetOriginallyAvailableAt()
            else
                subtitle = joinArray([item.Get("grandparentTitle"), item.GetSingleLineTitle()], " / ")
            end if
            m.subtitle = createLabel(subtitle, m.customFonts.subtitle)
            m.subtitle.SetColor(Colors().TextMed)
            m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
            m.AddComponent(m.subtitle)
        else
            m.subtitle = createLabel(item.Get("year", ""), m.customFonts.subtitle)
            m.subtitle.SetColor(Colors().TextMed)
            m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
            m.AddComponent(m.subtitle)
        end if
        m.runtime = createLabel(item.GetDuration(), m.customFonts.subtitle)
        m.runtime.SetColor(Colors().TextMed)
        m.runtime.SetPadding(0, m.padding.right, 0, m.padding.left)
        m.AddComponent(m.runtime)
    end if
end sub

sub trackPerformLayout()
    m.needsLayout = false

    ' composite: the coordinates of our children are relative to our own x,y.
    middle = m.height/2
    spacingSmall = 30
    spacingBig = 40
    xOffset = spacingBig

    if m.separator <> invalid then
        m.separator.SetFrame(xOffset, m.height - m.separator.height, m.width - xOffset*2, m.separator.height)
    end if

    ' track index / status glyph
    m.index.SetFrame(xOffset, 0, m.index.GetPreferredWidth(), m.height)
    xOffset = xOffset + m.title.font.GetOneLineWidth(string(len(m.trackCount.toStr()), "0"), m.width) + spacingSmall

    if m.trackImage <> invalid then
        height = cint(m.height * .726)
        width = m.trackImage.GetWidthForOrientation(m.trackImage.orientation, height)
        yOffset = middle - height/2
        m.trackImage.SetFrame(xOffset, yOffset, width, height)

        if m.unwatched <> invalid or m.progress <> invalid then
            ' composite needs to be alpha enabled for the overlay
            m.alphaEnable = true
            if m.progress <> invalid and m.progress.percent > 0 then
                progressHeight = 5
                m.progress.SetFrame(xOffset, yOffset + height - progressHeight, width, progressHeight)
            else if m.unwatched <> invalid then
                m.unwatched.SetFrame(xOffset, yOffset, width, m.unwatched.GetPreferredHeight())
            end if
        end if
        xOffset = xOffset +m.trackImage.GetPreferredWidth() + spacingSmall
    end if

    ' track time
    if m.time <> invalid then
        xOffsetTime = m.width - m.time.GetPreferredWidth() - spacingBig
        yOffset = middle - m.time.GetPreferredHeight()/2
        m.time.SetFrame(xOffsetTime, yOffset, m.time.GetPreferredWidth(), m.time.GetPreferredHeight())
    else
        xOffsetTime = m.width
    end if

    ' title / subtitle / runtime
    height = m.title.GetPreferredHeight()

    if m.subtitle <> invalid then
        height = height + m.subtitle.GetPreferredHeight()
    end if

    if m.runtime <> invalid then
        height = height + m.runtime.GetPreferredHeight()
    end if

    yOffset = middle - height/2
    m.title.SetFrame(xOffset, yOffset, xOffsetTime - xOffset, m.title.GetPreferredHeight())

    if m.subtitle <> invalid then
        yOffset = yOffset + m.title.GetPreferredHeight()
        m.subtitle.SetFrame(xOffset, yOffset, xOffsetTime - xOffset, m.subtitle.GetPreferredHeight())
    end if

    if m.runtime <> invalid then
        yOffset = yOffset + m.runtime.GetPreferredHeight()
        m.runtime.SetFrame(xOffset, yOffset, xOffsetTime - xOffset, m.runtime.GetPreferredHeight())
    end if
end sub

sub trackAddSeparator(region as object, options=invalid as dynamic)
    m.focusSeparator = region.GetHeight()
    m.separator = CreateBlock(Colors().Separator, region)
    m.separator.height = m.focusSeparator
    m.AddComponent(m.separator)
end sub
