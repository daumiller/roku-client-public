function ServerDropDownButtonClass() as object
    if m.ServerDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(DropDownButtonClass())
        obj.ClassName = "ServerDropDownButton"

        ' Method overrides
        obj.Init = sddbuttonInit

        ' Overlay overrides
        obj.GetComponents = sddoverlayGetComponents
        obj.CreateButton = sddoverlayCreateButton

        m.ServerDropDownButtonClass = obj
    end if

    return m.ServerDropDownButtonClass
end function

function createServerDropDownButton(text as string, font as object, maxHeight as integer, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ServerDropDownButtonClass())

    obj.screen = screen
    obj.Init(text, font, maxHeight)

    return obj
end function

sub sddbuttonInit(text as string, font as object,  maxHeight as integer)
    ApplyFunc(DropDownButtonClass().Init, m, [text, font, maxHeight])

    ' Custom fonts for the drop down options. These need to be references at this
    ' this level to conserve memory. Each drop down item will have a reference.
    m.customFonts = {
        title: FontRegistry().font16,
        subtitle: FontRegistry().font12,
        glyph: FontRegistry().GetIconFont(12),
        status: FontRegistry().GetTextFont(20),
    }

    ' Max and Min width of the drop down options (server/owner name dependent)
    m.maxWidth = 400
    m.minWidth = 128
end sub
