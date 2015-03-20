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

        ' Constants
        obj.SUBTITLES_DEFAULT = 0
        obj.SUBTITLES_BURN = 1
        obj.SUBTITLES_SOFT_DP = 2
        obj.SUBTITLES_SOFT_ANY = 3

        obj.subtitleDecision = obj.SUBTITLES_DEFAULT

        obj.ToString = mcToString

        m.MediaChoiceClass = obj
    end if

    return m.MediaChoiceClass
end function

function createMediaChoice(media as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(MediaChoiceClass())

    obj.media = media

    ' We generally just rely on PMS to have told us selected streams, so
    ' initialize our streams accordingly.
    '
    if media <> invalid then
        part = media.parts[0]

        if part <> invalid then
            streams = PlexStreamClass()
            obj.videoStream = part.GetSelectedStreamOfType(streams.TYPE_VIDEO)
            obj.audioStream = part.GetSelectedStreamOfType(streams.TYPE_AUDIO)
            obj.subtitleStream = part.GetSelectedStreamOfType(streams.TYPE_SUBTITLE)
        end if
    end if

    return obj
end function

function mcToString() as string
    return "playable:" + tostr(m.isPlayable) + " direct:" + tostr(m.isDirectPlayable) + " " + tostr(m.media)
end function
