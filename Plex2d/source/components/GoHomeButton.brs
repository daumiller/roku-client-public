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
        glyph: FontRegistry().GetIconFont(22),
    }

    m.label = createLabel(m.text, m.customFonts.label)
    m.AddComponent(m.label)

    ' TODO(rob): Home Glyph, Image, or something else?
    'm.homeGlyph = createLabel(Glyphs().HOME, m.customFonts.glyph)
    'm.AddComponent(m.homeGlyph)

    ' Image
    m.image = createImage("pkg:/images/pms_logo_HD_26x26.png", 26, 26, invalid, "scale-to-fit")
    m.AddComponent(m.image)
end sub

sub ghbuttonPerformLayout()
    ApplyFunc(CompositeButtonClass().PerformLayout, m)

    xOffset = m.width
    if m.homeGlyph <> invalid then
        yOffset = m.GetYOffsetAlignment(m.homeGlyph.font.GetOneLineHeight())
        xOffset = m.padding.right - m.homeGlyph.GetPreferredWidth()
        m.homeGlyph.SetColor(m.fgColor)
        m.homeGlyph.SetFrame(xOffset, yOffset, m.homeGlyph.GetPreferredWidth(), m.homeGlyph.GetPreferredHeight())
    else if m.image <> invalid then
        yOffset = m.GetYOffsetAlignment(m.image.GetPreferredHeight())
        xOffset = m.padding.right - m.image.GetPreferredWidth()
        m.image.SetFrame(xOffset, yOffset, m.image.GetPreferredWidth(), m.image.GetPreferredHeight())
    end if

    m.label.width = xOffset - m.padding.right
    yOffset = m.GetYOffsetAlignment(m.label.font.GetOneLineHeight())
    xOffset = m.padding.left
    m.label.SetColor(m.fgColor)
    m.label.SetFrame(xOffset, yOffset, m.label.GetPreferredWidth(), m.label.GetPreferredHeight())
end sub
