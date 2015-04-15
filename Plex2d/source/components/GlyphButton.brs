function GlyphButtonClass() as object
    if m.GlyphButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeButtonClass())
        obj.ClassName = "GlyphButton"

        ' Method overrides
        obj.Init = glyphbuttonInit
        obj.PerformLayout = glyphbuttonPerformLayout
        obj.Draw = glyphbuttonDraw

        m.GlyphButtonClass = obj
    end if

    return m.GlyphButtonClass
end function

function createGlyphButton(text as string, textFont as object, glyphText as string, glyphFont as object, command as dynamic, useIndicator=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GlyphButtonClass())

    obj.Init(text, textFont, glyphText, glyphFont)

    obj.useIndicator = useIndicator
    obj.command = command

    return obj
end function

sub glyphbuttonInit(text as string, font as object, glyphText as string, glyphFont as object)
    ApplyFunc(CompositeButtonClass().Init, m, [text, font])

    m.glyphText = glyphText
    m.customFonts = {
        glyph: glyphFont
    }

    m.label = createLabel(m.text, m.font)
    m.AddComponent(m.label)

    m.glyphLabel = createLabel(m.glyphText, m.customFonts.glyph)
    m.AddComponent(m.glyphLabel)
end sub

sub glyphbuttonPerformLayout()
    ApplyFunc(CompositeButtonClass().PerformLayout, m)

    ' We want the glyph positioned on the right with the same offset
    ' used for the label on the right, so we'll `use m.padding.left`
    xOffset = m.width - m.padding.left - m.glyphLabel.GetPreferredWidth()
    yOffset = m.GetYOffsetAlignment(m.glyphLabel.font.GetOneLineHeight())
    m.glyphLabel.SetFrame(xOffset, yOffset, m.glyphLabel.GetPreferredWidth(), m.glyphLabel.GetPreferredHeight())

    m.label.width = xOffset - m.padding.right
    xOffset = m.padding.left
    yOffset = m.GetYOffsetAlignment(m.label.font.GetOneLineHeight())
    m.label.SetFrame(xOffset, yOffset, m.label.GetPreferredWidth(), m.label.GetPreferredHeight())
end sub

function glyphButtonDraw(redraw=false as boolean) as object
    if m.focusMethod = m.FOCUS_FOREGROUND or m.focusMethod = m.FOCUS_BACKGROUND then
        ' Based on the focus method, we'll want to force a redraw
        ' regardless of the passed argument.
        redraw = (m.label.region <> invalid or m.glyphLabel.region <> invalid)

        ' Reset colors after buttons OnFocus/OnBlur methods
        m.label.SetColor(m.fgColor, m.bgColor)
        m.glyphLabel.SetColor(m.fgColor, m.bgColor)
    end if

    ' This is a composite, so these labels will be redrawn if
    ' the components have an invalid region.
    if redraw then
        m.label.region = invalid
        m.glyphLabel.region = invalid
    end if

    return ApplyFunc(CompositeButtonClass().Draw, m)
end function
