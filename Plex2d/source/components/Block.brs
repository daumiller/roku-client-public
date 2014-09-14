function BlockClass() as object
    if m.BlockClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "Block"

        obj.Draw = blockDraw

        m.BlockClass = obj
    end if

    return m.BlockClass
end function

function createBlock(color as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(BlockClass())

    obj.bgColor = color

    return obj
end function

sub blockDraw()
    m.InitRegion()
end sub
