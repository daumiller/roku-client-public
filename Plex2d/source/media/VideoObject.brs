function VideoObjectClass() as object
    if m.VideoObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "VideoObject"

        obj.Build = voBuild
        obj.BuildTranscodeHls = voBuildTranscodeHls
        obj.BuildTranscodeMkv = voBuildTranscodeMkv
        obj.BuildDirectPlay = voBuildDirectPlay

        m.VideoObjectClass = obj
    end if

    return m.VideoObjectClass
end function

function createVideoObject(item as object, seekValue=0 as integer) as object
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
    server = m.item.GetServer()

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

    ' Add soft subtitle info
    if m.choice.isExternalSoftSub then
        obj.SubtitleUrl = server.BuildUrl(m.choice.subtitleStream.GetSubtitlePath(), true)
        obj.SubtitleConfig = { ShowSubtitle: 1 }
    end if

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
        ' TODO(schuyler): Do we need a preference here? Also, clean this up. If
        ' we're going to just use MKV, then this is fine. If we're going to
        ' support both, then we can reduce some code duplication.
        '
        ' TODO(schuyler): Actually, we can't seek an MKV transcode until we
        ' have full control over the seekbar and controls. So for now, we'll
        ' stick to HLS.
        '
        if server.SupportsFeature("mkv_transcode") and false then
            obj = m.BuildTranscodeMkv(obj, partIndex, directStream)
        else
            obj = m.BuildTranscodeHls(obj, partIndex, directStream)
        end if
    end if

    m.metadata = obj

    Info("Constructed video item for playback: " + tostr(obj, 1))

    return m.metadata
end function

function voBuildTranscodeHls(obj as object, partIndex as integer, directStream as boolean) as dynamic
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

    if transcodeServer.IsLocalConnection() then
        qualityIndex = settings.GetIntPreference("local_quality")
    else
        qualityIndex = settings.GetIntPreference("remote_quality")
    end if
    builder.AddParam("videoQuality", settings.GetGlobal("transcodeVideoQualities")[qualityIndex])
    builder.AddParam("videoResolution", settings.GetGlobal("transcodeVideoResolutions")[qualityIndex])
    builder.AddParam("maxVideoBitrate", settings.GetGlobal("transcodeVideoBitrates")[qualityIndex])

    if m.choice.isExternalSoftSub then
        builder.AddParam("skipSubtitles", "1")
    end if

    builder.AddParam("partIndex", tostr(partIndex))

    ' Augment the server's profile for things that depend on the Roku's configuration.

    ' TODO(schuyler): Do we still need this to be tweakable? Can we move it to the profile?
    extras = "add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=41&isRequired=true)"

    settings = AppSettings()
    if settings.SupportsSurroundSound() and settings.GetBoolPreference("surround_sound_ac3") then
        extras = extras + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=hls&audioCodec=ac3)"
    end if

    if Len(extras) > 0 then
        builder.AddParam("X-Plex-Client-Profile-Extra", extras)
    end if

    obj.StreamUrls = [builder.GetUrl()]

    return obj
end function

function voBuildTranscodeMkv(obj as object, partIndex as integer, directStream as boolean) as dynamic
    part = m.media.parts[partIndex]
    settings = AppSettings()

    transcodeServer = m.item.GetTranscodeServer(true)
    if transcodeServer = invalid then return invalid

    obj.StreamFormat = "mkv"
    obj.StreamBitrates = [0]
    obj.IsTranscoded = true
    obj.transcodeServer = transcodeServer
    obj.ReleaseDate = obj.ReleaseDate + "   Transcoded"

    builder = createHttpRequest(transcodeServer.BuildUrl("/video/:/transcode/universal/start.mkv", true))

    builder.AddParam("protocol", "http")
    builder.AddParam("path", m.item.GetAbsolutePath("key"))
    builder.AddParam("session", settings.GetGlobal("clientIdentifier"))
    builder.AddParam("offset", tostr(int(m.seekValue/1000)))
    builder.AddParam("directPlay", "0")
    builder.AddParam("directStream", iif(directStream, "1", "0"))

    if transcodeServer.IsLocalConnection() then
        qualityIndex = settings.GetIntPreference("local_quality")
    else
        qualityIndex = settings.GetIntPreference("remote_quality")
    end if
    builder.AddParam("videoQuality", settings.GetGlobal("transcodeVideoQualities")[qualityIndex])
    builder.AddParam("videoResolution", settings.GetGlobal("transcodeVideoResolutions")[qualityIndex])
    builder.AddParam("maxVideoBitrate", settings.GetGlobal("transcodeVideoBitrates")[qualityIndex])

    if m.choice.isExternalSoftSub then
        builder.AddParam("subtitles", "muxed")
        obj.SubtitleUrl = invalid
    end if

    builder.AddParam("partIndex", tostr(partIndex))

    ' Augment the server's profile for things that depend on the Roku's configuration.

    ' TODO(schuyler): Do we still need this to be tweakable? Can we move it to the profile?
    extras = "add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=41&isRequired=true)"

    settings = AppSettings()
    if settings.SupportsSurroundSound() then
        if settings.GetBoolPreference("surround_sound_ac3") then
            extras = extras + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=http&audioCodec=ac3)"
        end if

        if settings.GetBoolPreference("surround_sound_dca") then
            extras = extras + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=http&audioCodec=dca)"
        end if
    end if

    if Len(extras) > 0 then
        builder.AddParam("X-Plex-Client-Profile-Extra", extras)
    end if

    obj.StreamUrls = [builder.GetUrl()]

    return obj
end function

function voBuildDirectPlay(obj as object, partIndex as integer) as dynamic
    part = m.media.parts[partIndex]
    server = m.item.GetServer()

    obj.StreamUrls = [server.BuildUrl(part.GetAbsolutePath("key"), true)]
    obj.StreamFormat = m.media.Get("container", "mp4")
    obj.StreamBitrates = [m.media.Get("bitrate")]
    if obj.StreamFormat = "hls" then obj.SwitchingStrategy = "full-adaptation"
    obj.IsTranscoded = false
    obj.ReleaseDate = obj.ReleaseDate + "   Direct Play (" + obj.StreamFormat + ")"

    if obj.StreamFormat = "mov" or obj.StreamFormat = "m4v" then
        obj.StreamFormat = "mp4"
    end if

    if m.choice.audioStream <> invalid then
        obj.AudioLanguageSelected = m.choice.audioStream.Get("languageCode")
    end if

    return obj
end function
