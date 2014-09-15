function BlockClass() as object
    if m.BlockClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "Block"

        ' This is actually a pretty bogus component, mostly used for testing.
        ' Things like basic drawing of a background color are handled by the
        ' base component, so we don't even have to do anything special here.

        m.BlockClass = obj
    end if

    return m.BlockClass
end function

function createBlock(color as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(BlockClass())

    obj.Init()

    obj.bgColor = color

    return obj
end function
