function PinScreen() as object
    if m.PinScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "PIN"

        obj.pollUrl = invalid
        obj.pinCode = invalid
        obj.hasError = false

        obj.GetComponents = pinGetComponents

        obj.RequestCode = pinRequestCode
        obj.OnCodeResponse = pinOnCodeResponse
        obj.OnPollResponse = pinOnPollResponse
        obj.OnPollTimer = pinOnPollTimer

        obj.OnItemSelected = pinOnItemSelected

        m.PinScreen = obj
    end if

    return m.PinScreen
end function

function createPinScreen() as object
    Debug("######## Creating PIN roScreen ########")

    obj = CreateObject("roAssociativeArray")
    obj.Append(PinScreen())

    obj.Init()

    ' Intialize custom fonts for this screen
    obj.customFonts.pin = FontRegistry().GetTextFont(150, true)
    obj.customFonts.welcome = FontRegistry().GetTextFont(32)
    obj.customFonts.info = FontRegistry().font16

    ' Request a code
    obj.RequestCode()

    return obj
end function

sub pinRequestCode()
    ' Kick off a request for the real pin
    m.pinCode = invalid
    m.pollUrl = invalid
    request = createMyPlexRequest("/pins.xml")
    context = request.CreateRequestContext("code", createCallable("OnCodeResponse", m))
    Application().StartRequest(request, context, "")

    ' Create a timer for polling to see if the code has been linked.
    m.pollTimer = createTimer("poll")
    m.pollTimer.SetDuration(5000, true)
    Application().AddTimer(m.pollTimer, createCallable("OnPollTimer", m))
end sub

sub pinOnCodeResponse(request as object, response as object, context as object)
    if response.IsSuccess() then
        m.pollUrl = response.GetResponseHeader("Location")
        xml = response.GetBodyXml()
        m.pinCode = xml.code.GetText()
        m.hasError = false
        m.Show()
        Debug("Got a PIN (" + tostr(xml.code.GetText()) + ") that expires at " + tostr(xml.GetNamedElements("expires-at").GetText()))
    else
        Debug("Request for new PIN failed: " + tostr(response.getStatus()) + " - " + tostr(response.getErrorString()))
        m.hasError = true
        m.Show()
    end if
end sub

sub pinOnPollResponse(request as object, response as object, context as object)
    if response.IsSuccess() then
        xml = response.GetBodyXml()
        if xml <> invalid then
            token = xml.auth_token.GetText()
            if len(token) > 0 then
                m.pollUrl = invalid
                Debug("TODO: Got a myPlex token" + tostr(token))
                MyPlexAccount().ValidateToken(token)
            end if
        end if
    else
        ' 404 is expected for expired pins, but treat all errors as expired
        Warn("Expired PIN, server response was " + tostr(response.getStatus()))
        m.pollUrl = invalid
        m.hasError = true
        m.Show()
    end if
end sub

sub pinOnPollTimer(timer as dynamic)
    if m.pollUrl <> invalid then
        ' Kick off a polling request
        Debug("Polling for PIN update at " + m.pollUrl)

        request = createMyPlexRequest(m.pollUrl)
        context = request.CreateRequestContext("poll", createCallable("OnPollResponse", m))
        Application().StartRequest(request, context)
    end if
end sub

sub pinOnItemSelected(item as object)
    ' TODO(schuyler): All of this. It depends on selectability, which depends on focusability.
    Debug("pinOnItemSelected::")

    ' check to see if se have a command requested for the area
    if item.area <> invalid then
        command = item.area.command
    else
        command = invalid
    end if

    ' process commands here
    if command <> invalid then
        Debug("process command: " + tostr(command))
        if command = "skipPinScreen" then
            ' TODO(schuyler): Go somewhere sensible. Replace this screen.
            Application().PushScreen(createComponentTestScreen())
        else if command = "refreshPinScreen" then
            ' Request a new code
            m.RequestCode()
        end if
    end if
end sub

sub pinGetComponents()
    ' TODO(schuyler): Can we avoid clearing and recreating all components?
    ' Not everything changes once it's created.

    ' TODO(schuyler): Make this pretty again. Rob's version was pretty.

    m.components.Clear()

    mainBox = createHBox(false, false, false, 50)
    mainBox.SetFrame(219, 200, 1000, 400)

    ' TODO(schuyler): Use an image component, not this lame stand-in.
    chevron = createBlock(Colors().PlexClr)
    chevron.width = 200
    chevron.height = 340
    mainBox.AddComponent(chevron)

    vb = createVBox(false, false, false, 5)

    welcomeLabel = createLabel("Welcome to Plex", m.customFonts.welcome)
    vb.AddComponent(welcomeLabel)

    if m.hasError then
        if m.pinCode <> invalid then
            infoLabel = createLabel("The PIN has expired. Please 'Refresh' to try again.", m.customFonts.info)
        else
            infoLabel = createLabel("A PIN could not be created. Please 'Refresh' to try again.", m.customFonts.info)
        end if
        infoLabel.SetColor(&hc23529ff)
        pinColor = Colors().ScrBkgClr
    else
        infoLabel = createLabel("From your browser, go to http://plex.tv/pin and enter this PIN:", m.customFonts.info)
        infoLabel.SetColor(Colors().PlexClr)
        pinColor = &hffffffff
    end if
    vb.AddComponent(infoLabel)

    pinDigits = createHBox(true, true, false, 20)
    for i = 1 to 4
        if m.pinCode <> invalid then
            pinDigit = createLabel(Mid(m.pinCode, i, 1), m.customFonts.pin)
        else
            pinDigit = createLabel("-", m.customFonts.pin)
        end if
        pinDigit.SetColor(pinColor, &h1f1f1fff)
        pinDigit.halign = pinDigit.JUSTIFY_CENTER
        pinDigit.width = 113
        pinDigits.AddComponent(pinDigit)
    end for
    vb.AddComponent(pinDigits)

    buttons = createHBox(false, false, false, 10)
    buttons.halign = buttons.JUSTIFY_RIGHT

    ' TODO(schuyler): We probably want a Button component that's similar to
    ' Label, but perhaps does things like set focusability by default and add a border?

    skipButton = createLabel("Skip", FontRegistry().font16)
    skipButton.halign = skipButton.JUSTIFY_CENTER
    skipButton.width = 72
    buttons.AddComponent(skipButton)

    if m.hasError then
        refreshButton = createLabel("Refresh", FontRegistry().font16)
        refreshButton.halign = refreshButton.JUSTIFY_CENTER
        refreshButton.width = 72
        buttons.AddComponent(refreshButton)
    end if

    vb.AddComponent(buttons)
    mainBox.AddComponent(vb)

    m.components.Push(mainBox)
end sub
