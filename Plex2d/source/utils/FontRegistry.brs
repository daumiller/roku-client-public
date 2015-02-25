function FontRegistry() as object
    if m.FontRegistry = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.registry = CreateObject("roFontRegistry")
        obj.registry.Register("pkg:/fonts/opensans-regular-webfont.ttf")
        obj.registry.Register("pkg:/fonts/opensans-bold-webfont.ttf")
        obj.registry.Register("pkg:/fonts/glyphicons-roku.ttf")

        obj.GetTextFont = frGetTextFont
        obj.GetIconFont = frGetIconFont
        obj.HDtoSDFont = frHDtoSDFont

        ' TODO(schuyler): What's the best way to adjust requested font sizes
        ' for SD screens? At low sizes we're always doing `requested - 4`, but
        ' is that reasonable for huge sizes like on the PIN screen?

        ' Initialize some common fonts that are expected to be used on many
        ' screens. Anything more unusual should be initialized by the screen
        ' that needs it so that the font isn't kept in memory longer than
        ' necessary.

        obj.SMALL  = obj.GetTextFont(14)
        obj.MEDIUM = obj.GetTextFont(16)
        obj.NORMAL = obj.GetTextFont(18)
        obj.LARGE  = obj.GetTextFont(20)
        obj.LARGE_BOLD = obj.GetTextFont(20, true)

        m.FontRegistry = obj
    end if

    return m.FontRegistry
end function

function frGetTextFont(size as integer, bold=false as boolean, italic=false as boolean) as object
    return m.registry.GetFont("Open Sans", m.HDtoSDFont(size), bold, italic)
end function

function frGetIconFont(size as integer) as object
    return m.registry.GetFont("GLYPHICONS", m.HDtoSDFont(size), false, false)
end function

function frHDtoSDFont(fontSize as integer) as object
    ' anything less than 10 on SD looks _more_ horrible.
    minSize = 10
    size = HDtoSDHeight(fontSize) + 1
    if size < minSize then size = minSize

    return size
end function
