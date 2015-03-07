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

        m.TrackClass = obj
    end if

    return m.TrackClass
end function

function createTrack(item as object, titleFont as object, subtitleFont as object, glyphFont as object, trackCount=1 as integer, isMixed=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(TrackClass())

    obj.plexObject = item
    obj.bgColor = (Colors().Text and &hffffff00)
    obj.isPlaying = false
    obj.isPaused = false
    obj.trackCount = trackCount
    obj.isMixed = isMixed
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

sub trackSetIndex(index as integer)
    m.index.SetText(tostr(index))
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
        if not comp.Equals(m.trackImage) then
            if comp.Equals(m.index) then
                if m.isPlaying or m.isPaused then
                    if comp.origText = invalid then comp.origText = comp.text
                    comp.SetText(iif(m.isPlaying, Glyphs().PLAY, Glyphs().PAUSE))
                    comp.font = m.customFonts.glyph
                else
                    comp.SetText(comp.origText)
                    comp.font = m.customFonts.index
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
    m.index.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.index)

    if m.isMixed = true then
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

    m.title = createLabel(item.Get("title", ""), m.customFonts.title)
    m.title.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.title)

    if item.type = "track" then
        if m.IsMixed then
            subtitle = joinArray([item.Get("grandparentTitle"), item.Get("parentTitle")], " / ")
            m.subtitle = createLabel(subtitle, m.customFonts.subtitle)
            m.subtitle.SetColor(Colors().TextDim)
            m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
            m.AddComponent(m.subtitle)
        end if
    else
        if item.type = "episode" then
            subtitle = joinArray([item.Get("grandparentTitle"), item.GetSingleLineTitle()], " / ")
            m.subtitle = createLabel(subtitle, m.customFonts.subtitle)
            m.subtitle.SetColor(Colors().TextDim)
            m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
            m.AddComponent(m.subtitle)
        else
            m.subtitle = createLabel(item.Get("year"), m.customFonts.subtitle)
            m.subtitle.SetColor(Colors().TextDim)
            m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
            m.AddComponent(m.subtitle)
        end if
        m.runtime = createLabel(item.GetDuration(), m.customFonts.subtitle)
        m.runtime.SetColor(Colors().TextDim)
        m.runtime.SetPadding(0, m.padding.right, 0, m.padding.left)
        m.AddComponent(m.runtime)
    end if

    m.time = createLabel(item.GetDuration(), m.customFonts.title)
    m.time.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.time)
end sub

sub trackPerformLayout()
    m.needsLayout = false

    ' composite: the coordinates of our children are relative to our own x,y.
    middle = m.height/2
    spacing = m.title.font.GetOneLineWidth("000", m.width)
    xOffset = spacing

    ' track index / status glyph
    if m.index <> invalid then
        yOffset = middle - m.index.GetPreferredHeight()/2
        m.index.SetFrame(xOffset, yOffset, m.index.GetPreferredWidth(), m.index.GetPreferredHeight())
    end if
    xOffset = xOffset + m.title.font.GetOneLineWidth(string(len(m.trackCount.toStr()), "0"), m.width) + spacing

    if m.trackImage <> invalid then
        height = cint(m.height * .726)
        width = m.trackImage.GetWidthForOrientation(m.trackImage.orientation, height)
        m.trackImage.SetFrame(xOffset, middle - height/2, width, height)
        xOffset = xOffset +m.trackImage.GetPreferredWidth() + spacing
    end if

    ' track time
    xOffsetTime = m.width - m.time.GetPreferredWidth() - spacing
    yOffset = middle - m.time.GetPreferredHeight()/2
    m.time.SetFrame(xOffsetTime, yOffset, m.time.GetPreferredWidth(), m.time.GetPreferredHeight())

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
