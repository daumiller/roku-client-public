function TrackClass() as object
    if m.TrackClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.ClassName = "Track"

        obj.alphaEnable = true

        ' Methods
        obj.Init = trackInit
        obj.InitComponents = trackInitComponents
        obj.PerformLayout = trackPerformLayout
        obj.SetPlaying = trackSetPlaying

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

    obj.Init(titleFont, subtitleFont, glyphFont)

    return obj
end function

sub trackInit(titleFont as object, subtitleFont as object, glyphFont as object)
    ApplyFunc(CompositeClass().Init, m)

    m.customFonts = {
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

sub trackSetPlaying(playing=true as boolean)
    m.isPlaying = playing
    m.isPaused = AudioPlayer().isPaused

    draw = (m.region <> invalid)

    fgColor = iif(m.isPlaying or m.isPaused, Colors().Orange, Colors().Text)
    fgStatus = iif(fgColor = Colors().Orange, fgColor, Colors().Transparent)

    ' set the composites background color to anti-alias
    m.bgColor = (fgColor and &hffffff00)
    for each comp in m.components
        if not comp.Equals(m.trackImage) then
            if comp.Equals(m.status) then
                comp.text = iif(m.isPlaying, Glyphs().PLAY, Glyphs().PAUSE)
                comp.SetColor(fgStatus)
            else if not comp.Equals(m.subtitle) then
                comp.SetColor(fgColor)
            end if
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

    m.status = createLabel(Glyphs().PLAY, m.customFonts.glyph)
    m.status.SetColor(Colors().Transparent)
    m.status.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.status)

    ' show the track index of the play queue, unless it's a single album
    if m.isMixed = true then
        trackIndex = item.GetFirst(["playQueueIndex", "index", ""])
    else
        trackIndex = item.Get("index","")
    end if
    m.index = createLabel(trackIndex, m.customFonts.title)
    m.index.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.index)

    if m.isMixed = true then
        m.trackImage = createImage(m.plexObject, m.height, m.height)
        m.trackImage.cache = true
        m.AddComponent(m.trackImage)
    end if

    m.title = createLabel(item.Get("title", ""), m.customFonts.title)
    m.title.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.title)

    if m.IsMixed then
        subtitle = joinArray([item.Get("grandparentTitle"), item.Get("parentTitle")], " / ")
        m.subtitle = createLabel(subtitle, m.customFonts.subtitle)
        m.subtitle.SetColor(Colors().Subtitle)
        m.subtitle.SetPadding(0, m.padding.right, 0, m.padding.left)
        m.AddComponent(m.subtitle)
    end if

    m.time = createLabel(item.GetDuration(), m.customFonts.title)
    m.time.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.time)
end sub

sub trackPerformLayout()
    m.needsLayout = false

    ' composite: the coordinates of our children are relative to our own x,y.
    middle = m.height/2
    xOffset = 20
    spacing = m.title.font.GetOneLineWidth("00", m.width)

    ' status glyph
    yOffset = middle - m.status.GetPreferredHeight()/2
    m.status.SetFrame(xOffset, yOffset, m.status.GetPreferredWidth(), m.status.GetPreferredHeight())
    xOffset = xOffset + m.status.GetPreferredWidth()

    ' track index
    if m.index <> invalid then
        yOffset = middle - m.index.GetPreferredHeight()/2
        m.index.SetFrame(xOffset, yOffset, m.index.GetPreferredWidth(), m.index.GetPreferredHeight())
    end if
    xOffset = xOffset + m.title.font.GetOneLineWidth(string(len(m.trackCount.toStr()), "0"), m.width) + spacing

    if m.trackImage <> invalid then
        size = cint(m.height * .80)
        m.trackImage.SetFrame(xOffset, middle - size/2, size, size)
        xOffset = xOffset +m.trackImage.GetPreferredWidth() + spacing
    end if

    ' track time
    xOffsetTime = m.width - m.time.GetPreferredWidth()
    yOffset = middle - m.time.GetPreferredHeight()/2
    m.time.SetFrame(xOffsetTime, yOffset, m.time.GetPreferredWidth(), m.time.GetPreferredHeight())

    ' change track title/subtitle offset if track index exists
    if m.index <> invalid then
        xOffsetTime = xOffsetTime - xOffset
    end if

    ' subtitle (artist / album)
    if m.subtitle <> invalid then
        height = m.title.GetPreferredHeight() + m.subtitle.GetPreferredHeight()
    else
        height = m.title.GetPreferredHeight()
    end if

    yOffset = middle - height/2
    m.title.SetFrame(xOffset, yOffset, xOffsetTime - xOffset, m.title.GetPreferredHeight())

    if m.subtitle <> invalid then
        yOffset = yOffset + m.title.GetPreferredHeight()
        m.subtitle.SetFrame(xOffset, yOffset, xOffsetTime - xOffset, m.subtitle.GetPreferredHeight())
    end if
end sub
