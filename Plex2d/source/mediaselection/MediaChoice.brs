function MediaChoiceClass() as object
    if m.MediaChoiceClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "MediaChoice"

        ' This is basically just a struct for the result of the MDE, not
        ' much to define on the class.

        obj.media = invalid
        obj.isPlayable = false
        obj.isDirectPlayable = false
        obj.videoStream = invalid
        obj.audioStream = invalid
        obj.subtitleStream = invalid
        obj.isExternalSoftSub = false

        obj.ToString = mcToString

        m.MediaChoiceClass = obj
    end if

    return m.MediaChoiceClass
end function

function createMediaChoice() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(MediaChoiceClass())

    return obj
end function

function mcToString() as string
    return "playable:" + tostr(m.isPlayable) + " direct:" + tostr(m.isDirectPlayable) + " " + tostr(m.media)
end function
