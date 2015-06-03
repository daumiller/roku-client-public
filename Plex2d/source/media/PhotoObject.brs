function PhotoObjectClass() as object
    if m.PhotoObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "PhotoObject"

        obj.Build = poBuild

        m.PhotoObjectClass = obj
    end if

    return m.PhotoObjectClass
end function

function createPhotoObject(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PhotoObjectClass())

    obj.item = item
    obj.media = item.mediaItems[0]

    return obj
end function

function poBuild() as dynamic
    if m.media.parts <> invalid and m.media.parts[0] <> invalid then
        obj = CreateObject("roAssociativeArray")

        part = m.media.parts[0]
        path = firstOf(part.Get("key"), m.item.Get("thumb"))

        obj.url = m.item.GetServer().BuildUrl(path, true)

        Debug("Constructed photo item for playback: " + tostr(obj, 1))

        m.metadata = obj
    end if

    return m.metatdata
end function
