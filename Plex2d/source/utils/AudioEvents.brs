function AudioEvents() as object
    if m.AudioEvents = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.OnKeyPress = audioeventsOnKeyPress
        obj.OnPress = audioeventsOnPress
        obj.OnRelease = audioeventsOnRelease

        ' Audio clips
        obj.clips = {}
        obj.clips.select = CreateObject("roAudioResource", "select")
        obj.clips.navsingle = CreateObject("roAudioResource", "navsingle")
        obj.clips.navmulti = CreateObject("roAudioResource", "navmulti")
        obj.clips.deadend = CreateObject("roAudioResource", "deadend")

        ' Key press mappings
        obj.keyPress = {}
        obj.keyPress["right"] = obj.clips.navsingle
        obj.keyPress["left"] = obj.clips.navsingle
        obj.keyPress["up"] = obj.clips.navsingle
        obj.keyPress["down"] = obj.clips.navsingle
        obj.keyPress["back"] = obj.clips.navsingle

        obj.keyPress["fwd"] = obj.clips.navmulti
        obj.keyPress["rev"] = obj.clips.navmulti

        obj.keyPress["ok"] = obj.clips.select
        obj.keyPress["play"] = obj.clips.select

        ' Key release mappings
        obj.keyRelease = {}

        ' Unused mappings
        ' obj.keyCodes["replay"] = obj.clips.click
        ' obj.keyCodes["info"] = obj.clips.click

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
