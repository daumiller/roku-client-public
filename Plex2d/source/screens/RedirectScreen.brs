function RedirectScreen() as object
    if m.RedirectScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Official Redirect"

        obj.Init = redirectInit
        obj.GetComponents = redirectGetComponents
        obj.OnItemSelected = redirectOnItemSelected

        m.RedirectScreen = obj
    end if

    return m.RedirectScreen
end function

function createRedirectScreen(title as string, text as string) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(RedirectScreen())

    obj.Init()

    obj.title = title
    obj.text = text

    Application().clearScreens()

    return obj
end function

sub redirectInit()
    ApplyFunc(ComponentsScreen().Init, m)

    ' Intialize custom fonts for this screen
    m.customFonts.welcome = FontRegistry().GetTextFont(32)
    m.customFonts.info = FontRegistry().NORMAL
end sub

sub redirectOnItemSelected(item as object)
    launchAppId("13535")
end sub

sub redirectGetComponents()
    m.DestroyComponents()

    mainBox = createHBox(false, false, false, HDtoSDWidth(50))
    rect = { x: 219, y: 200, w: 1000, h: 320 }
    HDtoSD(rect)
    mainBox.SetFrame(rect.x, rect.y, rect.w, rect.h)

    chevron = createImage("pkg:/images/plex-chevron.png", HDtoSDWidth(195), HDtoSDHeight(320), invalid, "scale-to-fit")
    mainBox.AddComponent(chevron)
    m.components.Push(mainBox)

    width = HDtoSDWidth(600)
    vb = createVBox(false, false, false, HDtoSDWidth(5))
    mainBox.AddComponent(vb)

    ' Header (title)
    headerBox = createHBox(false, false, false, m.customFonts.welcome.GetOneLineWidth(" ", AppSettings().GetGlobal("displaySize").w))
    welcome1 = createLabel("Welcome to Plex", m.customFonts.welcome)
    welcome2 = createLabel("- Plex Pass Preview", m.customFonts.welcome)
    welcome2.SetColor(Colors().TextDim)
    headerBox.AddComponent(welcome1)
    headerBox.AddComponent(welcome2)
    vb.AddComponent(headerBox)

    ' Title info
    titleLabel = createLabel(m.title, m.customFonts.info)
    titleLabel.SetColor(Colors().Red)
    titleLabel.width = width
    titleLabel.halign = titleLabel.JUSTIFY_CENTER
    vb.AddComponent(titleLabel)
    vb.AddSpacer(HDtoSDHeight(10))

    ' Text info
    textLabel = createLabel(m.text, FontRegistry().NORMAL)
    textLabel.wrap = true
    textLabel.SetFrame(0, 0, width, FontRegistry().NORMAL.getOneLineHeight() * 6)
    vb.AddComponent(textLabel)
    vb.AddSpacer(HDtoSDHeight(10))

    ' Buttons
    buttons = createHBox(false, false, false, HDtoSDWidth(10))
    buttons.halign = buttons.JUSTIFY_RIGHT
    vb.AddComponent(buttons)

    button = createButton("Launch Offical channel", FontRegistry().NORMAL, "redirect")
    button.SetColor(Colors().Text, Colors().Button)
    button.SetPadding(HDtoSDWidth(10))
    m.focusedItem = button
    buttons.AddComponent(button)
end sub

sub launchAppId(appId as string)
    ' Channel Store + Plex ECP launch
    ip = GetFirstIPAddress()
    url = "http://" + ip + ":8060/launch/11?contentID=" + appId

    ' Check for existing Plex install
    obj = CreateObject("roURLTransfer")
    obj.SetURL("http://" + ip + ":8060/query/apps")
    response = obj.GetToString()
    xml = CreateObject("roXMLElement")
    if xml.Parse(response) and xml.app <> invalid then
        for each app in xml.app
            if app@id = appId then
                ' Direct ECP launch into Plex
                url = "http://" + ip + ":8060/launch/" + appId
                exit for
             end if
        end for
    end if

    ' Directly launch Plex or the Channel Store to install Plex
    port = CreateObject("roMessagePort")
    obj = CreateObject("roUrlTransfer")
    obj.SetUrl(url)
    obj.PostFromString("")
    while true
        msg = wait(0, port)
    end while
end sub
