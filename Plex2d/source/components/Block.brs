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

function createBlock(color as integer, region=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(BlockClass())

    if region <> invalid then
        obj.region = region
        obj.InitRegion = blockInitSharedRegion
    end if

    obj.Init()

    obj.bgColor = color

    return obj
end function

function blockInitSharedRegion() as object
    m.isSharedRegion = true

    ' Resize the shared region (for all) if the size changes. The key here is to
    ' use m.region.Set() so it replaces all other regions sharing this reference.
    if m.region <> invalid and (m.region.GetWidth() <> m.width or m.region.GetHeight() <> m.height) then
        m.region.Set(CreateRegion(m.width, m.height, m.bgColor, m.alphaEnable))
    end if

    ApplyFunc(ComponentClass().InitRegion, m)

    return [m]
end function
