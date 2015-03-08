function ListenersMixin() as object
    if m.ListenersMixin = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.EnableListeners = listenersEnableListeners
        obj.DisableListeners = listenersDisableListeners
        obj.AddListener = listenersAddListener

        m.ListenersMixin = obj
    end if

    ' This is a sneaky way to make sure that the value is always true at
    ' the time that we're mixed in.
    '
    m.ListenersMixin.listenersOn = true

    return m.ListenersMixin
end function

sub listenersAddListener(subject as object, eventName as string, callback as object)
    if m.listeners = invalid then
        m.listeners = CreateObject("roList")
    end if

    m.listeners.Push({subject: subject, eventName: eventName, callback: callback})

    ' If our listeners are enabled, then immediately add this to the subject
    if m.listenersOn then
        subject.On(eventName, callback)
    end if
end sub

sub listenersEnableListeners()
    if m.listenersOn then return
    m.listenersOn = true

    if m.listeners <> invalid then
        for each listener in m.listeners
            listener.subject.On(listener.eventName, listener.callback)
        next
    end if
end sub

sub listenersDisableListeners(clear=false as boolean)
    if not m.listenersOn then return
    m.listenersOn = false

    if m.listeners <> invalid then
        for each listener in m.listeners
            listener.subject.Off(listener.eventName, listener.callback)
        next
        if clear then m.listeners.Clear()
    end if
end sub
