function ServerDropDownButtonClass() as object
    if m.ServerDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeDropDownButtonClass())
        obj.ClassName = "ServerDropDownButton"

        ' Method overrides
        obj.Init = sddbuttonInit
        obj.PerformLayout = sddbuttonPerformLayout

        ' Overlay overrides
        obj.GetComponents = sddoverlayGetComponents

        m.ServerDropDownButtonClass = obj
    end if

    return m.ServerDropDownButtonClass
end function

function createServerDropDownButton(server as object, font as object, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ServerDropDownButtonClass())

    obj.screen = screen
    obj.server = server
    obj.isSecure = (MyPlexAccount().isSecure and server.activeConnection <> invalid and server.activeConnection.isSecure)

    obj.Init(server.name, font)

    return obj
end function

sub sddbuttonInit(text as string, font as object)
    ApplyFunc(CompositeDropDownButtonClass().Init, m, [text, font])

    ' Custom fonts for the drop down options. These need to be references at this
    ' this level to conserve memory. Each drop down item will have a reference.
    m.customFonts = {
        title: FontRegistry().NORMAL,
        subtitle: FontRegistry().NORMAL,
        glyph: FontRegistry().GetIconFont(15),
    }

    ' Title
    m.title = createLabel(m.text, m.customFonts.title)
    m.AddComponent(m.title)

    ' PMS Logo
    m.image = createImage("pkg:/images/pms_logo_HD_26x26.png", 26, 26, invalid, "scale-to-fit")
    m.AddComponent(m.image)

    ' Indicator
    m.indicator = createLabel(Glyphs().D_TRIANGLE, m.customFonts.glyph)
    m.AddComponent(m.indicator)

    ' Lock
    if m.isSecure then
        m.lock = createLabel(Glyphs().PADLOCK, FontRegistry().GetIconFont(10))
        m.lock.SetColor(Colors().Green)
        m.lock.excludeGetPreferredWidth = true
        m.AddComponent(m.lock)
    end if

    ' Max and Min width of the drop down options (server/owner name dependent)
    m.dropdownMinWidth = 200
    m.dropdownMaxWidth = 450
end sub

sub sddbuttonPerformLayout()
    ApplyFunc(CompositeDropDownButtonClass().PerformLayout, m)

    ' Indicator
    yOffset = m.GetYOffsetAlignment(m.indicator.font.GetOneLineHeight())
    xOffset = m.width - m.padding.right - m.indicator.GetPreferredWidth()
    m.indicator.SetColor(m.fgColor)
    m.indicator.SetFrame(xOffset, yOffset, m.indicator.GetPreferredWidth(), m.indicator.GetPreferredHeight())

    ' PMS Logo
    yOffset = m.GetYOffsetAlignment(m.image.GetPreferredHeight())
    xOffset = xOffset - m.padding.right - m.image.GetPreferredWidth()
    m.image.SetFrame(xOffset, yOffset, m.image.GetPreferredWidth(), m.image.GetPreferredHeight())

    ' Lock
    if m.lock <> invalid then
        lockHeight = m.lock.GetPreferredHeight()
        lockWidth = m.lock.GetPreferredWidth()
        yOffset = computeRect(m.image).down - lockHeight + lockHeight/4
        xOffset = xOffset - lockWidth/4
        m.lock.SetFrame(xOffset, yOffset, lockWidth, lockHeight)
    end if

    ' Title
    m.title.width = xOffset - m.padding.right
    yOffset = m.GetYOffsetAlignment(m.title.font.GetOneLineHeight())
    xOffset = m.padding.left
    m.title.SetColor(m.fgColor)
    m.title.SetFrame(xOffset, yOffset, m.title.GetPreferredWidth(), m.title.GetPreferredHeight())
end sub
