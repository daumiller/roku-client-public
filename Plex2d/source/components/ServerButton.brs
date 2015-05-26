function ServerButtonClass() as object
    if m.ServerButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeButtonClass())
        obj.ClassName = "ServerButton"

        obj.alphaEnable = false

        ' Method overrides
        obj.Init = serverbuttonInit
        obj.PerformLayout = serverbuttonPerformLayout
        obj.Draw = serverbuttonDraw

        obj.GetPreferredWidth = serverbuttonGetPreferredWidth
        obj.GetPreferredHeight = serverbuttonGetPreferredHeight

        obj.OnFocus = serverbuttonOnFocus
        obj.OnBlur = serverbuttonOnBlur

        m.ServerButtonClass = obj
    end if

    return m.ServerButtonClass
end function

function createServerButton(server as object, titleFont as object, subtitleFont, glyphFont as object, command as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ServerButtonClass())

    obj.server = server

    obj.Init(titleFont, subtitleFont, glyphFont)

    obj.useIndicator = false
    obj.command = command

    return obj
end function

sub serverbuttonInit(titleFont as object, subtitleFont as object, glyphFont as object)
    ApplyFunc(CompositeButtonClass().Init, m, [m.server.name, titleFont])

    m.customFonts = {
        title: titleFont,
        subtitle: subtitleFont,
        glyph: glyphFont
    }

    ' Title: server name
    m.title = createLabel(m.text, m.customFonts.title)
    m.AddComponent(m.title)

    ' Subtitle: optional shared server user or status text
    if not m.server.owned then
        m.subtitle = createLabel(firstOf(m.server.owner, "remote"), m.customFonts.subtitle)
        m.subtitle.SetColor(Colors().Subtitle)
        m.AddComponent(m.subtitle)
    end if

    ' Status indicator
    if m.server.Equals(PlexServerManager().GetSelectedServer()) then
        statusText = Glyphs().CHECK
        statusColor = Colors().Text
    else if m.server.IsSupported = false or m.server.isReachable() = false then
        statusText = Glyphs().ERROR
        statusColor = Colors().Red
    else
        statusText = invalid
    end if

    if statusText <> invalid then
        m.statusLabel = createLabel(statusText, m.customFonts.glyph)
        m.statusLabel.SetColor(statusColor)
        m.AddComponent(m.statusLabel)
    end if

    ' Secure indicator
    showLock = (MyPlexAccount().isSecure and m.server.activeConnection <> invalid and m.server.activeConnection.isSecure)
    if showLock then
        m.lockLabel = createLabel(Glyphs().PADLOCK, m.customFonts.glyph)
        m.lockLabel.SetColor(Colors().Green)
        m.AddComponent(m.lockLabel)
    end if
end sub

sub serverbuttonPerformLayout()
    ApplyFunc(CompositeButtonClass().PerformLayout, m)

    ' Place the components right to left
    xOffset = m.width - m.padding.right

    ' Status label positioning
    if m.statusLabel <> invalid then
        xOffset = xOffset - m.statusLabel.GetPreferredWidth()
        yOffset = m.GetYOffsetAlignment(m.statusLabel.font.GetOneLineHeight())
        m.statusLabel.SetFrame(xOffset, yOffset, m.statusLabel.GetPreferredWidth(), m.statusLabel.GetPreferredHeight())
        xOffset = xOffset - m.padding.right
    end if

    ' Lock label positioning
    if m.lockLabel <> invalid then
        xOffset = xOffset - m.lockLabel.GetPreferredWidth()
        yOffset = m.GetYOffsetAlignment(m.lockLabel.font.GetOneLineHeight())
        m.lockLabel.SetFrame(xOffset, yOffset, m.lockLabel.GetPreferredWidth(), m.lockLabel.GetPreferredHeight())
        xOffset = xOffset - m.padding.right
    end if

    ' Calculate the available width and height after placing the status/lock indicators
    width = xOffset - m.padding.left
    height = m.title.GetPreferredHeight()
    if m.subtitle <> invalid then
        height = height + m.subtitle.GetPreferredHeight()
    end if

    xOffset = m.padding.left
    yOffset = m.height/2 - height/2

    m.title.SetFrame(xOffset, yOffset, width, m.title.GetPreferredHeight())

    if m.subtitle <> invalid then
        yOffset = yOffset + m.title.GetPreferredHeight()
        m.subtitle.SetFrame(xOffset, yOffset, width, m.subtitle.GetPreferredHeight())
    end if
end sub

function serverButtonDraw(redraw=false as boolean) as object
    if m.focusMethod = m.FOCUS_FOREGROUND or m.focusMethod = m.FOCUS_BACKGROUND then
        ' Based on the focus method, we'll want to force a redraw
        ' regardless of the passed argument.
        redraw = (m.title.region <> invalid) or (m.statusLabel <> invalid and m.statusLabel.region <> invalid) or (m.lockLabel <> invalid and m.LockLabel.region <> invalid)
    end if

    ' Reset colors after buttons OnFocus/OnBlur methods
    for each comp in m.components
        comp.SetColor(comp.fgColor, m.bgColor)
    end for

    ' This is a composite, so these labels will be redrawn if
    ' the components have an invalid region.
    if redraw then
        for each comp in m.components
            comp.region = invalid
        end for
    end if

    return ApplyFunc(CompositeButtonClass().Draw, m)
end function

sub serverbuttonOnFocus()
    m.title.SetColor(Colors().Black, m.bgColor)
    if m.subtitle <> invalid then
        m.subtitle.SetColor(Colors().Text, m.bgColor)
    end if

    ApplyFunc(CompositeButtonClass().OnFocus, m)
end sub

sub serverbuttonOnBlur(toFocus=invalid as dynamic)
    m.title.SetColor(Colors().Text, m.bgColor)
    if m.subtitle <> invalid then
        m.subtitle.SetColor(Colors().Subtitle, m.bgColor)
    end if

    ApplyFunc(CompositeButtonClass().OnBlur, m, [toFocus])
end sub

function serverbuttonGetPreferredWidth() as integer
    ' If someone specifically set our width, then prefer that.
    if validint(m.width) > 0 then return m.width

    width = m.title.GetPreferredWidth()
    if m.subtitle <> invalid and m.subtitle.GetPreferredWidth() > width then
        width = m.subtitle.GetPreferredWidth()
    end if

    for each comp in m.components
        if not comp.Equals(m.title) and not comp.Equals(m.subtitle) then
            ' Pad the lock or status label
            mp = iif(comp.Equals(m.lockLabel) or comp.Equals(m.statusLabel), 2, 1)
            width = width + comp.GetPreferredWidth()*mp + m.padding.right
        end if
    end for

    return width + m.padding.left
end function

function serverbuttonGetPreferredHeight() as integer
    ' If someone specifically set our height, then prefer that.
    if validint(m.height) > 0 then return m.height
    return m.customFonts.title.GetOneLineHeight() + m.customFonts.subtitle.GetOneLineHeight() + m.padding.top + m.padding.bottom
end function
