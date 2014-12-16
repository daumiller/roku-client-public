function VideoObjectClass() as object
    if m.VideoObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "VideoObject"

        obj.Build = voBuild
        obj.BuildTranscode = voBuildTranscode
        obj.BuildDirectPlay = voBuildDirectPlay

        m.VideoObjectClass = obj
    end if

    return m.VideoObjectClass
end function

function CreateVideoObject(item as object, seekValue=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(VideoObjectClass())

    obj.item = item
    obj.seekValue = seekValue
    obj.choice = MediaDecisionEngine().ChooseMedia(item)
    obj.media = obj.choice.media

    return obj
end function

function voBuild(directPlay=invalid as dynamic, directStream=true as boolean) as object
    directPlay = firstOf(directPlay, m.choice.isDirectPlayable)

    ' A lot of our content metadata is independent of the direct play decision.
    ' Add that first.

    obj = CreateObject("roAssociativeArray")
    obj.PlayStart = int(m.seekValue/1000)
    obj.Title = m.item.GetLongerTitle()
    obj.ReleaseDate = m.item.Get("originallyAvailableAt", "")
    obj.OrigReleaseDate = obj.ReleaseDate
    obj.duration = m.media.GetInt("duration")

    videoRes = m.media.GetInt("videoResolution")
    obj.HDBranded = videoRes >= 720
    obj.fullHD = videoRes >= 1080
    obj.StreamQualities = iif(videoRes >= 480 and AppSettings().GetGlobal("IsHD"), ["HD"], ["SD"])

    frameRate = m.media.Get("frameRate", "24p")
    if frameRate = "24p" then
        obj.FrameRate = 24
    else if frameRate = "NTSC"
        obj.FrameRate = 30
    end if

    ' TODO(schuyler): Subtitle support

    ' TODO(schuyler): Actual multipart support
    partIndex = 0
    part = m.media.parts[partIndex]

    if part.IsIndexed() then
        obj.SDBifUrl = part.GetIndexUrl("sd")
        obj.HDBifUrl = part.GetIndexUrl("hd")
    end if

    if directPlay then
        obj = m.BuildDirectPlay(obj, partIndex)
    else
        obj = m.BuildTranscode(obj, partIndex, directStream)
    end if

    m.videoItem = obj

    Info("Constructed video item for playback: " + tostr(obj, 1))

    return m.videoItem
end function

function voBuildTranscode(obj as object, partIndex as integer, directStream as boolean) as dynamic
    ' TODO(schuyler): Kepler builds this URL in plexnet. And we build the
    ' image transcoding URL in plexnet. Should this move there?

    part = m.media.parts[partIndex]
    settings = AppSettings()

    transcodeServer = m.item.GetTranscodeServer(true)
    if transcodeServer = invalid then return invalid

    obj.StreamFormat = "hls"
    obj.StreamBitrates = [0]
    obj.SwitchingStrategy = "no-adaptation"
    obj.IsTranscoded = true
    obj.transcodeServer = transcodeServer
    obj.ReleaseDate = obj.ReleaseDate + "   Transcoded"

    builder = createHttpRequest(transcodeServer.BuildUrl("/video/:/transcode/universal/start.m3u8", true))

    builder.AddParam("protocol", "hls")
    builder.AddParam("path", m.item.GetAbsolutePath("key"))
    builder.AddParam("session", settings.GetGlobal("clientIdentifier"))
    builder.AddParam("waitForSegments", "1")
    builder.AddParam("offset", tostr(int(m.seekValue/1000)))
    builder.AddParam("directPlay", "0")
    builder.AddParam("directStream", iif(directStream, "1", "0"))

    ' TODO(schuyler): Get quality from prefs, local vs. remote, etc.
    qualityIndex = 8
    builder.AddParam("videoQuality", settings.GetGlobal("transcodeVideoQualities")[qualityIndex])
    builder.AddParam("videoResolution", settings.GetGlobal("transcodeVideoResolutions")[qualityIndex])
    builder.AddParam("maxVideoBitrate", settings.GetGlobal("transcodeVideoBitrates")[qualityIndex])

    ' TODO(schuyler): Subtitles

    builder.AddParam("partIndex", tostr(partIndex))

    ' TODO(schuyler): Surround sound and profile augmentation

    ' TODO(schuyler): Can these be added from a helper?
    versionArr = settings.GetGlobal("rokuVersionArr")
    builder.AddParam("X-Plex-Platform", "Roku")
    builder.AddParam("X-Plex-Platform-Version", tostr(versionArr[0]) + "." + tostr(versionArr[1]))
    builder.AddParam("X-Plex-Version", settings.GetGlobal("appVersionStr"))
    builder.AddParam("X-Plex-Product", "Plex for Roku")
    builder.AddParam("X-Plex-Device", settings.GetGlobal("rokuModel"))

    obj.StreamUrls = [builder.GetUrl()]

    return obj
end function

function voBuildDirectPlay(obj as object, partIndex as integer) as dynamic
    part = m.media.parts[partIndex]
    server = m.item.GetServer()

    obj.StreamUrls = [server.BuildUrl(part.GetAbsolutePath("key"))]
    obj.StreamFormat = m.media.Get("container", "mp4")
    obj.StreamBitrates = [m.media.Get("bitrate")]
    if obj.StreamFormat = "hls" then obj.SwitchingStrategy = "full-adaptation"
    obj.IsTranscoded = false
    obj.ReleaseDate = obj.ReleaseDate + "   Direct Play (" + obj.StreamFormat + ")"

    if obj.StreamFormat = "mov" or obj.StreamFormat = "m4v" then
        obj.StreamFormat = "mp4"
    end if

    if m.audioStream <> invalid then
        obj.AudioLanguageSelected = m.audioStream.Get("languageCode")
    end if

    return obj
end function
