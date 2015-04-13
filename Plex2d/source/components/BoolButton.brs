function BoolButtonClass() as object
    if m.BoolButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ButtonClass())
        obj.ClassName = "BoolButton"

        obj.Draw = boolbuttonDraw
        obj.Init = boolbuttonInit
        obj.OnSelected = boolbuttonOnSelected

        m.BoolButtonClass = obj
    end if

    return m.BoolButtonClass
end function

function createBoolButton(text as string, font as object, command as dynamic, isSelected=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(BoolButtonClass())

    obj.Init(text, font, command, isSelected)

    obj.prefType = "bool"

    return obj
end function

sub boolbuttonInit(text as string, font as object, command as dynamic, isSelected as boolean)
    ApplyFunc(ButtonClass().Init, m, [text, font])

    m.command = command
    m.isSelected = isSelected

    m.focusable = true
    m.selectable = true
    m.halign = m.JUSTIFY_CENTER
    m.valign = m.ALIGN_MIDDLE
end sub

function boolbuttonDraw(redraw=false as boolean) as object
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
'            color: Colors().Button and &hffffff90
            color: Colors().Button,
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

sub boolbuttonOnSelected(screen as object)
    ' toggle and redraw the selected component
    m.isSelected = NOT(m.isSelected)
    m.Draw(true)

    ' redraw the screen
    screen.screen.DrawAll()
end sub
