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
    ApplyFunc(GlyphButtonClass().Init, m, [text, font, " ", glyphFont])
    m.SetDirection(direction, false)
end sub

sub sortbuttonSetDirection(direction=invalid as dynamic, redraw=false as boolean)
    if m.glyphLabel = invalid or m.DoesExist("direction") and direction = m.direction then return
    m.direction = direction

    text = {
        up: Glyphs().ARROW_UP,
        down: Glyphs().ARROW_DOWN,
        asc: Glyphs().ARROW_UP,
        desc: Glyphs().ARROW_DOWN
    }

    m.glyphLabel.SetText(firstOf(text[tostr(direction)], " "))

    if redraw = true then
        m.Draw(true)
    end if
end sub
