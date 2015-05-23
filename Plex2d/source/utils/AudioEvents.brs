function AudioEvents() as object
    if m.AudioEvents = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.OnKeyPress = audioeventsOnKeyPress
        obj.OnPress = audioeventsOnPress
        obj.OnRelease = audioeventsOnRelease

        ' Audio clips
        obj.clips = {
            select: CreateObject("roAudioResource", "select"),
            navsingle: CreateObject("roAudioResource", "navsingle")
            ' Unused audio clips
            ' navmulti: CreateObject("roAudioResource", "navmulti"),
            ' deadend: CreateObject("roAudioResource", "deadend")
        }

        ' Containers
        obj.keyPress = CreateObject("roAssociativeArray")
        obj.keyRelease = CreateObject("roAssociativeArray")

        ' Key press mappings
        obj.keyPress["right"]  = obj.clips.navsingle
        obj.keyPress["left"]   = obj.clips.navsingle
        obj.keyPress["up"]     = obj.clips.navsingle
        obj.keyPress["down"]   = obj.clips.navsingle
        obj.keyPress["back"]   = obj.clips.navsingle
        obj.keyPress["fwd"]    = obj.clips.navsingle
        obj.keyPress["rev"]    = obj.clips.navsingle
        obj.keyPress["ok"]     = obj.clips.select
        obj.keyPress["play"]   = obj.clips.select

        ' Unused mappings
        ' obj.keyPress["replay"] = obj.clips.click
        ' obj.keyPress["info"]   = obj.clips.click

        m.AudioEvents = obj
    end if

    return m.AudioEvents
end function

sub audioeventsOnKeyPress(keyCode as integer)
    if AudioPlayer().isPlaying = true then return

    if keyCode >= 100 then
        m.OnRelease(KeyCodeToString(keyCode - 100))
    else
        m.OnPress(KeyCodeToString(keyCode))
    end if
end sub

sub audioeventsOnPress(key as string)
    if type(m.keyPress[key]) = "roAudioResource" then
        m.keyPress[key].Trigger(50)
    end if
end sub

sub audioeventsOnRelease(key as string)
    if type(m.keyRelease[key]) = "roAudioResource" then
        m.keyRelease[key].Trigger(50)
    end if
end sub
