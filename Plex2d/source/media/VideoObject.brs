function VideoObjectClass() as object
    if m.VideoObjectClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "VideoObject"

        obj.Build = voBuild
        obj.BuildTranscodeHls = voBuildTranscodeHls
        obj.BuildTranscodeMkv = voBuildTranscodeMkv
        obj.BuildDirectPlay = voBuildDirectPlay

        obj.HasMoreParts = voHasMoreParts
        obj.GoToNextPart = voGoToNextPart

        m.VideoObjectClass = obj
    end if

    return m.VideoObjectClass
end function

function createVideoObject(item as object, seekValue=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(VideoObjectClass())

    obj.item = item
    obj.seekValue = seekValue
    ' TODO(rob): `checkFiles` here? It's probable that we are playing an item
    ' from a play queue, and play queues do not support checkFiles. This means
    ' everything will be accessible and available when it may not be.
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
    if m.item.Get("extraTitle") <> invalid then
        obj.Title = m.item.Get("extraTitle")
        obj.hudTitle = m.item.GetLongerTitle()
    else
        obj.Title = m.item.GetLongerTitle()
    end if
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
    if m.choice.subtitleDecision = m.choice.SUBTITLES_SOFT_ANY then
        obj.SubtitleUrl = server.BuildUrl(m.choice.subtitleStream.GetSubtitlePath(), true)
        obj.SubtitleConfig = { ShowSubtitle: 1 }
    end if

    ' Create one content metadata object for each part and store them as a
    ' linked list. We probably want a doubly linked list, except that it
    ' becomes a circular reference nuisance, so we make the current item the
    ' base object and singly link in each direction from there.

    baseObj = obj
    prevObj = invalid
    startOffset = 0

    for partIndex = 0 to m.media.parts.Count() - 1
        part = m.media.parts[partIndex]
        partObj = CreateObject("roAssociativeArray")
        partObj.Append(baseObj)

        partObj.startOffset = startOffset

        if part.IsIndexed() then
            partObj.SDBifUrl = part.GetIndexUrl("sd")
            partObj.HDBifUrl = part.GetIndexUrl("hd")
        end if

        if directPlay then
            partObj = m.BuildDirectPlay(partObj, partIndex)
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
                partObj = m.BuildTranscodeMkv(partObj, partIndex, directStream)
            else
                partObj = m.BuildTranscodeHls(partObj, partIndex, directStream)
            end if
        end if

        ' Set up our linked list references. If we couldn't build an actual
        ' object then fail fast. Otherwise, see if we're at our start offset
        ' yet in order to decide if we need to link forwards or backwards.
        '
        if partObj = invalid then
            obj = invalid
            exit for
        else if int(m.seekValue/1000) >= startOffset then
            obj = partObj
            partObj.prevObj = prevObj
        else if prevObj <> invalid then
            prevObj.nextPart = partObj
        end if

        startOffset = startOffset + int(part.GetInt("duration") / 1000)

        prevObj = partObj
    end for

    ' Only set PlayStart for the initial part, and adjust for the part's offset
    if obj <> invalid then
        obj.PlayStart = int(m.seekValue/1000) - obj.startOffset
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
    builder.AddParam("directPlay", "0")
    builder.AddParam("directStream", iif(directStream, "1", "0"))

    seekOffset = int(m.seekValue/1000)
    if seekOffset >= obj.startOffset and seekOffset < obj.startOffset + int(part.GetInt("duration") / 1000) then
        startOffset = seekOffset - obj.startOffset
    else
        startOffset = 0
    end if

    builder.AddParam("offset", tostr(startOffset))

    if transcodeServer.IsLocalConnection() then
        qualityIndex = settings.GetIntPreference("local_quality")
    else
        qualityIndex = settings.GetIntPreference("remote_quality")
    end if
    builder.AddParam("videoQuality", settings.GetGlobal("transcodeVideoQualities")[qualityIndex])
    builder.AddParam("videoResolution", settings.GetGlobal("transcodeVideoResolutions")[qualityIndex])
    builder.AddParam("maxVideoBitrate", settings.GetGlobal("transcodeVideoBitrates")[qualityIndex])

    if m.choice.subtitleDecision = m.choice.SUBTITLES_SOFT_ANY then
        builder.AddParam("skipSubtitles", "1")
    end if

    builder.AddParam("partIndex", tostr(partIndex))

    ' Augment the server's profile for things that depend on the Roku's configuration.

    ' TODO(schuyler): Do we still need this to be tweakable? Can we move it to the profile?
    extras = "add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=41&isRequired=true)"

    settings = AppSettings()
    if settings.SupportsAudioStream("ac3", 6) then
        extras = extras + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=hls&audioCodec=ac3)"
        extras = extras + "+add-direct-play-profile(type=videoProfile&container=matroska&videoCodec=*&audioCodec=ac3)"
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

    obj.SubtitleUrl = invalid
    if m.choice.subtitleDecision = m.choice.SUBTITLES_BURN then
        builder.AddParam("subtitles", "burn")
    else
        builder.AddParam("subtitles", "muxed")
    end if

    builder.AddParam("partIndex", tostr(partIndex))

    ' Augment the server's profile for things that depend on the Roku's configuration.

    ' TODO(schuyler): Do we still need this to be tweakable? Can we move it to the profile?
    extras = "add-limitation(scope=videoCodec&scopeName=h264&type=upperBound&name=video.level&value=41&isRequired=true)"

    settings = AppSettings()
    if settings.SupportsSurroundSound() then
        for each codec in ["ac3", "eac3", "dca"]
            ' TODO(schuyler): Do we need to pass along the channel count?
            if settings.SupportsAudioStream(codec, 6) then
                extras = extras + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=http&audioCodec=" + codec + ")"
                extras = extras + "+add-direct-play-profile(type=videoProfile&container=matroska&videoCodec=*&audioCodec=" + codec + ")"
            end if
        next
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

function voHasMoreParts() as boolean
    return (m.metadata <> invalid and m.metadata.nextPart <> invalid)
end function

sub voGoToNextPart()
    oldPart = m.metadata
    if oldPart = invalid then return

    newPart = oldPart.nextPart
    if newPart = invalid then return

    newPart.prevPart = oldPart
    oldPart.nextPart = invalid
    m.metadata = newPart
end sub
