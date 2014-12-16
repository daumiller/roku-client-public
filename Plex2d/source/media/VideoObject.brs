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

    obj.Build()

    return obj
end function

function voBuild(transcode=invalid as dynamic) as object
    ' TODO(schuyler): Only temporarily forcing transcodes to prove that it works
    directPlay = false
    ' isdirectplayable = firstOf(transcode, m.choice.isdirectplayable)

    ' A lot of our content metadata is independent of the direct play decision.
    ' Add that first.

    obj = CreateObject("roAssociativeArray")
    obj.PlayStart = int(m.seekValue/1000)
    obj.Server = m.item.GetServer()
    obj.Title = m.item.GetLongerTitle()
    obj.ReleaseDate = m.item.Get("originallyAvailableAt")

    videoRes = m.media.GetInt("videoResolution")
    obj.HDBranded = videoRes >= 720
    obj.fullHD = videoRes >= 1080
    obj.StreamQualities = iif(videoRes >= 480 and AppSettings().GetGlobal("DisplayType") = "HDTV", ["HD"], ["SD"])

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
        m.BuildDirectPlay(obj, partIndex)
    else
        m.BuildTranscode(obj, partIndex)
    end if

    m.videoItem = obj

    Info("Constructed video item for playback: " + tostr(obj, 1))

    return m.videoItem
end function

sub voBuildTranscode(obj as object, partIndex as integer)
    ' TODO(schuyler): Kepler builds this URL in plexnet. And we build the
    ' image transcoding URL in plexnet. Should this move there?

    part = m.media.parts[partIndex]
    settings = AppSettings()

    ' TODO(schuyler): What if this is invalid?
    transcodeServer = m.item.GetTranscodeServer(true)

    obj.StreamFormat = "hls"
    obj.StreamBitrates = [0]
    obj.SwitchingStrategy = "no-adaptation"
    obj.IsTranscoded = true

    builder = createHttpRequest(transcodeServer.BuildUrl("/video/:/transcode/universal/start.m3u8", true))

    builder.AddParam("protocol", "hls")
    builder.AddParam("path", m.item.GetAbsolutePath("key"))
    builder.AddParam("session", settings.GetGlobal("clientIdentifier"))
    builder.AddParam("waitForSegments", "1")
    builder.AddParam("offset", tostr(int(m.seekValue/1000)))
    builder.AddParam("directPlay", "0")

    ' TODO(schuyler): Based on settings
    builder.AddParam("directStream", "1")

    ' TODO(schuyler): Quality settings
    builder.AddParam("videoQuality", "100")
    builder.AddParam("videoResolution", "1280x720")
    builder.AddParam("maxVideoBitrate", "4000")

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
end sub

sub voBuildDirectPlay(obj as object, partIndex as integer)
    part = m.media.parts[partIndex]
    server = m.item.GetServer()

    obj.StreamUrls = [server.BuildUrl(part.GetAbsolutePath("key"))]
    obj.StreamFormat = m.media.Get("container", "mp4")
    obj.StreamBitrates = [m.media.Get("bitrate")]
    if obj.StreamFormat = "hls" then obj.SwitchingStrategy = "full-adaptation"
    obj.IsTranscoded = false

    if obj.StreamFormat = "mov" or obj.StreamFormat = "m4v" then
        obj.StreamFormat = "mp4"
    end if

    if m.audioStream <> invalid then
        obj.AudioLanguageSelected = m.audioStream.Get("languageCode")
    end if
end sub
