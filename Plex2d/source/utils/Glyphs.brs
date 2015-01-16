function Glyphs() as object
    if m.Glyphs = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants (glyph mappings)
        obj.CHECK       = chr(&he207)
        obj.CIR_CHECK   = chr(&he194)
        obj.CIR_MINUS   = chr(&he192)
        obj.ELLIPSIS    = chr(&he188)

        obj.PLAY        = chr(&he174)
        obj.PAUSE       = chr(&he175)
        obj.RESUME      = chr(&he17e)
        obj.STEP_FWD    = chr(&he179)
        obj.STEP_REV    = chr(&he171)
        obj.STOP        = chr(&he176)
        ' TODO(rob): add the repeat glyph into the custom ttf
        obj.REPEAT      = chr(&he230)

        obj.STAR_FULL   = chr(&he050)
        obj.STAR_HALF   = chr(&he04f)
        obj.STAR_EMPTY  = chr(&he049)
        obj.DEL_LABEL   = chr(&he257)
        obj.CONFIG      = chr(&he281)
        obj.HOME        = chr(&he029)
        obj.SEARCH      = chr(&he058)
        obj.FILM_STRIP  = chr(&he009)
        obj.TRAILER     = chr(&hf109)
        obj.CROWN       = chr(&h1f451)
        obj.LOCK        = chr(&h1f512)
        obj.UNLOCK      = chr(&he205)
        obj.SHUFFLE     = chr(&he084)
        obj.INFO        = chr(&he196)

        ' TODO(rob): verify which one is correct for the now playing screen
        obj.HAMBURGER   = chr(&he519)
        obj.LIST        = chr(&he159)

        ' Constants Aliases
        obj.SCROBBLE    = obj.CIR_CHECK
        obj.UNSCROBBLE  = obj.CIR_MINUS
        obj.MORE        = obj.ELLIPSIS
        obj.BACKSPACE   = obj.DEL_LABEL
        obj.EXTRAS      = obj.FILM_STRIP

        m.Glyphs = obj
    end if

    return m.Glyphs
end function
