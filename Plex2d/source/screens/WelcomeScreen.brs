function WelcomeScreen()
    obj = m.WelcomeScreen

    if obj = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.Show = welcomeShow
        obj.HandleMessage = welcomeHandleMessage

        obj.reset()
        m.WelcomeScreen = obj
    end if

    ' TODO(schuyler): This is totally bogus, but it's easier to commit this as
    ' a working PoC of the Application stuff and then switch to roScreen instead
    ' of doing it all at once.
    obj.screen = CreateObject("roParagraphScreen")

    return obj
end function

function createWelcomeScreen()
    obj = CreateObject("roAssociativeArray")

    obj.append(BaseScreen())
    obj.append(WelcomeScreen())

    obj.reset()
    return obj
end function

sub welcomeShow(screen)
    m.screen.SetMessagePort(Application().port)
    m.screen.AddHeaderText("Welcome!")
    m.screen.AddParagraph("Nothing to see here")
    m.screen.AddButton(0, "close")
    m.screen.Show()

    ' TODO(schuyler): Remove, just a PoC
    m.OnTimerExpired = welcomeOnTimerExpired
    timer = createTimer("welcome")
    timer.SetDuration(5000, true)
    Application().AddTimer(timer, m)
end sub

function welcomeHandleMessage(msg)
    handled = false

    if type(msg) = "roParagraphScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Application().PopScreen(m)
        else if msg.isButtonPressed() then
            m.Screen.Close()
        end if
    end if

    return handled
end function

sub welcomeOnTimerExpired(timer)
    Debug(timer.name + " timer expired")
end sub
