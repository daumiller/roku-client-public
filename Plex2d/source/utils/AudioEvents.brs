function AudioEvents() as object
    if m.AudioEvents = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.OnKeyPress = audioeventsOnKeyPress
        obj.OnPress = audioeventsOnPress
        obj.OnRelease = audioeventsOnRelease

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

        ' Audio volume. These clips are pretty quiet compared to default audio
        ' clips for standard screens. As of now, there is now way to query the
        ' roku "Menu Volume" setting, which is lame because we don't know if
        ' we should even play them, regardless of the expected volume. Does
        ' that me we need a custom pref?
        obj.volume = 100

        m.AudioEvents = obj
    end if

    return m.AudioEvents
end function

sub audioeventsOnKeyPress(keyCode as integer)
    if keyCode >= 100 then
        m.OnRelease(KeyCodeToString(keyCode - 100))
    else
        m.OnPress(KeyCodeToString(keyCode))
    end if
end sub

sub audioeventsOnPress(key as string)
    if type(m.keyPress[key]) = "roAudioResource" then
        m.keyPress[key].Trigger(m.volume)
    end if
end sub

sub audioeventsOnRelease(key as string)
    if type(m.keyRelease[key]) = "roAudioResource" then
        m.keyRelease[key].Trigger(m.volume)
    end if
end sub
