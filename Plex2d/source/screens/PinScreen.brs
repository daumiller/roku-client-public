function PinScreen() as object
    if m.PinScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "PIN"

        obj.pollUrl = invalid
        obj.pinCode = invalid
        obj.hasError = false

        obj.Init = pinInit
        obj.GetComponents = pinGetComponents

        obj.RequestCode = pinRequestCode
        obj.OnCodeResponse = pinOnCodeResponse
        obj.OnPollResponse = pinOnPollResponse
        obj.OnPollTimer = pinOnPollTimer

        obj.OnItemSelected = pinOnItemSelected
        obj.Activate = pinActivate

        m.PinScreen = obj
    end if

    return m.PinScreen
end function

sub pinInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts.pin = FontRegistry().GetTextFont(150, true)
    m.customFonts.welcome = FontRegistry().GetTextFont(32)
    m.customFonts.info = FontRegistry().font16
end sub

function createPinScreen(clearScreens=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PinScreen())

    obj.Init()

    if clearScreens then Application().clearScreens()

    ' TODO(rob): setting hasEntitlementError could be done on one line, but we
    ' also need to sign out the user without calling 'change:user'. We rely on
    ' change:user after pin validation, and that requires the ID's to differ
    obj.hasEntitlementError = (MyPlexAccount().isSignedIn and MyPlexAccount().isEntitled = false)
    if obj.hasEntitlementError
        MyPlexAccount().id = invalid
        obj.show()
    else
        ' Request a code
        obj.RequestCode()
    end if

    return obj
end function

sub pinActivate()
    ' Request a code
    m.Init()
    m.RequestCode()
end sub

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
                Debug("Got a myPlex token" + tostr(token))
                MyPlexAccount().ValidateToken(token, true)
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
    Debug("PIN item selected with command: " + tostr(item.command))

    if item.command <> invalid then
        if m.polltimer <> invalid then m.pollTimer.active = false

        ' TODO(rob): skip button removed, but we may need to allow it when
        ' we add support for IAP. Same concept goes for the loading screen.
        ' i.e. If the app isn't purchased, then we should just show the PIN
        ' screen immediately.
        if item.command = "refresh" then
            m.hasEntitlementError = false
            ' Request a new code
            m.RequestCode()
        end if
    end if
end sub

sub pinGetComponents()
    ' TODO(schuyler): Can we avoid clearing and recreating all components?
    ' Not everything changes once it's created.

    ' TODO(schuyler): Make this pretty again. Rob's version was pretty.

    m.DestroyComponents()

    mainBox = createHBox(false, false, false, 50)
    mainBox.SetFrame(219, 200, 1000, 320)

    chevron = createImage("pkg:/images/plex-chevron.png", 195, 320)
    mainBox.AddComponent(chevron)

    vb = createVBox(false, false, false, 5)

    titleBox = createHBox(false, false, false, m.customFonts.welcome.GetOneLineWidth(" ", 1280))
    welcomeLabel = createLabel("Welcome to Plex", m.customFonts.welcome)
    titleBox.AddComponent(welcomeLabel)
    if m.hasEntitlementError then
        previewLabel = createLabel("- Plex Pass Preview", m.customFonts.welcome)
        previewLabel.SetColor(Colors().TextDim)
        titleBox.AddComponent(previewLabel)
    end if
    vb.AddComponent(titleBox)

    if m.hasEntitlementError then
        infoLabel = createLabel("Plex Pass Required", m.customFonts.info)
        infoLabel.SetColor(Colors().Red)
    else if m.hasError then
        if m.pinCode <> invalid then
            infoLabel = createLabel("The PIN has expired. Please 'Refresh' to try again.", m.customFonts.info)
        else
            infoLabel = createLabel("A PIN could not be created. Please 'Refresh' to try again.", m.customFonts.info)
        end if
        infoLabel.SetColor(Colors().Red)
        pinColor = Colors().Background
    else
        infoLabel = createLabel("From your browser, go to http://plex.tv/pin and enter this PIN:", m.customFonts.info)
        infoLabel.SetColor(Colors().Orange)
        pinColor = Colors().Text
    end if
    vb.AddComponent(infoLabel)

    vb.AddSpacer(10)

    if m.hasEntitlementError then
        message = "We're sorry, this application is currently only available for Plex "
        message = message + "Pass subscribers. Don't worry though, we're working hard to have it "
        message = message + "ready for everyone very soon. Can't wait? Buy a Plex Pass now."
        msgLabel = createLabel(message, FontRegistry().font16)
        msgLabel.wrap = true
        msgLabel.SetFrame(0, 0, 500, FontRegistry().font16.getOneLineHeight() * 3)
        vb.AddComponent(msgLabel)
        vb.AddSpacer(10)
        urlLabel = createLabel("http://plex.tv/plexpass", FontRegistry().font16)
        urlLabel.SetColor(Colors().Orange)
        vb.AddComponent(urlLabel)
    else
        pinDigits = createHBox(true, true, false, 20)
        for i = 1 to 4
            if m.pinCode <> invalid then
                pinDigit = createLabel(Mid(m.pinCode, i, 1), m.customFonts.pin)
            else
                pinDigit = createLabel(" ", m.customFonts.pin)
            end if
            pinDigit.SetColor(pinColor, Colors().Button)
            pinDigit.halign = pinDigit.JUSTIFY_CENTER
            pinDigit.valign = pinDigit.ALIGN_MIDDLE
            pinDigit.width = 113
            pinDigit.height = 140
            pinDigits.AddComponent(pinDigit)
        end for
        vb.AddComponent(pinDigits)
    end if

    vb.AddSpacer(15)

    buttons = createHBox(false, false, false, 10)
    buttons.halign = buttons.JUSTIFY_RIGHT

    if m.hasError or m.hasEntitlementError then
        refreshButton = createButton(iif(m.hasEntitlementError, "Retry", "Refresh"), FontRegistry().font16, "refresh")
        refreshButton.SetColor(Colors().Text, Colors().Button)
        refreshButton.width = 72
        refreshButton.height = 44
        m.focusedItem = refreshButton
        buttons.AddComponent(refreshButton)
    end if

    vb.AddComponent(buttons)
    mainBox.AddComponent(vb)

    m.components.Push(mainBox)
end sub
