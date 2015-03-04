function MediaDecisionEngine() as object
    if m.MediaDecisionEngine = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "MediaDecisionEngine"

        obj.ChooseMedia = mdeChooseMedia
        obj.EvaluateMediaVideo = mdeEvaluateMediaVideo
        obj.EvaluateMediaMusic = mdeEvaluateMediaMusic
        obj.CanDirectPlay = mdeCanDirectPlay
        obj.CanUseSoftSubs = mdeCanUseSoftSubs

        m.MediaDecisionEngine = obj
    end if

    return m.MediaDecisionEngine
end function

' TODO(schuyler): Do we need to allow this to be async? We may have to request
' the media again to fetch details, and we may need to make multiple requests to
' resolve an indirect. We can do it all async, we can block, or we can allow
' both.
'
function mdeChooseMedia(item as object) as object
    ' If we've already evaluated this item, use our previous choice.
    if item.mediaChoice <> invalid then return item.mediaChoice

    ' See if we're missing media/stream details for this item.
    if item.IsLibraryItem() and item.IsVideoItem() and item.mediaItems.Count() > 0 and not item.mediaItems[0].HasStreams() then
        ' TODO(schuyler): Fetch the details
        Fatal("Can't make media choice, missing details")
    end if

    ' Take a first pass through the media items to create a list of candidates
    ' that we'll evaluate more completely. If we find a forced item, we use it.
    ' If we find an indirect, we only keep a single candidate.

    candidates = CreateObject("roList")
    indirect = false

    maxResolution = AppSettings().GetMaxResolution(item.GetServer().IsLocalConnection())

    for each media in item.mediaItems
        if media.IsSelected() then
            candidates.Clear()
            candidates.AddTail(media)
            exit for
        end if

        if media.IsIndirect() then
            indirect = true
            if media.GetInt("height") <= maxResolution then
                candidates.Clear()
                candidates.AddTail(media)
                exit for
            end if
        end if

        candidates.AddTail(media)
    next

    if indirect then
        while candidates.Count() > 1
            candidates.RemoveTail()
        end while
    end if

    ' Now that we have a list of candidates, evaluate them completely.

    bestChoice = createMediaChoice(invalid)
    bestChoice.score = -1

    for each media in candidates
        if item.IsVideoItem() then
            choice = m.EvaluateMediaVideo(item, media)
        else if item.IsMusicItem() then
            choice = m.EvaluateMediaMusic(item, media)
        else
            choice = createMediaChoice(media)
        end if

        if choice.score > bestChoice.score then
            bestChoice = choice
        end if

        ' Our media items should have been sorted best to worst, so if we found
        ' something direct playable then we can stop evaluating options.
        '
        if (choice.isPlayable and choice.isDirectPlayable) then exit for
    next

    item.mediaChoice = bestChoice
    return bestChoice
end function

function mdeEvaluateMediaVideo(item as object, media as object) as object
    choice = createMediaChoice(media)
    settings = AppSettings()

    ' Resolve indirects before doing anything else.
    if media.IsIndirect() then
        media = media.ResolveIndirect()
    end if

    ' Assign a score to this media item. Items can earn points as follows:
    '
    ' 10000 - For being manually selected by the user
    '  5000 - For being accessible and available
    '  2000 - For being direct playable
    '  1080 - A point per vertical pixel, within our current limits
    '    20 - For potentially remuxable video streams
    '    10 - For potentially remuxable audio streams
    '
    choice.score = 0

    if media.IsSelected()
        choice.score = choice.score + 10000
    end if

    if media.IsAccessible() then
        choice.isPlayable = true
        choice.score = choice.score + 5000
    end if

    maxResolution = settings.GetMaxResolution(item.GetServer().IsLocalConnection())
    height = media.GetInt("height")
    if height <= maxResolution then
        choice.score = choice.score + height
    end if

    if choice.subtitleStream <> invalid then
        choice.isExternalSoftSub = m.CanUseSoftSubs(choice.subtitleStream)
    end if

    ' For evaluation purposes, we only care about the first part
    part = media.parts[0]
    if part = invalid then return choice

    ' TODO(schuyler): Assume that synced servers always have direct playable media

    ' Although PMS has already told us which streams are selected, we can't
    ' necessarily tell the video player which streams we want. So we need to
    ' iterate over the streams and see if there are any red flags that would
    ' prevent direct play. If there are multiple video streams, we're hosed.
    ' For audio streams, we have a fighting chance if the selected stream can
    ' be selected by language.

    numVideoStreams = 0
    stereoCodec = invalid
    surroundCodec = invalid
    surroundStreamFirst = false
    audioLanguageForceable = false

    if choice.audioStream <> invalid then
        audioLanguage = choice.audioStream.Get("languageCode", "unk")
        audioLanguageSeen = false
        maxChannels = iif(settings.SupportsSurroundSound(), 8, 2)
    end if

    if part.GetBool("hasChapterVideoStream") then numVideoStreams = 1

    for each stream in part.streams
        streamType = stream.GetInt("streamType")
        if streamType = stream.TYPE_VIDEO then
            numVideoStreams = numVideoStreams + 1

            if stream.Get("codec") = "h264" then
                choice.score = choice.score + 20
            end if
        else if streamType = stream.TYPE_AUDIO then
            numChannels = stream.GetInt("channels")
            if numChannels <= 2 then
                if stereoCodec = invalid then
                    stereoCodec = stream.Get("codec")
                    surroundStreamFirst = (surroundCodec <> invalid)
                end if
            else if surroundCodec = invalid then
                surroundCodec = stream.Get("codec")
            end if

            if audioLanguage = stream.Get("languageCode", "unk") and numChannels <= maxChannels then
                if stream.IsSelected() and not audioLanguageSeen then
                    audioLanguageForceable = true
                end if

                audioLanguageSeen = true
            end if

            if stream.Get("codec") = "aac" then
                choice.score = choice.score + 10
            end if
        end if
    next

    ' See if we found any red flags based on the streams. Otherwise, go ahead
    ' with our codec checks.

    if numVideoStreams > 1 then
        Info("MDE: Multiple video streams, won't try to direct play")
    else if choice.subtitleStream <> invalid and not choice.isExternalSoftSub then
        Info("MDE: Need to burn in subtitles")
    else if surroundStreamFirst and surroundCodec = "aac" then
        Info("MDE: First audio stream is 5.1 AAC")
    else if not audioLanguageForceable then
        Info("MDE: Secondary audio stream is selected and can't be forced by language")
    else if m.CanDirectPlay(media, part, choice.videoStream, choice.audioStream) then
        choice.isDirectPlayable = true
        choice.score = choice.score + 2000
    end if

    return choice
end function

function mdeCanDirectPlay(media as object, part as object, videoStream as object, audioStream as object) as boolean
    settings = AppSettings()
    maxResolution = settings.GetMaxResolution(media.GetServer().IsLocalConnection())
    height = media.GetInt("height")
    if height > maxResolution then
        Info("MDE: Video height is greater than max allowed: " + tostr(height) + " > " + tostr(maxResolution))
        return false
    end if

    ' TODO(schuyler): Is this a real concern? What should we do?
    if videoStream = invalid then
        Fatal("No video stream")
    end if

    ' Check current surround sound support
    if settings.SupportsSurroundSound() then
        surroundSoundAC3 = settings.GetBoolPreference("surround_sound_ac3")
        surroundSoundDCA = settings.GetBoolPreference("surround_sound_dca")
    else
        surroundSoundAC3 = false
        surroundSoundDCA = false
    end if

    container = media.Get("container")
    videoCodec = videoStream.Get("codec")
    if audioStream = invalid then
        audioCodec = invalid
    else
        audioCodec = audioStream.Get("codec")
    end if

    if container = "mp4" or container = "mov" or container = "m4v" then
        Debug("MDE: MP4 container looks OK, checking streams")

        if videoCodec <> "h264" and videoCodec <> "mpeg4" then
            Info("MDE: Unsupported video codec: " + tostr(videoCodec))
            return false
        end if

        ' TODO(schuyler): Fix ref frames check. It's more nuanced than this.
        if videoStream.GetInt("refFrames") > 8 then
            Info("MDE: Too many ref frames: " + videoStream.Get("refFrames", ""))
            return false
        end if

        if not ((surroundSoundAC3 and audioCodec = "ac3") or (audioCodec = "aac" and audioStream.GetInt("channels") <= 2)) then
            Info("MDE: Unsupported audio track: " + tostr(audioCodec))
            return false
        end if

        ' Those were our problems, everything else should be OK.
        return true
    else if container = "mkv" then
        Debug("MDE: MKV container looks OK, checking streams")

        if videoCodec <> "h264" and videoCodec <> "mpeg4" then
            Info("MDE: Unsupported video codec: " + tostr(videoCodec))
            return false
        end if

        ' TODO(schuyler): Fix ref frames check. It's more nuanced than this.
        if videoStream.GetInt("refFrames") > 8 then
            Info("MDE: Too many ref frames: " + videoStream.Get("refFrames", ""))
            return false
        end if

        if videoStream.GetInt("bitDepth") > 8 then
            Info("MDE: Bit depth too high: " + videoStream.Get("bitDepth", ""))
            return false
        end if

        if not ((surroundSoundAC3 and audioCodec = "ac3") or (surroundSoundDCA and audioCodec = "dca") or ((audioCodec = "aac" or audioCodec = "mp3") and audioStream.GetInt("channels") <= 2)) then
            Info("MDE: Unsupported audio track: " + tostr(audioCodec))
            return false
        end if

        ' Those were our problems, everything else should be OK.
        return true
    else if container = "hls" then
        Debug("MDE: Assuming HLS is direct playable")
        return true
    else
        Info("MDE: Unsupported container: " + tostr(container))
    end if

    return false
end function

function mdeCanUseSoftSubs(stream as object) as boolean
    ' Not if the user prefers them burned in
    if AppSettings().GetBoolPreference("hardsubtitles") then return false

    ' We only support soft subtitles for sidecar SRT.
    if stream.Get("codec") <> "srt" or stream.Get("key") = invalid then return false

    ' TODO(schuyler) If Roku adds support for non-Latin characters, remove
    ' this hackery. To the extent that we continue using this hackery, it
    ' seems that the Roku requires UTF-8 subtitles but only supports characters
    ' from Windows-1252. This should be the full set of languages that are
    ' completely representable in Windows-1252. PMS should specifically be
    ' returning ISO 639-2/B language codes.
    ' Update: Roku has added support for additional characters, but still only
    ' Latin characters. We can now basically support anything from the various
    ' ISO-8859 character sets, but nothing non-Latin.

    if m.SoftSubLanguages = invalid then
        m.SoftSubLanguages = {
            afr: 1,
            alb: 1,
            baq: 1,
            bre: 1,
            cat: 1,
            cze: 1,
            dan: 1,
            dut: 1,
            eng: 1,
            epo: 1,
            est: 1,
            fao: 1,
            fin: 1,
            fre: 1,
            ger: 1,
            gla: 1,
            gle: 1,
            glg: 1,
            hrv: 1,
            hun: 1,
            ice: 1,
            ita: 1,
            lat: 1,
            lav: 1,
            lit: 1,
            ltz: 1,
            may: 1,
            mlt: 1,
            nno: 1,
            nob: 1,
            nor: 1,
            oci: 1,
            pol: 1,
            por: 1,
            roh: 1,
            rum: 1,
            slo: 1,
            slv: 1,
            spa: 1,
            srd: 1,
            swa: 1,
            swe: 1,
            tur: 1,
            vie: 1,
            wel: 1,
            wln: 1,
        }
    end if

    code = stream.Get("languageCode")

    return (code = invalid or m.SoftSubLanguages.DoesExist(code))
end function

function mdeEvaluateMediaMusic(item as object, media as object) as object
    choice = createMediaChoice(media)
    settings = AppSettings()

    ' Resolve indirects before doing anything else.
    if media.IsIndirect() then
        media = media.ResolveIndirect()
    end if

    ' Assign a score to this media item. Items can earn points as follows:
    '
    ' 10000 - For being manually selected by the user
    '  5000 - For being accessible and available
    '  2000 - For being direct playable
    '
    choice.score = 0

    if media.selected = true then
        choice.score = choice.score + 10000
    end if

    if media.IsAccessible() then
        choice.isPlayable = true
        choice.score = choice.score + 5000
    end if

    ' We can generally get away with just looking at the codec, and we can get
    ' that from the media element. So we don't bother going into the
    ' part/streams.

    codec = media.Get("audioCodec", "invalid")
    container = media.Get("container", "invalid")

    canPlayCodec = settings.GetBoolPreference("directplay_" + codec)
    canPlayContainer = ((codec = container) or (container = "mp4" or container = "mka" or container = "mkv"))

    if canPlayCodec and canPlayContainer then
        choice.isDirectPlayable = true
        choice.score = choice.score + 2000
    else
        choice.isDirectPlayable = false
    end if

    ' TODO(schuyler): Assume that synced servers always have direct playable media

    return choice
end function
