function Glyphs() as object
    if m.Glyphs = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants (glyph mappings)
        obj.CHECK       = chr(&he207)
        obj.CIR_CHECK   = chr(&he194)
        obj.CIR_MINUS   = chr(&he192)
        obj.CIR_X       = chr(&he193)
        obj.ELLIPSIS    = chr(&he188)

        obj.PLAY        = chr(&he174)
        obj.PLAY_MORE   = chr(&he170)
        obj.PAUSE       = chr(&he175)
        obj.RESUME      = chr(&he17e)
        obj.STEP_FWD    = chr(&he179)
        obj.STEP_REV    = chr(&he171)
        obj.STOP        = chr(&he176)

        ' Custom glyphs from the TV app
        obj.SHUFFLE     = chr(&he084)
        obj.REPEAT      = chr(&he085)
        obj.REPEAT_ONE  = chr(&he086)

        obj.STAR_FULL   = chr(&he050)
        obj.STAR_HALF   = chr(&he04f)
        obj.STAR_EMPTY  = chr(&he049)
        obj.DEL_LABEL   = chr(&he257)
        obj.DELETE      = chr(&he017)
        obj.CONFIG      = chr(&he281)
        obj.HOME        = chr(&he021)
        obj.SEARCH      = chr(&he058)
        obj.FILM_STRIP  = chr(&he009)
        obj.TRAILER     = chr(&hf109)
        obj.CROWN       = chr(&h1f451)
        obj.PADLOCK     = chr(&hf107)
        obj.LOCK        = chr(&h1f512)
        obj.UNLOCK      = chr(&he205)
        obj.INFO        = chr(&he196)
        obj.EQ          = chr(&hf10a)
        obj.LIST        = chr(&he159)
        obj.D_TRIANGLE  = chr(&h1f450)
        obj.ERROR       = chr(&he197)
        obj.ARROW_DOWN  = chr(&he000)
        obj.ARROW_UP    = chr(&he001)
        obj.ARROW_RIGHT = chr(&he224)
        obj.ARROW_LEFT  = chr(&he225)
        obj.EYE         = chr(&he002)
        obj.CIRCLE      = chr(&hf108)

        ' Constants Aliases
        obj.MORE        = obj.ELLIPSIS
        obj.BACKSPACE   = obj.DEL_LABEL
        obj.EXTRAS      = obj.FILM_STRIP

        m.Glyphs = obj
    end if

    return m.Glyphs
end function
