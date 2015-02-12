function PlayOptionsClass() as object
    if m.PlayOptionsClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PlayOptions"

        ' At the moment, this is really just a glorified struct. But the
        ' expected fields include key, shuffle, extraPrefixCount,
        ' and unwatched. We may give this more definition over time.

        ' These aren't widely used yet, but half inspired by a PMS discussion...
        obj.CONTEXT_AUTO = 0
        obj.CONTEXT_SELF = 1
        obj.CONTEXT_PARENT = 2
        obj.CONTEXT_CONTAINER = 3

        m.PlayOptionsClass = obj
    end if

    return m.PlayOptionsClass
end function

function createPlayOptions() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlayOptionsClass())

    obj.context = obj.CONTEXT_AUTO

    return obj
end function
