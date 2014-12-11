function Glyphs() as object
    if m.Glyphs = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants (glyph mappings)
        obj.CHECK       = "a"
        obj.CIR_CHECK   = "b"
        obj.CIR_MINUS   = "c"
        obj.DOT         = "d"
        obj.ELLIPSIS    = "f"
        obj.PLAY        = "g"
        obj.RESUME      = "h"
        obj.STAR_FULL   = "i"
        obj.STAR_HALF   = "j"
        obj.STAR_EMPTY  = "k"
        obj.CONFIG      = "x"
        obj.HOME        = "y"
        obj.SEARCH      = "z"

        ' Constants Aliases
        obj.SCROBBLE    = obj.CIR_CHECK
        obj.UNSCROBBLE  = obj.CIR_MINUS
        obj.MORE        = obj.ELLIPSIS

        m.Glyphs = obj
    end if

    return m.Glyphs
end function
