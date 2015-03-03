function GoHomeButtonClass() as object
    if m.GoHomeButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeButtonClass())
        obj.ClassName = "GoHomeButton"

        ' Method overrides
        obj.Init = ghbuttonInit
        obj.PerformLayout = ghbuttonPerformLayout

        m.GoHomeButtonClass = obj
    end if

    return m.GoHomeButtonClass
end function

function createGoHomeButton(font as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GoHomeButtonClass())

    obj.Init("Go Home", font)

    obj.command = "go_home"

    return obj
end function

sub ghbuttonInit(text as string, font as object)
    ApplyFunc(CompositeButtonClass().Init, m, [text, font])

    m.customFonts = {
        label: FontRegistry().NORMAL,
        glyph: FontRegistry().GetIconFont(26),
    }

    m.label = createLabel(m.text, m.customFonts.label)
    m.AddComponent(m.label)

    m.homeGlyph = createLabel(Glyphs().HOME, m.customFonts.glyph)
    m.AddComponent(m.homeGlyph)
end sub

sub ghbuttonPerformLayout()
    ApplyFunc(CompositeButtonClass().PerformLayout, m)

    yOffset = m.GetYOffsetAlignment(m.homeGlyph.font.GetOneLineHeight())
    xOffset = m.width - m.padding.right - m.homeGlyph.GetPreferredWidth()
    m.homeGlyph.SetColor(m.fgColor)
    m.homeGlyph.SetFrame(xOffset, yOffset, m.homeGlyph.GetPreferredWidth(), m.homeGlyph.GetPreferredHeight())

    m.label.width = xOffset - m.padding.right
    yOffset = m.GetYOffsetAlignment(m.label.font.GetOneLineHeight())
    xOffset = m.padding.left
    m.label.SetColor(m.fgColor)
    m.label.SetFrame(xOffset, yOffset, m.label.GetPreferredWidth(), m.label.GetPreferredHeight())
end sub
