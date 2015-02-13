function PlexStreamClass() as object
    if m.PlexStreamClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexAttributeCollectionClass())
        obj.ClassName = "PlexStream"

        ' Constants
        obj.TYPE_UNKNOWN = 0
        obj.TYPE_VIDEO = 1
        obj.TYPE_AUDIO = 2
        obj.TYPE_SUBTITLE = 3

        ' We have limited font support, so make a very modest effort at using
        ' English names for common unsupported languages.
        '
        obj.SAFE_LANGUAGE_NAMES = {
            ara: "Arabic",
            arm: "Armenian",
            bel: "Belarusian",
            ben: "Bengali",
            bul: "Bulgarian",
            chi: "Chinese",
            cze: "Czech",
            gre: "Greek",
            heb: "Hebrew",
            hin: "Hindi",
            jpn: "Japanese",
            kor: "Korean",
            rus: "Russian",
            srp: "Serbian",
            tha: "Thai",
            ukr: "Ukrainian",
            yid: "Yiddish"
        }

        ' Methods
        obj.GetTitle = pnstrGetTitle
        obj.GetCodec = pnstrGetCodec
        obj.GetChannels = pnstrGetChannels
        obj.GetLanguageName = pnstrGetLanguageName
        obj.GetSubtitlePath = pnstrGetSubtitlePath
        obj.IsSelected = pnstrIsSelected
        obj.SetSelected = pnstrSetSelected
        obj.ToString = pnstrToString
        obj.Equals = pnstrEquals

        m.PlexStreamClass = obj
    end if

    return m.PlexStreamClass
end function

function createPlexStream(xml as object) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(PlexStreamClass())

    obj.Init(xml)

    return obj
end function

function pnstrGetTitle() as string
    title = m.GetLanguageName()
    streamType = m.GetInt("streamType")

    if streamType = m.TYPE_AUDIO then
        codec = m.GetCodec()
        channels = m.GetChannels()

        if codec <> "" and channels <> "" then
            title = title + " (" + codec + " " + channels + ")"
        else if codec <> "" or channels <> "" then
            title = title + " (" + codec + channels + ")"
        end if
    else if streamType = m.TYPE_SUBTITLE then
        codec = m.GetCodec()
        suffix = iif(m.GetBool("forced"), " Forced)", ")")

        if codec <> "" then
            title = title + " (" + codec + suffix
        end if
    end if

    return title
end function

function pnstrGetCodec() as string
    codec = firstOf(m.Get("codec"), "")

    if codec = "dca" then
        codec = "DTS"
    else
        codec = UCase(codec)
    end if

    return codec
end function

function pnstrGetChannels() as string
    channels = m.GetInt("channels")

    if channels = 1 then
        return "Mono"
    else if channels = 2 then
        return "Stereo"
    else if channels > 0 then
        return (channels - 1).tostr() + ".1"
    else
        return ""
    end if
end function

function pnstrGetLanguageName() as string
    code = m.Get("languageCode")

    if code = invalid then return "Unknown"

    return firstOf(m.SAFE_LANGUAGE_NAMES[code], m.Get("language"), "Unknown")
end function

function pnstrGetSubtitlePath() as string
    query = "?encoding=utf-8"

    if m.Get("codec") = "smi" then
        query = query + "&format=srt"
    end if

    return m.Get("key") + query
end function

function pnstrIsSelected() as boolean
    return (m.GetInt("selected") = 1)
end function

sub pnstrSetSelected(selected as boolean)
    m.attrs["selected"] = iif(selected, "1", "0")
end sub

function pnstrToString() as string
    return m.GetTitle()
end function

function pnstrEquals(other as dynamic) as boolean
    if other = invalid then return false
    if m.ClassName <> other.ClassName then return false

    return m.AttributesMatch(other, ["streamType", "language", "codec", "channels", "index"])
end function

' Synthetic subtitle stream for 'none'

function NoneStream() as object
    if m.NoneStream = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(PlexStreamClass())

        obj.name = "Stream"
        obj.attrs = {id: "0", streamType: obj.TYPE_SUBTITLE}

        obj.GetTitle = function() :return "None" :end function

        m.NoneStream = obj
    end if

    return m.NoneStream
end function
