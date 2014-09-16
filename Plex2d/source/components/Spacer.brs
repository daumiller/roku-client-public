function SpacerClass() as object
    if m.SpacerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "Spacer"

        obj.Draw = spacerDraw

        m.SpacerClass = obj
    end if

    return m.SpacerClass
end function

function createSpacer(width as integer, height as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SpacerClass())

    obj.Init()

    obj.width = width
    obj.height = height

    return obj
end function

function spacerDraw() as object
    return []
end function
