function ServerButtonClass() as object
    if m.ServerButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.Append(PaddingMixin())
        obj.ClassName = "ServerButton"

        obj.Draw = serverbuttonDraw
        obj.Init = serverbuttonInit

        m.ServerButtonClass = obj
    end if

    return m.ServerButtonClass
end function

function createServerButton(server as object, command as dynamic, titleFont as object, subtitleFont as object, glyphFont as object, statusFont as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ServerButtonClass())

    obj.server = server
    obj.command = command
    obj.statusWidth = statusFont.GetOneLineWidth(Glyphs().CHECK, 1280) * 2

    obj.Init(titleFont, subtitleFont, glyphFont, statusFont)

    return obj
end function

sub serverbuttonInit(titleFont as object, subtitleFont as object, glyphFont as object, statusFont as object)
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

    m.halign = m.JUSTIFY_LEFT
    m.valign = m.ALIGN_MIDDLE
end sub

function serverbuttonDraw(redraw=false as boolean) as object
    if redraw = false and m.region <> invalid then return [m]
    m.InitRegion()

    if m.padding <> invalid then
        childWidth = m.width - m.padding.left - m.padding.right - m.statusWidth
        xOffset = m.padding.left
    else
        childWidth = m.width - m.statusWidth
        xOffset = 0
    end if

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
    ' Check mark for selected server
    else if m.server.Equals(PlexServerManager().GetSelectedServer())
        yOffset = m.GetYOffsetAlignment(m.customFonts.glyph.GetOneLineHeight())
        m.region.DrawText(Glyphs().CHECK, xOffset, yOffset, Colors().Green, m.customFonts.glyph)
    end if
    xOffset = xOffset + m.statusWidth

    ' Swap title/subtitle based on server ownership
    if m.server.owned = true then
        titleText = tostr(m.server.name)
        subtitleText = invalid
    else
        titleText = tostr(m.server.owner)
        subtitleText = tostr(m.server.name)
    end if

    ' Title
    title = createLabel(titleText, m.customFonts.title)
    title.width = childWidth
    titleText = title.TruncateText()
    yOffset = m.GetYOffsetAlignment(m.customFonts.title.GetOneLineHeight())
    if m.halign <> m.JUSTIFY_LEFT then
        xOffset = m.GetXOffsetAlignment(m.customFonts.title.GetOneLineWidth(titleText, m.width))
    end if
    m.region.DrawText(titleText, xOffset, yOffset, m.titleColor, m.customFonts.title)

    ' Subtitle
    if subtitleText <> invalid then
        subtitle = createLabel(subtitleText, m.customFonts.title)
        subtitle.width = childWidth
        subtitleText = subtitle.TruncateText()
        yOffset = m.height - m.customFonts.subtitle.GetOneLineHeight()
        if m.padding <> invalid then
            yOffset = yOffset - m.padding.bottom
        end if
        if m.halign <> m.JUSTIFY_LEFT then
            xOffset = m.GetXOffsetAlignment(m.customFonts.subtitle.GetOneLineWidth(subtitleText, m.width))
        end if
        m.region.DrawText(subtitleText, xOffset, yOffset, m.subtitleColor, m.customFonts.subtitle)
    end if

    return [m]
end function
