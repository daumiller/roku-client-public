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

    m.bgColor = iif(m.server.owned, Colors().Button, Colors().ButtonMed)
    m.titleColor = iif(m.server.isReachable(), Colors().Text, Colors().Subtitle)
    m.subtitleColor = Colors().Subtitle

    m.focusable = true
    m.selectable = true
    m.fixed = false
    m.focusInside = true

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

    if m.focusSeparator <> invalid then
        m.region.DrawRect(xOffset, m.height - m.focusSeparator, m.width - xOffset*2, m.focusSeparator, Colors().Black)
    end if

    ' Include subtitle if server is shared
    titleText = tostr(m.server.name)
    subtitleText = m.server.GetSubtitle()

    ' Status indicators
    showLock = (MyPlexAccount().isSecure and m.server.activeConnection <> invalid and m.server.activeConnection.isSecure)

    if m.server.Equals(PlexServerManager().GetSelectedServer()) then
        if showLock then
            ' TODO(schuyler): Is this the best way to show both? The latest client
            ' mocks for this menu are somewhat different.
            glyphText = Glyphs().LOCK + Glyphs().CHECK
        else
            glyphText = Glyphs().CHECK
        end if
        glyphColor = Colors().Green
    else if m.server.IsSupported = false or m.server.isReachable() = false then
        glyphText = Glyphs().ERROR
        glyphColor = Colors().Red
    else if showLock then
        glyphText = Glyphs().LOCK
        glyphColor = Colors().Green
    else
        glyphText = invalid
    end if
    if glyphText <> invalid then
        yOffset = m.GetYOffsetAlignment(m.customFonts.glyph.GetOneLineHeight())
        m.region.DrawText(glyphText, xOffset, yOffset, glyphColor, m.customFonts.glyph)
    end if
    xOffset = xOffset + m.statusWidth

    ' Title
    title = createLabel(titleText, m.customFonts.title)
    title.width = childWidth
    titleText = title.TruncateText()
    height = title.GetPreferredHeight()

    ' Subtitle
    if subtitleText <> invalid then
        subtitle = createLabel(subtitleText, m.customFonts.subtitle)
        subtitle.width = childWidth
        subtitleText = subtitle.TruncateText()
        height = height + subtitle.GetPreferredHeight()
    end if

    yOffset = m.GetYOffsetAlignment(height)
    if m.halign <> m.JUSTIFY_LEFT then
        xOffset = m.GetXOffsetAlignment(title.font.GetOneLineWidth(titleText, m.width))
    end if
    m.region.DrawText(titleText, xOffset, yOffset, m.titleColor, title.font)

    if subtitleText <> invalid then
        yOffset = yOffset + title.GetPreferredHeight()
        if m.halign <> m.JUSTIFY_LEFT then
            xOffset = m.GetXOffsetAlignment(subtitle.font.GetOneLineWidth(subtitleText, m.width))
        end if
        m.region.DrawText(subtitleText, xOffset, yOffset, m.subtitleColor, subtitle.font)
    end if

    return [m]
end function
