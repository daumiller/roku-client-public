function HeaderClass() as object
    if m.HeaderClass = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(ContainerClass())

        ' Constants
        obj.bkgClr = &h000000e0
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

    m.logo = {
        image: "pkg:/images/plex_logo_HD_62x20.png",
        width: 62,
        height: 20,
        valign: "ALIGN_MIDDLE",
        yOffset: 10
    }

    m.buttons = {
        width: 128,
        height: 40,
        valign: "ALIGN_MIDDLE",
        spacing: 10,
        yOffset: 10,
        font: FontRegistry().font16
    }
end sub

function createHeader(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HeaderClass())

    obj.Init()

    obj.screen = screen

    return obj
end function

sub headerPerformLayout()
    m.needsLayout = false

    ' *** Background *** '
    background = createBlock(m.bkgClr)
    background.SetFrame(0, 0, m.width, m.height)
    m.AddComponent(background)

    ' *** Logo *** '
    hbox = createHBox(false, false, false, 0)
    hbox.SetFrame(m.left, m.logo.yOffset, m.logo.width, m.height)
    logo = createImage(m.logo.image, m.logo.width, m.logo.height)
    logo.pvalign = logo[m.logo.valign]
    hbox.AddComponent(logo)
    m.AddComponent(hbox)

    ' *** Buttons/DropDowns - depended on the screen type (TBD) *** '
    buttons = createObject("roList")
    if tostr(m.screen.screenName) = "Home Screen" then
        ' Server List Drop Down
        button = createDropDown(m.screen.server.name, m.buttons.font, int(720 * .80))
        button.width = m.buttons.width
        button.pvalign = button.ALIGN_MIDDLE
        ' TODO(?): PlexNet server list and sorted?
        servers = PlexServerManager().getServers()
        for each server in servers
            if server.isReachable() = true then
                button.options.push({text: server.name, command: "selected_server", font: m.buttons.font, height: 66, width: 128, metadata: server })
            end if
        end for
        buttons.push(button)

        ' Options Drop Down: Settings, Sign Out/In
        if MyPlexAccount().IsSignedIn then
            connect = {text: "Sign Out", command: "sign_out"}
        else
            connect = {text: "Sign In", command: "sign_in"}
        end if
        button = createDropDown(firstOf(MyPlexAccount().username, "Options"), m.buttons.font, int(720 * .80))
        button.width = m.buttons.width
        button.pvalign = button[m.buttons.valign]
        button.options.push({text: "Settings", command: "settings", font: m.buttons.font, height: 66, width: 128 })
        button.options.push({text: connect.text, command: connect.command, font: m.buttons.font, height: 66, width: 128 })
        buttons.push(button)
    else
        button = createButton("Go Home", m.buttons.font, "go_home")
        button.width = m.buttons.width
        button.pvalign = button[m.buttons.valign]
        buttons.push(button)
    end if

    ' *** Calculate the layout for the buttons *** '
    if buttons.count() > 0 then
        hbox = createHBox(false, false, false, m.buttons.spacing)
        for each button in buttons
            hbox.addComponent(button)
        end for
        numButtons = buttons.count()

        xOffset = (m.right - m.buttons.width*numButtons) - (m.buttons.spacing * numButtons-1) + m.buttons.spacing
        buttonsWidth = m.buttons.width*numButtons + (m.buttons.spacing * numButtons-1)
        hbox.setFrame(xOffset, m.buttons.yOffset, buttonsWidth, m.height)
        m.AddComponent(hbox)
    end if

    m.buttons.font = invalid
end sub
