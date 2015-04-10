function OptionsDropDownButtonClass() as object
    if m.OptionsDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeDropDownButtonClass())
        obj.ClassName = "OptionsDropDownButton"

        ' Method overrides
        obj.Init = oddbuttonInit
        obj.PerformLayout = oddbuttonPerformLayout

        m.OptionsDropDownButtonClass = obj
    end if

    return m.OptionsDropDownButtonClass
end function

function createOptionsDropDownButton(text as string, font as object, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(OptionsDropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font)

    return obj
end function

sub oddbuttonInit(text as string, font as object)
    ApplyFunc(CompositeDropDownButtonClass().Init, m, [text, font])

    ' Custom fonts for the drop down options. These need to be references at this
    ' this level to conserve memory. Each drop down item will have a reference.
    m.customFonts = {
        title: FontRegistry().NORMAL,
        glyph: FontRegistry().GetIconFont(11),
    }

    ' Title
    m.title = createLabel(m.text, m.customFonts.title)
    m.AddComponent(m.title)

    ' Avatar
    thumb = MyPlexAccount().thumb
    if thumb <> invalid then
        avatar = iif(instr(1, thumb, "gravatar") > 0, thumb + "&s=26", thumb)
        m.avatar = createImage(avatar, 26, 26)
        m.avatar.cache = true
        m.AddComponent(m.avatar)
    end if

    ' Indicator
    m.indicator = createLabel(Glyphs().D_TRIANGLE, m.customFonts.glyph)
    m.AddComponent(m.indicator)

    ' Max and Min width of the drop down options
    m.maxWidth = 400
    m.minWidth = 128
end sub

sub oddbuttonPerformLayout()
    ApplyFunc(CompositeDropDownButtonClass().PerformLayout, m)

    ' Indicator
    yOffset = m.GetYOffsetAlignment(m.indicator.font.GetOneLineHeight())
    xOffset = m.width - m.padding.right - m.indicator.GetPreferredWidth()
    m.indicator.SetColor(m.fgColor)
    m.indicator.SetFrame(xOffset, yOffset, m.indicator.GetPreferredWidth(), m.indicator.GetPreferredHeight())

    ' Avatar
    if m.avatar <> invalid then
        yOffset = m.GetYOffsetAlignment(m.avatar.GetPreferredHeight())
        xOffset = xOffset - m.padding.right - m.avatar.GetPreferredWidth()
        m.avatar.SetFrame(xOffset, yOffset, m.avatar.GetPreferredWidth(), m.avatar.GetPreferredHeight())
    end if

    ' Title
    m.title.width = xOffset - m.padding.right
    yOffset = m.GetYOffsetAlignment(m.title.font.GetOneLineHeight())
    xOffset = m.padding.left
    m.title.SetColor(m.fgColor)
    m.title.SetFrame(xOffset, yOffset, m.title.GetPreferredWidth(), m.title.GetPreferredHeight())
end sub
