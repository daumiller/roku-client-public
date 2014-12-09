function MediaDecisionEngine() as object
    if m.MediaDecisionEngine = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "MediaDecisionEngine"

        obj.ChooseMedia = mdeChooseMedia

        m.MediaDecisionEngine = obj
    end if

    return m.MediaDecisionEngine
end function

function mdeChooseMedia(item as object) as object
    ' If we've already evaluated this item, use our previous choice.
    if item.mediaChoice <> invalid then return item.mediaChoice

    choice = createMediaChoice()

    ' TODO(schuyler): Everything! This is just a stub to unblock the player.

    ' TODO(schuyler): What about parts?

    choice.media = item.mediaItems[0]
    part = choice.media.parts[0]

    choice.isPlayable = true
    choice.isDirectPlayable = true

    streams = PlexStreamClass()
    choice.videoStream = part.GetSelectedStreamOfType(streams.TYPE_VIDEO)
    choice.audioStream = part.GetSelectedStreamOfType(streams.TYPE_AUDIO)
    choice.subtitleStream = part.GetSelectedStreamOfType(streams.TYPE_SUBTITLE)

    item.mediaChoice = choice
    return choice
end function
