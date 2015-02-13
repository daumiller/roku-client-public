function AudioObjectClass() as object
    if m.AudioObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "AudioObject"

        obj.Build = aoBuild
        obj.BuildTranscode = aoBuildTranscode
        obj.BuildDirectPlay = aoBuildDirectPlay

        m.AudioObjectClass = obj
    end if

    return m.AudioObjectClass
end function

function createAudioObject(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(AudioObjectClass())

    obj.item = item
    obj.choice = MediaDecisionEngine().ChooseMedia(item)
    obj.media = obj.choice.media

    return obj
end function

function aoBuild(directPlay=invalid as dynamic) as object
    directPlay = firstOf(directPlay, m.choice.isDirectPlayable)

    obj = CreateObject("roAssociativeArray")

    ' TODO(schuyler): Do we want/need to add anything generic here? Title? Duration?

    if directPlay then
        obj = m.BuildDirectPlay(obj)
    else
        obj = m.BuildTranscode(obj)
    end if

    m.metadata = obj

    Info("Constructed audio item for playback: " + tostr(obj, 1))

    return m.metadata
end function

function aoBuildTranscode(obj as object) as dynamic
    part = m.media.parts[0]
    settings = AppSettings()

    transcodeServer = m.item.GetTranscodeServer(true)
    if transcodeServer = invalid then return invalid

    obj.StreamFormat = "mp3"
    obj.IsTranscoded = true
    obj.transcodeServer = transcodeServer

    builder = createHttpRequest(transcodeServer.BuildUrl("/music/:/transcode/universal/start.mp3", true))

    builder.AddParam("protocol", "http")
    builder.AddParam("path", m.item.GetAbsolutePath("key"))
    builder.AddParam("session", settings.GetGlobal("clientIdentifier"))
    builder.AddParam("directPlay", "0")
    builder.AddParam("directStream", "0")

    obj.Url = builder.GetUrl()

    return obj
end function

function aoBuildDirectPlay(obj as object) as dynamic
    if m.media.parts <> invalid and m.media.parts[0] <> invalid then
        part = m.media.parts[0]
        obj.StreamFormat = m.media.Get("container", "mp3")
        obj.Url = m.item.GetServer().BuildUrl(part.GetAbsolutePath("key"), true)
        bitrate = m.media.GetInt("bitrate")

        if bitrate > 0 then
            obj.Streams = [{ url: obj.Url, bitrate: bitrate }]
        end if
    end if

    return obj
end function
