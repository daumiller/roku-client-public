' TODO(rob): converted DialogClass -- cleanup needed... just a POC for now

function SettingsClass() as object
    if m.SettingsClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        obj.ClassName = "SettingsClass"

        ' Methods
        obj.HandleButton = settingsHandleButton
        obj.OnKeyRelease = settingsOnKeyRelease
        obj.Show = settingsShow
        obj.Close = settingsClose
        obj.Init = settingsInit
        obj.CreateButton = settingsCreateButton
        obj.SetFrame = compSetFrame

        m.SettingsClass = obj
    end if

    return m.SettingsClass
end function

function createSettings(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SettingsClass())

    obj.screen = screen

    ' remember the current focus and invalidate it
    obj.fromFocusedItem = screen.focusedItem
    screen.lastFocusedItem = invalid
    screen.FocusedItem = invalid

    obj.Init()

    return obj
end function

sub settingsHandleButton(button as object)
    Debug("Settings button selected: command=" + tostr(button.command) + ", key=" + tostr(button.key))

    if button.command = "close" then
        m.Close()
    else
        Debug("command not defined: " + tostr(button.command))
    end if
end sub

sub settingsButtonOnSelected()
    m.overlay.HandleButton(m)
end sub

sub settingsInit()
    ' hacky? intercept the back button to handle the overlay closure
    m.screen.SuperOnKeyRelease = m.screen.OnKeyRelease
    m.screen.OnKeyRelease = m.OnKeyRelease
    m.screen.overlayScreen = m

    m.components = m.screen.GetManualComponents(m.ClassName)
    m.buttons = CreateObject("roList")

    ' TODO(rob) how do we handle dynamic width/height along with center placment?
    m.width = 660
    m.height = 610
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)

    m.padding = 10
end sub

function settingsClose() as boolean
    ' remove the onKeyRelease intercept
    m.screen.OnKeyRelease = m.screen.SuperOnKeyRelease
    m.screen.SuperOnKeyRelease = invalid
    m.screen.overlayScreen = invalid

    m.DestroyComponents()

    ' refocus on the item we initially came from
    m.screen.lastFocusedItem = invalid
    if m.fromFocusedItem <> invalid then
        m.screen.FocusedItem = m.fromFocusedItem
        m.screen.screen.DrawFocus(m.screen.focusedItem, true)
    else
        m.screen.screen.HideFocus(true, true)
    end if
end function

sub settingsShow()
    Application().CloseLoadingModal()

    ' TODO(rob): 1px border on settingsBox and between menu/list box
    settingsBox = createVBox(false, false, false, 0)
    settingsBox.SetFrame(m.x, m.y, m.width, m.height)

    title = createLabel("Settings", FontRegistry().font18)
    title.halign = title.JUSTIFY_CENTER
    title.valign = title.ALIGN_MIDDLE
    title.SetDimensions(m.width, 70)
    title.zOrder = 100
    title.SetColor(Colors().TextClr, Colors().BtnBkgClr)
    settingsBox.AddComponent(title)

    prefsBox = createHBox(true, true, true, 0)
    prefsBox.SetFrame(0, 0, m.width, m.height - title.height)
    menuBox = createVBox(false, false, false, 0)
    listBox = createVBox(false, false, false, 0)
    prefsBox.AddComponent(menuBox)
    prefsBox.AddComponent(listBox)
    settingsBox.AddComponent(prefsBox)

    prefs = settingsGetPrefs()
    for each key in prefs.keys
        title = createLabel(key, FontRegistry().font18)
        title.SetColor(Colors().TextClr, Colors().BtnBkgClr and &hffffff90)
        title.SetDimensions(m.width, 60)
        title.SetPadding(0, 0, 0, m.padding)
        title.valign = title.ALIGN_MIDDLE
        title.zOrder = 100
        menuBox.AddComponent(title)
        for each pref in prefs[key]
            btn = m.createButton(pref.title, pref.command)
            btn.SetDimensions(m.width, 60)
            btn.zOrder = 100
            btn.SetPadding(0, 0, 0, m.padding*2)
            btn.OnFocus = settingsOnFocus
            btn.listBox = listBox
            btn.screen = m.screen
            btn.options = pref.options
            menuBox.AddComponent(btn)
        end for
    end for

    m.components.push(settingsBox)

    dimmer = createBlock(Colors().ScrMedOverlayClr)
    dimmer.SetFrame(0, 0, 1280, 720)
    dimmer.zOrder = 98
    m.components.push(dimmer)

    bkg = createBlock(&h000000ff)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = 99
    m.components.push(bkg)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    m.screen.OnItemFocused(m.screen.focusedItem)
end sub

function settingsCreateButton(text as string, command as dynamic) as object
    btn = createButton(text, FontRegistry().font16, command)
    btn.fixed = true
    btn.halign = m.JUSTIFY_LEFT

    ' special properties for the settings buttons
    btn.overlay = m
    btn.focusNonSiblings = false
    btn.OnSelected = settingsButtonOnSelected

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

function settingsGetPrefs()
    ' TODO(rob): mark defaults or user selected prefs (state)
    prefs = CreateObject("roAssociativeArray")
    prefs.keys = CreateObject("roList")

    ' ** AUDIO PREFS ** '
    audio = CreateObject("roList")
    prefs.keys.push("Audio")
    prefs.audio = audio

    ' surround sound options
    options = [
        {title: "Dolby Digitial (AC3)", key: "ac3"},
        {title: "DTS (DCA)", key: "ac3"},
    ]
    audio.Push({command: "surround_list", title: "Receiver Capabilities", options: options, type: "checkbox"})

    ' volume boost
    options = [
        {title: "None",  key: "none"},
        {title: "Small", key: "small"},
        {title: "Large", key: "large"},
        {title: "Huge",  key: "huge"},
    ]
    audio.Push({command: "volume_boost", title: "Volume Boost", options: options, type: "radio"})

    ' ** VIDEO PREFS ** '
    video = CreateObject("roList")
    prefs.keys.push("Video")
    prefs.video = video

    ' locate/remote video qualities
    options = [
        {title: "20 Mbps",  key: "20"},
        {title: "12 Mbps",  key: "12"},
        {title: "10 Mbps",  key: "10"},
        {title: "8 Mbps",   key: "8"},
        {title: "4 Mbps",   key: "4"},
        {title: "3 Mbps",   key: "3"},
        {title: "2 Mbps",   key: "2"},
        {title: "1.5 Mbps", key: "1.5"},
        {title: "720 Kbps", key: "720"},
        {title: "320 Kbps", key: "320"},

    ]
    video.Push({command: "local_quality", title: "Local Streaming Quality", options: options, type: "radio"})
    video.Push({command: "remote_quality", title: "Remote Streaming Quality", options: options, type: "radio"})

    ' subtitle size
    options = [
        {title: "Tiny",   key: "tiny"},
        {title: "Small",  key: "small"},
        {title: "Normal", key: "normal"},
        {title: "Large",  key: "large"},
        {title: "Huge",   key: "huge"},
    ]
    video.Push({command: "subtitle_size", title: "Subtitle Size", options: options})

    return prefs
end function

function settingsOnFocus()
    'TODO(rob): better way to reinit the list box
    m.listBox.DestroyComponents()
    m.listBox.lastFocusableItem = invalid

    for each option in m.options
        btn = m.screen.overlayScreen.createButton(option.title, tostr(m.command))
        btn.key = option.key
        btn.SetDimensions(m.width, m.height)
        btn.zOrder = 100
        btn.SetPadding(0, 0, 0, m.padding.left)
        btn.SetFocusSibling("left", m)
        m.listBox.AddComponent(btn)
    end for

    m.SetFocusSibling("right", m.listBox.components[0])

    CompositorScreen().DrawComponent(m.listBox)
    m.screen.screen.DrawAll()
end function

' From the context of the underlying screen. Process everything as
' we would, but intercept the back button and close the overlay.
function settingsOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK then
        m.overlayScreen.Close()
    else
        m.SuperOnKeyRelease(keyCode)
    end if
end function
