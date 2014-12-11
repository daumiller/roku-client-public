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
    isdirectplayable = firstOf(transcode, m.choice.isdirectplayable)
    if isdirectplayable then
        m.BuildDirectPlay()
    else
        m.BuildTranscode()
    end if
end function

sub voBuildTranscode()
    Fatal("voBuildTranscode::TB")
end sub

sub voBuildDirectPlay()
    ' TODO(rob): select curPart from seekValue. e.g. original: obj.curPart = metadata.SelectPartForOffset(seekValue)
    part = m.media.parts[0]

    ' TODO(rob): this is all sort of a mess. Transcoded material may also
    ' use some of the same info... definitely a temporary mess.
    obj = CreateObject("roAssociativeArray")
    obj.PlayStart = int(m.seekValue/1000)
    obj.Server = m.item.GetServer()

    obj.Title = m.item.GetLongerTitle()
    obj.ReleaseDate = m.item.Get("originallyAvailableAt")

    videoRes = m.media.Get("videoResolution")
    obj.HDBranded = val(videoRes) >= 720
    obj.fullHD = iif(videoRes = "1080", true, false)

    obj.StreamUrls = [m.item.GetServer().BuildUrl(part.Get("key"))]
    obj.StreamFormat = m.media.Get("container", "mp4")
    obj.StreamQualities = iif(appSettings().GetGlobal("DisplayType") = "HDTV", ["HD"], ["SD"])
    obj.StreamBitrates = [m.media.Get("bitrate")]
    if obj.StreamFormat = "hls" then obj.SwitchingStrategy = "full-adaptation"
    obj.IsTranscoded = false

    frameRate = m.media.Get("frameRate", "24p")
    if frameRate = "24p" then
        obj.FrameRate = 24
    else if frameRate = "NTSC"
        obj.FrameRate = 30
    end if

    ' TODO(rob): indexes (sd only) we can get fancy later...
    if part.Get("indexes") <> invalid then
        obj.SDBifUrl = m.item.GetServer().BuildUrl("/library/parts/" + part.Get("id") + "/indexes/sd?interval=10000")
    end if

    if m.audioStream <> invalid then
        obj.AudioLanguageSelected = m.audioStream.Get("languageCode")
    end if

    ' TODO(rob): subtitles
    'if part <> invalid AND part.subtitles <> invalid AND part.subtitles.Codec = "srt" AND part.subtitles.key <> invalid then
    '    obj.SubtitleUrl = FullUrl(m.serverUrl, "", part.subtitles.key) + "?encoding=utf-8"
    '    ' this forces showing the subtitle regardless of the Roku setting
    '    obj.SubtitleConfig = { ShowSubtitle: 1 }
    'end if

    Debug("Setting stream quality: " + tostr(obj.StreamQualities[0]))
    Debug("Will try to direct play " + tostr(obj.StreamUrls[0]))

    m.videoItem = obj
end sub
