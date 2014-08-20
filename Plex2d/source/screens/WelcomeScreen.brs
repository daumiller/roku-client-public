function WelcomeScreen()
    obj = m.WelcomeScreen

    if obj = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.screenName = "Welcome"

        obj.Show = welcomeShow
        obj.HandleMessage = welcomeHandleMessage
        obj.OnAccountChange = welcomeOnAccountChange
        obj.ReplaceScreen = welcomeReplaceScreen

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

    Application().On("change:user", createCallable("OnAccountChange", obj))

    obj.reset()
    return obj
end function

sub welcomeShow(screen)
    m.screen.SetMessagePort(Application().port)

    account = MyPlexAccount()

    if account.isSignedIn then
        m.screen.AddHeaderText("Welcome, " + account.username + "!")
        ' TODO(schuyler): Add servers as paragraphs

        m.screen.AddButton(2, "Sign out")
        m.screen.AddButton(0, "Close")
    else
        m.screen.AddHeaderText("Welcome!")

        m.screen.AddButton(1, "Sign in")
        m.screen.AddButton(0, "Close")
    end if

    m.screen.Show()
end sub

function welcomeHandleMessage(msg)
    handled = false

    if type(msg) = "roParagraphScreenEvent" then
        handled = true

        if msg.isScreenClosed() and not (m.ignoreCloseEvent = true) then
            if m.ignoreCloseEvent = true then
                m.ignoreCloseEvent = false
            else
                Application().PopScreen(m)
            end if
        else if msg.isButtonPressed() then
            if msg.GetIndex() = 1 then
                Application().PushScreen(createPinScreen())
            else if msg.GetIndex() = 2 then
                MyPlexAccount().SignOut()
            else
                m.Screen.Close()
            end if
        end if
    end if

    return handled
end function

sub welcomeOnAccountChange(account)
    Debug("Account changed, now: " + tostr(account.username))

    if Application().IsActiveScreen(m) then
        m.ReplaceScreen(invalid)
    else
        m.Activate = m.ReplaceScreen
    end if
end sub

sub welcomeReplaceScreen(ignored)
    oldScreen = m.screen
    m.ignoreCloseEvent = true
    m.Activate = BaseScreen().Activate

    m.screen = CreateObject("roParagraphScreen")
    m.Show(invalid)
    oldScreen.Close()
end sub
