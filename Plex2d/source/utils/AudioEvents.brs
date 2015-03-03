function AudioEvents() as object
    if m.AudioEvents = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.OnKeyPress = audioeventsOnKeyPress
        obj.OnPress = audioeventsOnPress
        obj.OnRelease = audioeventsOnRelease
        obj.SetVolume = audioSetVolume

        ' Audio clips
        obj.clips = {}
        obj.clips.cursor = CreateObject("roAudioResource", "pkg:/audio/Cursor.wav")
        obj.clips.click = CreateObject("roAudioResource", "pkg:/audio/Click.wav")
        obj.clips.back = CreateObject("roAudioResource", "pkg:/audio/Back.wav")

        ' Key press mappings
        obj.keyPress = {}
        obj.keyPress["right"] = obj.clips.cursor
        obj.keyPress["left"] = obj.clips.cursor
        obj.keyPress["up"] = obj.clips.cursor
        obj.keyPress["down"] = obj.clips.cursor

        obj.keyPress["ok"] = obj.clips.click
        obj.keyPress["play"] = obj.clips.click

        obj.keyPress["back"] = obj.clips.back

        ' Key release mappings
        obj.keyRelease = {}

        ' Unused mappings
        ' obj.keyCodes["replay"] = obj.clips.click
        ' obj.keyCodes["rev"] = obj.clips.click
        ' obj.keyCodes["fwd"] = obj.clips.click
        ' obj.keyCodes["info"] = obj.clips.click

        obj.SetVolume(AppSettings().GetIntPreference("menu_volume"))

        Application().On("change:menu_volume", createCallable("SetVolume", obj))
        m.AudioEvents = obj
    end if

    return m.AudioEvents
end function

sub audioeventsOnKeyPress(keyCode as integer)
    if m.volume = 0 or AudioPlayer().isPlaying = true then return

    if keyCode >= 100 then
        m.OnRelease(KeyCodeToString(keyCode - 100))
    else
        m.OnPress(KeyCodeToString(keyCode))
    end if
end sub

sub audioeventsOnPress(key as string)
    if key = "back" and Locks().IsLocked("BackButton") then return

    if type(m.keyPress[key]) = "roAudioResource" then
        m.keyPress[key].Trigger(m.volume)
    end if
end sub

sub audioeventsOnRelease(key as string)
    if key = "back" and Locks().IsLocked("BackButton") then return

    if type(m.keyRelease[key]) = "roAudioResource" then
        m.keyRelease[key].Trigger(m.volume)
    end if
end sub

sub audioSetVolume(volume as dynamic)
    if not isint(volume) then volume = volume.toint()
    m.volume = volume
end sub
