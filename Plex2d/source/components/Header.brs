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
        obj.Destroy = headerDestroy

        obj.SetTriggers = headerSetTriggers

        m.HeaderClass = obj
    end if

    return m.HeaderClass
end function

function headerDraw() as object
    m.SetTriggers().On()
    return ApplyFunc(ContainerClass().Draw, m)
end function

sub headerDestroy()
    m.SetTriggers().Off()
    ApplyFunc(ContainerClass().Destroy, m)
end sub

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
end sub

function createHeader(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HeaderClass())

    obj.Init()

    obj.zOrder = 200
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

function headerSetTriggers() as object
    if m.SetTriggersClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(TriggersClass())
        obj.Init()

        ' use a uniq component id
        id = m.uniqId

        ' Callback methods
        m.OnPlay = headerOnPlay
        m.OnStop = headerOnStop
        m.OnPause = headerOnPause
        m.OnResume = headerOnResume
        m.OnProgress = headerOnProgress

        ' Add("eventName", callback)
        obj.Add("audio:play", CreateCallable("OnPlay", m, id))
        obj.Add("audio:stop", CreateCallable("OnStop", m, id))
        obj.Add("audio:pause", CreateCallable("OnPause", m, id))
        obj.Add("audio:resume", CreateCallable("OnResume", m, id))
        obj.Add("audio:progress", CreateCallable("OnProgress", m, id))

        m.SetTriggersClass = obj
    end if

    return m.SetTriggersClass
end function

sub headerOnPlay(context as object, item as object)
    mp = MiniPlayer().Draw()
    mp.SetTitle(item.Get("grandparentTitle", ""))
    mp.SetSubtitle(item.Get("title", ""))
    mp.SetImage(item)
    mp.Show()
end sub

sub headerOnStop(context as object, item as object)
    MiniPlayer().Hide(m.screen)
end sub

sub headerOnPause(context as object, item as object)
    ' anything we need here?
end sub

sub headerOnResume(context as object, item as object)
    MiniPlayer().Show()
end sub

sub headerOnProgress(context as object, item as object, time as integer)
    ' limit gratuitous screen updates as they are expensive.
    if context.IsPlaying and MiniPlayer().SetProgress(time, item.GetInt("duration")) then
        MiniPlayer().Show()
    end if
end sub
