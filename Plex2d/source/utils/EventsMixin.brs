' An incredibly simple events mixin inspired by Backbone.Events. Any class
' can append EventsMixin() to get event functionality. You can call `on` or
' `off` to register and clear callbacks, and `trigger` to fire an event.
'
' Note that the implementation is inspired by very early, very simple
' Backbone.Events. Some shortcuts and candy from later versions aren't
' included, but probably could be if the need arises.

function EventsMixin() as object
    if m.EventsMixin = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.On = eventsOn
        obj.Off = eventsOff
        obj.Trigger = eventsTrigger

        m.EventsMixin = obj
    end if

    return m.EventsMixin
end function

sub eventsOn(eventName as string, callback as object)
    if m.eventsCallbacks = invalid then
        m.eventsCallbacks = CreateObject("roAssociativeArray")
    end if

    callbacks = m.eventsCallbacks[eventName]
    if callbacks = invalid then
        callbacks = CreateObject("roList")
        m.eventsCallbacks[eventName] = callbacks
    end if

    callbacks.AddTail(callback)
end sub

sub eventsOff(eventName as dynamic, callback as dynamic)
    if m.eventsCallbacks = invalid then return

    if eventName = invalid then
        m.eventsCallbacks = invalid
    else
        if callback = invalid then
            m.eventsCallbacks.Delete(eventName)
        else
            callbacks = m.eventsCallbacks[eventName]
            if callbacks = invalid then return

            ' This is how annoying deleting from a list is, give or take.
            toRemove = -1
            for i = 0 to callbacks.Count() - 1
                if callback.Equals(callbacks[i]) then
                    toRemove = i
                    exit for
                end if
            next

            if toRemove <> -1 then
                callbacks.Delete(toRemove)
            end if
        end if
    end if
end sub

sub eventsTrigger(eventName as string, args as object)
    if m.eventsCallbacks = invalid then return

    callbacks = m.eventsCallbacks[eventName]
    if callbacks = invalid then return

    for each callback in callbacks
        callback.Call(args)
    next
end sub
