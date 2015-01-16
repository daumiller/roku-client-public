function TriggersClass() as object
    if m.TriggersClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "TriggersClass"

        ' Methods
        obj.Init = triggersInit
        obj.Add = triggersAdd
        obj.On = triggersOn
        obj.Off = triggersOff

        m.TriggersClass = obj
    end if

    return m.TriggersClass
end function

sub triggersInit()
    m.triggers = CreateObject("roList")
    m.triggersOn = false
end sub

sub triggersAdd(eventName as string, func as dynamic)
    m.triggers.Push({eventName: eventName, func: func})
end sub

sub triggersOn()
    if m.triggersOn then return
    m.triggersOn = true

    for each trigger in m.triggers
        Application().On(trigger.eventName, trigger.func)
    end for
end sub

sub triggersOff()
    if not m.triggersOn then return
    m.triggersOn = false

    for each trigger in m.triggers
        Application().Off(trigger.eventName, trigger.func)
    end for
end sub
