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
        obj.SetColor = trackSetColor
        obj.OnFocus = trackOnFocus
        obj.OnBlur = trackOnBlur
        obj.SetPlaying = trackSetPlaying

        m.TrackClass = obj
    end if

    return m.TrackClass
end function

function createTrack(item as object, textFont as object, glyphFont as object, trackCount=1 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(TrackClass())

    obj.plexObject = item
    obj.bgColor = (Colors().Text and &hffffff00)
    obj.isPlaying = false
    obj.isPaused = false
    obj.trackCount = trackCount

    obj.Init(textFont, glyphFont)

    return obj
end function

sub trackInit(textFont as object, glyphFont as object)
    ApplyFunc(CompositeClass().Init, m)

    m.customFonts = {
        text: textFont,
        glyphs: glyphFont,
    }

    m.padding =  {
        top: 5,
        right: 5,
        bottom: 5,
        left: 5,
    }

    m.InitComponents()
end sub

sub trackSetColor(fgColor as integer, bgColor=invalid as dynamic)
    ' we'll redraw if we have a valid region
    draw = m.region <> invalid

    ' override colors if track is currently playing (maybe paused too?)
    if m.isPlaying or m.isPaused then fgColor = Colors().Orange

    ' set the composites background color to anti-alias
    m.bgColor = firstOf(m.bgColorForce, (fgColor and &hffffff00))
    for each comp in m.components
        if comp.Equals(m.status) then
            if m.isPlaying = false and m.isPaused = false then
                comp.SetColor(&h00000000)
            else
                comp.text = iif(m.isPlaying, Glyphs().PLAY, Glyphs().PAUSE)
                comp.SetColor(fgColor, bgColor)
            end if
        else
            comp.SetColor(fgColor, bgColor)
        end if
        if draw then comp.Draw(true)
    end for

    if draw then
        m.Draw()
        m.Trigger("redraw", [m])
    end if
end sub

sub trackOnFocus()
    m.SetColor(Colors().Orange, invalid)
end sub

sub trackOnBlur(toFocus=invalid as dynamic)
    m.SetColor(Colors().Text, invalid)
end sub

sub trackSetPlaying(playing=true as boolean)
    m.isPlaying = playing
    m.isPaused = AudioPlayer().isPaused
    m.SetColor(iif(playing, Colors().Orange, Colors().Text), invalid)
end sub

sub trackInitComponents()
    item = m.plexObject

    ' TODO(rob): update Play / Paused status
    m.status = createLabel(Glyphs().PLAY, m.customFonts.glyphs)
    m.status.SetColor(&h00000000)
    m.status.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.status)

    m.index = createLabel(item.Get("index", ""), m.customFonts.text)
    m.index.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.index)

    m.title = createLabel(item.Get("title", ""), m.customFonts.text)
    m.title.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.title)

    m.time = createLabel(item.GetDuration(), m.customFonts.text)
    m.time.SetPadding(m.padding.top, m.padding.right, m.padding.bottom, m.padding.left)
    m.AddComponent(m.time)
end sub

sub trackPerformLayout()
    m.needsLayout = false

    ' composite: the coordinates of our children are relative to our own x,y.
    middle = m.height/2
    xOffset = 0

    ' status glyph
    yOffset = middle - m.status.GetPreferredHeight()/2
    m.status.SetFrame(xOffset, yOffset, m.status.GetPreferredWidth(), m.status.GetPreferredHeight())

    ' track index
    xOffset = xOffset + m.status.GetPreferredWidth()
    yOffset = middle - m.index.GetPreferredHeight()/2
    m.index.SetFrame(xOffset, yOffset, m.index.GetPreferredWidth(), m.index.GetPreferredHeight())

    ' track title
    xOffset = xOffset + m.customFonts.text.GetOneLineWidth(string(len(m.trackCount.toStr()) + 2, "0"), m.width)
    yOffset = middle - m.title.GetPreferredHeight()/2
    xOffsetTime = m.width - m.time.GetPreferredWidth() - m.index.x
    m.title.SetFrame(xOffset, yOffset, xOffsetTime - xOffset, m.title.GetPreferredHeight())

    ' track time
    yOffset = middle - m.time.GetPreferredHeight()/2
    m.time.SetFrame(xOffsetTime, yOffset, m.time.GetPreferredWidth(), m.time.GetPreferredHeight())
end sub
