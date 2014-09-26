function PlexObjectClass() as object
    if m.PlexObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexObject"

        obj.type = invalid
        obj.container = invalid

        obj.Init = pnoInit
        obj.InitSynthetic = pnoInitSynthetic

        ' Helper methods
        obj.IsVideoItem = pnoIsVideoItem
        obj.IsMusicItem = pnoIsMusicItem
        obj.IsPhotoItem = pnoIsPhotoItem
        obj.IsVideoOrDirectoryItem = pnoIsVideoOrDirectoryItem
        obj.IsPhotoOrDirectoryItem = pnoIsPhotoOrDirectoryItem
        obj.IsDirectory = pnoIsDirectory
        obj.IsLibrarySection = pnoIsLibrarySection
        obj.IsLibraryItem = pnoIsLibraryItem
        obj.IsITunes = pnoIsITunes

        ' TODO(schuyler): There are a hundred more helper methods on here, but
        ' perhaps we can start adding them only when we're using them.

        obj.GetSingleLineTitle = pnoGetSingleLineTitle
        obj.GetLongerTitle = pnoGetLongerTitle

        obj.ToString = pnoToString

        m.PlexObjectClass = obj
    end if

    return m.PlexObjectClass
end function

sub pnoInit(container as object, xml as object)
    ApplyFunc(PlexAttributeCollectionClass().Init, m, [xml])

    m.type = firstOf(m.Get("type"), LCase(m.name))
    m.container = container

    ' Hack for photo albums
    if m.type = "photo" and m.IsDirectory() then
        m.type = "photoalbum"
    end if
end sub

sub pnoInitSynthetic(container as object, name as string)
    m.name = name
    m.type = LCase(name)
    m.container = container
    m.attrs = CreateObject("roAssociativeArray")
end sub

function pnoIsVideoItem() as boolean
    return (m.type = "movie" or m.type = "episode" or m.type = "clip" or m.type = "video")
end function

function pnoIsMusicItem() as boolean
    return (m.type = "track" or m.type = "album")
end function

function pnoIsPhotoItem() as boolean
    return (m.type = "photo")
end function

function pnoIsVideoOrDirectoryItem() as boolean
    return (m.IsVideoItem() or m.type = "season" or m.type = "show")
end function

function pnoIsPhotoOrDirectoryItem() as boolean
    return (m.IsPhotoItem() or m.type = "photoalbum")
end function

function pnoIsDirectory() as boolean
    return (m.name = "Directory" or m.name = "Playlist")
end function

function pnoIsLibrarySection() as boolean
    return (isnonemptystr(m.Get("agent")) or isnonemptystr(m.Get("serverName")))
end function

function pnoIsLibraryItem() as boolean
    return (instr(1, m.Get("key", ""), "/library/metadata") > 0)
end function

function pnoIsITunes() as boolean
    return (m.Get("identifier", "") = "com.plexapp.plugins.itunes")
end function

function pnoGetSingleLineTitle() as string
    if m.type = "episode" and m.Has("parentIndex") and m.Has("index") then
        return "S" + right("0" + m.Get("parentIndex"), 2) + " E" + right("0" + m.Get("index"), 2)
    end if

    return m.Get("title", "")
end function

function pnoGetLongerTitle() as string
    parentTitle = invalid
    childTitle = invalid

    if m.type = "episode" then
        parentTitle = m.Get("grandparentTitle")
        childTitle = m.GetSingleLineTitle()
    else if m.type = "season" then
        parentTitle = m.Get("parentTitle")
        childTitle = m.Get("title")
    else if m.type = "album" then
        parentTitle = m.Get("parentTitle")
        childTitle = m.Get("title")
    else if m.type = "track" then
        parentTitle = m.Get("grandparentTitle")
        childTitle = m.Get("title")
    end if

    if parentTitle <> invalid and childTitle <> invalid then
        return parentTitle + " - " + childTitle
    else
        return firstOf(parentTitle, childTitle, m.Get("title", ""))
    end if
end function

function pnoToString() as string
    return m.name + ": " + m.GetSingleLineTitle()
end function

function createPlexObjectFromElement(container as object, xml as object) as object
    if xml.GetName() = "Device" then
        return createPlexResource(container, xml)
    else if xml.GetName() = "Hub" then
        return createPlexHub(container, xml)
    else if xml.GetNamedElements("Media").Count() > 0 or container.Get("identifier") = "com.plexapp.plugins.itunes" then
        return createPlexItem(container, xml)
    end if

    Info("Don't know what to do with " + xml.GetName() + ", creating generic PlexObject")

    obj = CreateObject("roAssociativeArray")
    obj.Append(PlexObjectClass())
    obj.Init(container, xml)
    return obj
end function
