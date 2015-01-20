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
        obj.Draw = headerDraw

        obj.OnPlay = headerOnPlay
        obj.OnStop = headerOnStop
        obj.OnPause = headerOnPause
        obj.OnResume = headerOnResume
        obj.OnProgress = headerOnProgress

        m.HeaderClass = obj
    end if

    return m.HeaderClass
end function

function headerDraw() as object
    m.EnableListeners()
    return ApplyFunc(ContainerClass().Draw, m)
end function

sub headerInit()
    ApplyFunc(ContainerClass().Init, m)

    m.logo = {
        image: "pkg:/images/plex_logo_HD_62x20.png",
        width: 62,
        height: 20,
        valign: "ALIGN_MIDDLE",
        yOffset: 5,
    }

    m.buttons = {
        width: 128,
        height: 40,
        valign: "ALIGN_MIDDLE",
        spacing: 10,
        yOffset: 5,
        font: FontRegistry().font16
    }

    ' Set up listeners for AudioPlayer and the MiniPlayer
    m.DisableListeners()
    player = AudioPlayer()
    m.AddListener(player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(player, "paused", CreateCallable("OnPause", m))
    m.AddListener(player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(player, "progress", CreateCallable("OnProgress", m))
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
    background = createBlock(Colors().OverlayVeryDark)
    background.SetFrame(0, 0, m.width, m.height)
    background.zOrder = m.zOrder
    m.AddComponent(background)

    ' *** Mini Player *** '
    m.AddComponent(MiniPlayer())

    ' *** Logo *** '
    hbox = createHBox(false, false, false, 0)
    hbox.SetFrame(m.left, m.logo.yOffset, m.logo.width, m.height)
    logo = createImage(m.logo.image, m.logo.width, m.logo.height)
    logo.pvalign = logo[m.logo.valign]
    logo.zOrder = m.zOrder
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
        button.zOrder = m.zOrder
        buttons.push(button)

        ' Options Drop Down: Settings, Sign Out/In
        button = createDropDown(firstOf(MyPlexAccount().title, "Options"), m.buttons.font, int(720 * .80), m.screen)
        button.width = m.buttons.width
        button.pvalign = button[m.buttons.valign]
        button.GetOptions = headerGetOptions
        button.zOrder = m.zOrder
        buttons.push(button)
    else
        button = createButton("Go Home", m.buttons.font, "go_home")
        button.width = m.buttons.width
        button.pvalign = button[m.buttons.valign]
        button.zOrder = m.zOrder
        buttons.push(button)
    end if

    ' *** Calculate the layout for the buttons *** '
    if buttons.Count() > 0 then
        hbox = createHBox(false, false, false, m.buttons.spacing)
        for each button in buttons
            hbox.addComponent(button)
        end for
        numButtons = buttons.Count()

        buttonsWidth = (m.buttons.width * numButtons) + (m.buttons.spacing * (numButtons - 1))
        hbox.setFrame(m.right - buttonsWidth, m.buttons.yOffset, buttonsWidth, m.height)
        m.AddComponent(hbox)

        ' set the focus siblings for the mini player
        buttons[0].SetFocusSibling("left", MiniPlayer())
        MiniPlayer().SetFocusSibling("right", buttons[0])
    end if

    m.buttons.font = invalid
end sub

' TODO(rob): sorted list, selected checkmark, info: offline|remote|update required?
function headerGetServerOptions() as object
    m.options.clear()
    MyPlexManager().RefreshResources()
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
        m.options.push({text: "Switch User", command: "show_users", font: font, height: 66, width: 128 })
        ' TODO(rob): should we use a full user switch page (above) or quick switch list of users (below)
        ' for each user in mpa.homeUsers
        '     ' TODO(rob): custom button: crown, selected checkmark, pin, avatar
        '     m.options.push({text: user.title, command: "switch_user", metadata: user, font: font, height: 66, width: 128 })
        ' end for
    else
        connect = {text: "Sign In", command: "sign_in"}
    end if

    m.options.push({text: "Settings", command: "settings", font: font, height: 66, width: 128 })
    m.options.push({text: connect.text, command: connect.command, font: font, height: 66, width: 128 })

    return m.options
end function

sub headerOnPlay(player as object, item as object)
    mp = MiniPlayer()
    mp.SetTitle(item.Get("grandparentTitle", ""))
    mp.SetSubtitle(item.Get("title", ""))
    mp.SetImage(item)
    mp.Show()
end sub

sub headerOnStop(player as object, item as object)
    MiniPlayer().Hide(m.screen)
end sub

sub headerOnPause(player as object, item as object)
    ' anything we need here?
end sub

sub headerOnResume(player as object, item as object)
    MiniPlayer().Show()
end sub

sub headerOnProgress(player as object, item as object, time as integer)
    ' limit gratuitous screen updates as they are expensive.
    if player.IsPlaying and MiniPlayer().SetProgress(time, item.GetInt("duration")) then
        MiniPlayer().Show()
    end if
end sub
