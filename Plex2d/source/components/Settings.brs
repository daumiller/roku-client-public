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
    m.height = 560
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)
    m.scrollHeight = m.y + m.height

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

    title = createLabel("Settings", FontRegistry().font18)
    title.halign = title.JUSTIFY_CENTER
    title.valign = title.ALIGN_MIDDLE
    title.zOrder = 100
    title.SetColor(Colors().TextClr, Colors().BtnBkgClr)
    title.SetFrame(m.x, m.y, m.width, 70)
    m.components.push(title)

    settingsBox = createHBox(true, true, true, 0)
    settingsBox.SetFrame(m.x, m.y + title.height, m.width, m.height)
    menuBox = createVBox(false, false, false, 0)
    listBox = createVBox(false, false, false, 0)
    settingsBox.AddComponent(menuBox)
    settingsBox.AddComponent(listBox)

    listBox.SetScrollable(m.scrollHeight)
    menuBox.SetScrollable(m.scrollHeight)

    prefs = settingsGetPrefs()
    for each key in prefs.keys
        title = createLabel(key, FontRegistry().font18)
        title.fixed = false
        title.SetColor(Colors().TextClr, Colors().BtnBkgClr and &hffffff90)
        title.SetDimensions(m.width, 60)
        title.SetPadding(0, 0, 0, m.padding)
        title.valign = title.ALIGN_MIDDLE
        title.zOrder = 100
        menuBox.AddComponent(title)
        first = true
        for each pref in prefs[key]
            btn = m.createButton(pref.title, pref.command)
            if first = true then
                btn.scrollOffset = title.height
                first = false
            end if
            btn.SetDimensions(m.width, 60)
            btn.zOrder = 100
            btn.SetPadding(0, 0, 0, m.padding*2)
            btn.OnFocus = settingsOnFocus
            btn.OnBlur = settingsOnBlur
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

    ' hide any menu options outside of the safe scrolling area
    for each comp in menuBox.components
        comp.SetVisibility(invalid, invalid, menuBox.y, menuBox.scrollHeight)
    end for

    m.screen.OnItemFocused(m.screen.focusedItem)
end sub

function settingsCreateButton(text as string, command as dynamic) as object
    btn = createButton(text, FontRegistry().font16, command)
    btn.focusInside = true
    btn.fixed = false
    btn.halign = m.JUSTIFY_LEFT

    ' special properties for the settings buttons
    btn.overlay = m
    btn.focusNonSiblings = false
    btn.OnSelected = settingsButtonOnSelected

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

function settingsGetPrefs() as object
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

    ' ** ADVANCED PREFS ** '
    advanced = CreateObject("roList")
    prefs.keys.push("Advanced")
    prefs.advanced = advanced

    ' locate/remote video qualities
    options1 = [
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

    options2 = [
        {title: "Tiny",   key: "tiny"},
        {title: "Small",  key: "small"},
        {title: "Normal", key: "normal"},
        {title: "Large",  key: "large"},
        {title: "Huge",   key: "huge"},
    ]

    advanced.Push({command: "testing1", title: "testing 1", options: options1, type: "radio"})
    advanced.Push({command: "testing2", title: "testing 2", options: options2, type: "radio"})
    advanced.Push({command: "testing3", title: "testing 3", options: options1, type: "radio"})
    advanced.Push({command: "testing4", title: "testing 4", options: options2, type: "radio"})
    advanced.Push({command: "testing5", title: "testing 5", options: options1, type: "radio"})
    advanced.Push({command: "testing6", title: "testing 6", options: options2, type: "radio"})

    return prefs
end function

sub settingsOnFocus()
    if tostr(m.listBox.curCommand) = m.command then
        ' TODO(rob): we can probably rip the focus sibling out when we keep
        ' state, as I'd expect we'll always focus to the selected pref
        m.SetFocusSibling("right", m.screen.lastFocusedItem)
        return
    end if
    m.listBox.curCommand = m.command

    ' highlight the focused item
    m.SetColor(Colors().TextClr, Colors().BtnBkgClr)
    m.draw(true)

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
    CompositorScreen().DrawComponent(m.listBox)
    m.SetFocusSibling("right", m.listBox.components[0])

    ' hide any options outside of the safe scrolling area
    for each comp in m.listBox.components
        comp.SetVisibility(invalid, invalid, m.listBox.y, m.listBox.scrollHeight)
    end for

    m.screen.screen.DrawAll()
end sub

sub settingsOnBlur(toFocus as object)
    if toFocus.options <> invalid then
        m.SetColor(Colors().TextClr)
        m.draw(true)
    end if
end sub

' From the context of the underlying screen. Process everything as
' we would, but intercept the back button and close the overlay.
sub settingsOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK then
        m.overlayScreen.Close()
    else
        m.SuperOnKeyRelease(keyCode)
    end if
end sub
