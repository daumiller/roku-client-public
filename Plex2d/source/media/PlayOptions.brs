function PlayOptionsClass() as object
    if m.PlayOptionsClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PlayOptions"

        ' At the moment, this is really just a glorified struct. But the
        ' expected fields include continuous, key, shuffle, extraPrefixCount,
        ' and unwatched. We may give this more definition over time.

        m.PlayOptionsClass = obj
    end if

    return m.PlayOptionsClass
end function

function createPlayOptions() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PlayOptionsClass())

    ' Default to unwatched only. Playing all items is a secondary action.
    obj.unwatched = true

    return obj
end function
