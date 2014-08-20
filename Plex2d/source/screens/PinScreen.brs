function PinScreen() as object
    if m.PinScreen = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.screenName = "PIN"
        obj.pollUrl = invalid

        obj.Show = pinShow
        obj.HandleMessage = pinHandleMessage
        obj.RequestCode = pinRequestCode
        obj.OnCodeResponse = pinOnCodeResponse
        obj.OnPollResponse = pinOnPollResponse
        obj.OnPollTimer = pinOnPollTimer
        obj.OnAccountChange = pinOnAccountChange

        obj.reset()
        m.PinScreen = obj
    end if

    return m.PinScreen
end function

function createPinScreen() as object
    obj = CreateObject("roAssociativeArray")

    obj.append(BaseScreen())
    obj.append(PinScreen())

    obj.screen = CreateObject("roCodeRegistrationScreen")

    obj.screen.SetTitle("Connect Plex account")
    obj.screen.AddParagraph("You know the drill.")
    obj.screen.AddParagraph(" ")
    obj.screen.AddFocalText("From your computer,", "spacing-dense")
    obj.screen.AddFocalText("go to plex.tv/pin", "spacing-dense")
    obj.screen.AddFocalText("and enter this code:", "spacing-dense")
    m.screen.SetRegistrationCode("retrieving code...")
    obj.screen.AddParagraph(" ")
    obj.screen.AddParagraph("This screen will automatically update once your Roku player has been linked to your Plex account.")

    obj.screen.AddButton(0, "get a new code")
    obj.screen.AddButton(1, "back")

    Application().On("change:user", createCallable("OnAccountChange", obj))

    obj.reset()
    return obj
end function

sub pinShow(screen)
    m.screen.Show()

    ' Kick off a request for the real pin
    m.RequestCode()

    ' Create a timer for polling to see if the code has been linked.
    timer = createTimer("poll")
    timer.SetDuration(5000, true)
    Application().AddTimer(timer, createCallable("OnPollTimer", m))
end sub

function pinHandleMessage(msg as object) as boolean
    handled = false

    if type(msg) = "roCodeRegistrationScreenEvent" then
        handled = true

        if msg.isScreenClosed() then
            Application().PopScreen(m)
        else if msg.isButtonPressed() then
            if msg.GetIndex(0) then
                m.RequestCode()
            else
                m.screen.Close()
            end if
        end if
    end if

    return handled
end function

sub pinRequestCode()
    m.screen.SetRegistrationCode("retrieving code...")

    request = createMyPlexRequest("/pins.xml")
    context = request.CreateRequestContext("code", createCallable("OnCodeResponse", m))
    Application().StartRequest(request, context, "")
end sub

sub pinOnCodeResponse(request as object, response as object, context as object)
    if response.IsSuccess() then
        m.pollUrl = response.GetResponseHeader("Location")
        xml = response.GetBodyXml()
        m.screen.SetRegistrationCode(xml.code.GetText())
    else
        Error("Request for new PIN failed")
        m.screen.SetRegistrationCode("error")
    end if
end sub

sub pinOnPollResponse(request as object, response as object, context as object)
    if response.IsSuccess() then
        xml = response.GetBodyXml()
        if xml <> invalid then
            token = xml.auth_token.GetText()
            if len(token) > 0 then
                MyPlexAccount().ValidateToken(token)
            end if
        end if
    else
        ' 404 is expected for expired pins, but treat all errors as expired
        Warn("Expiring PIN")
        m.screen.SetRegistrationCode("code expired")
        m.pollUrl = invalid
    end if
end sub

sub pinOnPollTimer(timer)
    if m.pollUrl <> invalid then
        ' Kick off a polling request
        Debug("Polling for PIN update at " + m.pollUrl)

        request = createMyPlexRequest(m.pollUrl)
        context = request.CreateRequestContext("poll", createCallable("OnPollResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

sub pinOnAccountChange(account)
    Debug("Account changed to " + tostr(account.username) + ", closing screen")
    m.screen.Close()
end sub
