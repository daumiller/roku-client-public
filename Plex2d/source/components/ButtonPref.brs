function ButtonPrefClass() as object
    if m.ButtonPrefClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "ButtonPref"

        obj.Draw = buttonprefDraw
        obj.Init = buttonprefInit
        obj.OnSelected = buttonprefOnSelected

        m.ButtonPrefClass = obj
    end if

    return m.ButtonPrefClass
end function

function createButtonPref(text as string, font as object, command as dynamic, value as string, prefType as string, screenPref=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ButtonPrefClass())

    obj.Init(text, font)

    obj.command = command
    obj.value = value
    obj.prefType = prefType
    obj.screenPref = screenPref
    obj.isSelected = false

    return obj
end function

sub buttonprefInit(text as string, font as object)
    ApplyFunc(LabelClass().Init, m, [text, font])

    m.focusable = true
    m.selectable = true
    m.halign = m.JUSTIFY_CENTER
    m.valign = m.ALIGN_MIDDLE
end sub

function buttonprefDraw(redraw=false as boolean) as object
    if redraw = false and m.region <> invalid then return [m]

    m.InitRegion()

    ' Text calculation
    line = m.TruncateText()
    lineHeight = m.font.GetOneLineHeight()
    yOffset = m.GetYOffsetAlignment(lineHeight)

    ' If we're left justifying, don't bother with the expensive width calculation.
    if m.halign = m.JUSTIFY_LEFT then
        xOffset = m.GetContentArea().x
    else
        xOffset = m.GetXOffsetAlignment(m.font.GetOneLineWidth(line, 1280))
    end if
    m.region.DrawText(line, xOffset, yOffset, m.fgColor, m.font)

    ' CheckBox and CheckMark
    if m.prefType = "bool" or m.isSelected then
        ' TODO(rob): how will we handle this with HD to SD?
        glyph = FontRegistry().GetIconFont(32)
        glyphHeight = glyph.GetOneLineHeight()
        glyphWidth = glyph.GetOneLineWidth(Glyphs().CHECK, m.width)
    end if

    ' include the checkbox for a boolean preference, an enumerated pref will only have one selected.
    if m.prefType = "bool" then
        checkBox = {
            y: m.GetYOffsetAlignment(glyphWidth),
            x: m.width - xOffset - glyphWidth,
            w: glyphWidth,
            h: glyphWidth,
            color: Colors().BtnBkgClr and &hffffff90
        }

        m.region.DrawRect(checkBox.x, checkBox.y, checkBox.w, checkBox.h, checkBox.color)
    end if

    if m.isSelected then
        checkMark = {
            y: m.GetYOffsetAlignment(glyphHeight)
            x: m.width - xOffset - glyphWidth
            color: m.fgColor
        }

        m.region.DrawText(Glyphs().CHECK, checkMark.x, checkMark.y, checkMark.color, glyph)
    end if

    return [m]
end function

sub buttonprefOnSelected()
    if m.prefType = "bool" then
        prefKey = m.command + "_" + m.value
        prefValue = tostr(not(m.isSelected))
    else if m.prefType = "enum" then
        prefKey = m.command
        prefValue = m.value

        m.selected = false
        ' uncheck any selected component and redraw
        for each comp in m.parent.components
            if comp.isSelected then
                comp.isSelected = false
                comp.Draw(true)
            end if
        end for
    else
        FATAL("invalid prefType: " + tostr(m.prefType))
    end if

    ' toggle and redraw the selected component
    m.isSelected = NOT(m.isSelected)
    m.Draw(true)

    ' redraw the screen
    CompositorScreen().DrawAll()

    if m.screenPref then
        Debug("TODO: override pref for Screen: " + prefKey + "=" + prefValue + " (type: " + m.prefType + ")")
    else
        Debug("TODO: write setting to AppSettings: " + prefKey + "=" + prefValue + " (type: " + m.prefType + ")")
    end if
end sub
