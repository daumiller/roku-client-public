function HeaderClass() as object
    if m.HeaderClass = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(ContainerClass())

        ' Constants
        obj.width = 1280
        obj.height = 72
        obj.left = 50
        obj.right = 1230

        obj.PerformLayout = headerPerformLayout
        obj.Init = headerInit

        m.HeaderClass = obj
    end if

    return m.HeaderClass
end function

sub headerInit()
    ApplyFunc(ContainerClass().Init, m)

    m.customFonts = {
        buttons: FontRegistry().NORMAL
    }

    m.logo = {
        image: "pkg:/images/plex_logo_HD_62x20.png",
        width: 62,
        height: 20,
        valign: "ALIGN_MIDDLE",
        yOffset: 5,
    }

    m.buttons = {
        maxWidth: 400,
        minWidth: 50,
        height: 36,
        valign: "ALIGN_MIDDLE",
        spacing: 10,
        padding: 10,
        yOffset: 5,
    }
end sub

function createHeader(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HeaderClass())

    obj.Init()

    obj.zOrder = ZOrders().HEADER
    obj.screen = screen

    return obj
end function

sub headerPerformLayout()
    m.needsLayout = false

    ' *** Background *** '
    background = createBlock(Colors().OverlayDark)
    background.SetFrame(0, 0, m.width, m.height)
    background.zOrder = m.zOrder
    m.AddComponent(background)

    ' *** Mini Player *** '
    m.AddComponent(createMiniPlayer(m.screen))

    ' *** Logo *** '
    hbox = createHBox(false, false, false, 0)
    hbox.SetFrame(m.left, m.logo.yOffset, m.logo.width, m.height)
    logo = createImage(m.logo.image, m.logo.width, m.logo.height)
    logo.pvalign = logo[m.logo.valign]
    logo.zOrder = m.zOrder
    hbox.AddComponent(logo)
    m.AddComponent(hbox)

    ' *** Buttons/DropDowns - dependent on the current screen (TBD) *** '
    buttons = createObject("roList")
    if tostr(m.screen.screenName) = "Home Screen" then
        ' Server List Drop Down
        button = createServerDropDownButton(m.screen.server, m.customFonts.buttons, int(720 / 2), m.screen)
        button.SetPadding(0, m.buttons.padding, 0, m.buttons.padding)
        button.pvalign = button[m.buttons.valign]
        button.SetColor(Colors().Subtitle)
        button.zOrder = m.zOrder
        buttons.push(button)

        ' Options Drop Down: Settings, Sign Out/In
        button = createOptionsDropDownButton(firstOf(MyPlexAccount().title, "Options"), m.customFonts.buttons, int(720 / 2), m.screen)
        button.SetPadding(0, m.buttons.padding, 0, m.buttons.padding)
        button.pvalign = button[m.buttons.valign]
        button.GetOptions = headerGetOptions
        button.SetColor(Colors().Subtitle)
        button.zOrder = m.zOrder
        buttons.push(button)
    else
        button = createGoHomeButton(m.customFonts.buttons)
        button.SetPadding(0, m.buttons.padding, 0, m.buttons.padding)
        button.pvalign = button[m.buttons.valign]
        button.SetColor(Colors().Subtitle)
        button.zOrder = m.zOrder
        buttons.push(button)
    end if

    ' *** Calculate the layout for the buttons *** '
    if buttons.Count() > 0 then
        hbox = createHBox(false, false, false, m.buttons.spacing)
        buttonContWidth = 0
        for each button in buttons
            button.height = m.buttons.height
            buttonWidth = button.GetPreferredWidth()
            if buttonWidth > m.buttons.maxWidth then
                button.width = m.buttons.maxWidth
            else if buttonWidth < m.buttons.minWidth then
                button.width = m.buttons.minWidth
            end if
            buttonContWidth = buttonContWidth + button.GetPreferredWidth() + hbox.spacing
            hbox.addComponent(button)
        end for
        numButtons = buttons.Count()

        hbox.setFrame(m.right - buttonContWidth, m.buttons.yOffset, buttonContWidth, m.height)
        m.AddComponent(hbox)

        ' set the focus siblings for the mini player
        buttons[0].SetFocusSibling("left", MiniPlayer())
        MiniPlayer().SetFocusSibling("right", buttons[0])
    end if
end sub

function headerGetOptions() as object
    m.options.clear()
    font = FontRegistry().NORMAL

    mpa = MyPlexAccount()
    if mpa.IsSignedIn then
        m.options.push({text: "Switch User", command: "show_users", font: font, height: 66})
        if MyPlexAccount().isManaged then
            connect = invalid
        else
            connect = {text: "Sign Out", command: "sign_out"}
        end if
    else if mpa.IsOffline then
        connect = {text: "Offline Mode" }
    else
        connect = {text: "Sign In", command: "sign_in"}
    end if

    m.options.push({text: "Settings", command: "settings", font: font, height: 66})
    m.options.push({text: connect.text, command: connect.command, font: font, height: 66})

    return m.options
end function
