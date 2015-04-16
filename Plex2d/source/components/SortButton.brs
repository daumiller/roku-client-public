function SortButtonClass() as object
    if m.SortButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(GlyphButtonClass())
        obj.ClassName = "SortButton"

        ' Methods
        obj.Init = sortbuttonInit
        obj.SetDirection = sortbuttonSetDirection

        m.SortButtonClass = obj
    end if

    return m.SortButtonClass
end function

function createSortButton(text as string, direction as dynamic, textFont as object, glyphFont as object, command as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SortButtonClass())

    obj.Init(text, textFont, direction, glyphFont)

    obj.command = command

    return obj
end function

sub sortbuttonInit(text as string, font as object, direction as dynamic, glyphFont as object)
    m.SetDirection(direction)
    ApplyFunc(GlyphButtonClass().Init, m, [text, font, m.glyphText, glyphFont])
end sub

sub sortbuttonSetDirection(direction=invalid as dynamic)
    if m.DoesExist("direction") and direction = m.direction then return
    m.direction = direction

    text = {
        up: Glyphs().ARROW_UP,
        down: Glyphs().ARROW_DOWN,
        asc: Glyphs().ARROW_UP,
        desc: Glyphs().ARROW_DOWN
    }

    m.glyphText = firstOf(text[tostr(direction)], " ")

    if m.glyphLabel <> invalid then
        m.glyphLabel.SetText(m.glyphText)
        m.Draw(true)
    end if
end sub
