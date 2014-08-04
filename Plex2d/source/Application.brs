function Application()
    obj = m.Application

    if obj = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.port = CreateObject("roMessagePort")
        obj.nextScreenID = 1
        obj.screens = []

        obj.AssignScreenID = appAssignScreenID
        obj.PushScreen = appPushScreen
        obj.PopScreen = appPopScreen

        obj.Run = appRun
        obj.ProcessOneMessage = appProcessOneMessage

        obj.reset()
        m.Application = obj
    end if

    return obj
end function

sub appAssignScreenID(screen)
    if screen.screenID = invalid then
        screen.screenID = m.nextScreenID
        m.nextScreenID = m.nextScreenID + 1
    end if
end sub

sub appPushScreen(screen)
    if m.screens.Count() > 0 then
        oldScreen = m.screens.Peek()
    else
        oldScreen = invalid
    end if

    m.AssignScreenID(screen)
    m.screens.Push(screen)

    if oldScreen <> invalid then
        oldScreen.Deactivate()
    end if

    screen.Show(invalid)
end sub

sub appPopScreen(screen)
    ' TODO(schuyler): There's much more logic and paranoia in the old version of
    ' this method. Is any warranted here?

    callActivate = true

    if screen.screenID <> m.screens.Peek().screenID then
        ' TODO(schuyler): Is this much of a concern now that we're not using
        ' standard dialogs? Presumably not...
        callActivate = false
    else
        screen.Destroy()
        m.screens.Pop()
    end if

    if m.screens.Count() > 0 and callActivate then
        m.screens.Peek().Activate(invalid)
    end if
end sub

sub appRun()
    print "Starting global message loop"

    ' TODO(schuyler): Not the best place for this presumably, but you get the idea...
    if m.screens.Count() = 0 then
        m.PushScreen(createWelcomeScreen())
    end if

    timeout = 0
    while m.screens.Count() > 0
        timeout = m.ProcessOneMessage(timeout)
    end while

    print "Finished global message loop"
end sub

function appProcessOneMessage(timeout)
    msg = wait(timeout, m.port)

    if msg <> invalid then
        print "Processing "; type(msg)
        m.screens.Peek().HandleMessage(msg)
    end if

    return 0
end function
