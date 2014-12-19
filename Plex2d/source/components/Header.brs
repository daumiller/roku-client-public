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
        button = createDropDown(m.screen.server.name, m.buttons.font, int(720 * .80), m.screen)
        button.width = m.buttons.width
        button.pvalign = button[m.buttons.valign]
        button.GetOptions = headerGetServerOptions
        buttons.push(button)

        ' Options Drop Down: Settings, Sign Out/In
        button = createDropDown(firstOf(MyPlexAccount().title, "Options"), m.buttons.font, int(720 * .80), m.screen)
        button.width = m.buttons.width
        button.pvalign = button[m.buttons.valign]
        button.GetOptions = headerGetOptions
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

' TODO(rob): sorted list, selected checkmark, info: offline|remote|update required?
function headerGetServerOptions() as object
    m.options.clear()
    PlexServerManager().UpdateReachability(true)
    for each server in PlexServerManager().GetServers()
        if server.isReachable() = true then
            m.options.push({text: server.name, command: "selected_server", font: FontRegistry().font16, height: 66, width: 128, metadata: server })
        end if
    end for

    return m.options
end function

function headerGetOptions() as object
    m.options.clear()
    font = FontRegistry().font16

    mpa = MyPlexAccount()
    if mpa.IsSignedIn then
        connect = {text: "Sign Out", command: "sign_out"}
        mpa.UpdateHomeUsers()
        for each user in mpa.homeUsers
            ' TODO(rob): custom button: crown, selected checkmark, pin, avatar
            m.options.push({text: user.title, command: "switch_user", metadata: user, font: font, height: 66, width: 128 })
        end for
    else
        connect = {text: "Sign In", command: "sign_in"}
    end if

    sep = createBlock(&h333333ff)
    sep.height = 2
    sep.width = 128
    m.options.push({component: sep})
    m.options.push({text: "Settings", command: "settings", font: font, height: 66, width: 128 })
    m.options.push({text: connect.text, command: connect.command, font: font, height: 66, width: 128 })

    return m.options
end function
