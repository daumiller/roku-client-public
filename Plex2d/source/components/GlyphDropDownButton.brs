function GlyphDropDownButtonClass() as object
    if m.GlyphDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(GlyphButtonClass())
        obj.Append(GenericDropDownButtonClass())

        obj.ClassName = "GlyphDropDownButton"

        ' Methods
        obj.Init = glddbInit

        m.GlyphDropDownButtonClass = obj
    end if

    return m.GlyphDropDownButtonClass
end function

function createGlyphDropDownButton(text as string, font as object, glyphText as string, glyphFont as object, screen as object, useIndicator=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GlyphDropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font, glyphText, glyphFont)

    obj.useIndicator = useIndicator

    return obj
end function

sub glddbInit(text as string, font as object, glyphText as string, glyphFont as object)
    ApplyFunc(GlyphButtonClass().Init, m, [text, font, glyphText, glyphFont])
    ApplyFunc(GenericDropDownButtonClass().Init, m)
end sub
