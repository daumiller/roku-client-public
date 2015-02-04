function ButtonServerClass() as object
    if m.ButtonServerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.Append(PaddingMixin())
        obj.ClassName = "ButtonServer"

        obj.Draw = buttonServerDraw
        obj.Init = buttonServerInit

        m.ButtonServerClass = obj
    end if

    return m.ButtonServerClass
end function

function createButtonServer(server as object, command as dynamic, titleFont as object, subtitleFont as object, glyphFont as object, statusFont as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ButtonServerClass())

    obj.server = server
    obj.command = command

    obj.Init(titleFont, subtitleFont, glyphFont, statusFont)

    return obj
end function

sub buttonServerInit(titleFont as object, subtitleFont as object, glyphFont as object, statusFont as object)
    ApplyFunc(ComponentClass().Init, m)

    m.customFonts = {
        title: titleFont,
        subtitle: subtitleFont,
        glyph: glyphFont,
        status: statusFont,
    }

    m.bgColor = iif(m.server.owned, Colors().ButtonDark, Colors().Button)
    m.titleColor = iif(m.server.isReachable(), Colors().Text, Colors().TextDim)
    m.subtitleColor = Colors().TextDim

    m.focusable = true
    m.selectable = true
    m.fixed = false

    m.halign = m.JUSTIFY_RIGHT
    m.valign = m.ALIGN_MIDDLE
    m.statusWidth = 0
end sub

function buttonServerDraw(redraw=false as boolean) as object
    if redraw = false and m.region <> invalid then return [m]
    m.InitRegion()

    if m.server.owned = true then
        titleText = tostr(m.server.name)
        subtitleText = invalid
    else
        titleText = tostr(m.server.owner)
        subtitleText = tostr(m.server.name)
    end if

    ' Title
    title = createLabel(titleText, m.customFonts.title)
    title.width = m.width - m.statusWidth
    titleText = title.TruncateText()
    yOffset = m.GetYOffsetAlignment(m.customFonts.title.GetOneLineHeight())
    xOffset = m.GetXOffsetAlignment(m.customFonts.title.GetOneLineWidth(titleText, m.width))
    m.region.DrawText(titleText, xOffset, yOffset, m.titleColor, m.customFonts.title)
    xOffset = iif(m.padding <> invalid, m.padding.left, 0)

    ' Not supported - blue dot (upgraded required)
    if m.server.IsSupported = false then
        yOffset = m.GetYOffsetAlignment(m.customFonts.status.GetOneLineHeight())
        m.region.DrawText("•", xOffset, yOffset, Colors().Blue, m.customFonts.status)
        subtitleText = "Upgrade Required"
    ' Unreachable - red dot (offline)
    else if m.server.isReachable() = false then
        yOffset = m.GetYOffsetAlignment(m.customFonts.status.GetOneLineHeight())
        m.region.DrawText("•", xOffset, yOffset, Colors().Red, m.customFonts.status)
        subtitleText = "Offline"
    end if

    ' Check mark for selected server
    if m.server.Equals(PlexServerManager().GetSelectedServer())
        yOffset = m.GetYOffsetAlignment(m.customFonts.glyph.GetOneLineHeight())
        m.region.DrawText(Glyphs().CHECK, xOffset, yOffset, Colors().Green, m.customFonts.glyph)
    end if

    ' Subtitle
    if subtitleText <> invalid then
        subtitle = createLabel(subtitleText, m.customFonts.title)
        subtitle.width = m.width
        subtitleText = subtitle.TruncateText()
        xOffset = m.GetXOffsetAlignment(m.customFonts.subtitle.GetOneLineWidth(subtitleText, m.width))
        yOffset = m.height - m.customFonts.subtitle.GetOneLineHeight()
        if m.padding <> invalid then
            yOffset = yOffset - m.padding.bottom
        end if
        m.region.DrawText(subtitleText, xOffset, yOffset, m.subtitleColor, m.customFonts.subtitle)
    end if

    return [m]
end function
