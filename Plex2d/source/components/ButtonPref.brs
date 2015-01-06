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
        glyph = FontRegistry().GetIconFont(20)
        glyphPref = {
            padding: int(glyph.GetOneLineHeight() / 4)
            height: glyph.GetOneLineHeight(),
            width: glyph.GetOneLineWidth(Glyphs().CHECK, m.width)
        }
    end if

    ' include the checkbox for a boolean preference, an enumerated pref will only have one selected.
    if m.prefType = "bool" then
        checkBox = {
            y: m.GetYOffsetAlignment(glyphPref.width) - glyphPref.padding/2,
            x: m.width - xOffset - glyphPref.width - glyphPref.padding/2,
            w: glyphPref.width + glyphPref.padding,
            h: glyphPref.width + glyphPref.padding,
            color: Colors().Button and &hffffff90
        }

        m.region.DrawRect(checkBox.x, checkBox.y, checkBox.w, checkBox.h, checkBox.color)
    end if

    if m.isSelected then
        checkMark = {
            y: m.GetYOffsetAlignment(glyphPref.height)
            x: m.width - xOffset - glyphPref.width
            color: m.fgColor
        }

        m.region.DrawText(Glyphs().CHECK, checkMark.x, checkMark.y, checkMark.color, glyph)
    end if

    return [m]
end function

sub buttonprefOnSelected()
    prefKey = m.command

    if m.prefType = "bool" then
        prefValue = iif(m.isSelected, "0", "1")
    else if m.prefType = "enum" then
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
        Debug("Set preference:" + prefKey + "=" + prefValue + " (type: " + m.prefType + ")")
        AppSettings().SetPreference(prefKey, prefValue)
    end if
end sub
