function SettingsClass() as object
    if m.SettingsClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        obj.ClassName = "SettingsClass"

        ' Methods
        obj.Show = settingsShow
        obj.Close = settingsClose
        obj.Init = settingsInit
        obj.OnKeyRelease = settingsOnKeyRelease
        obj.CreateMenuButton = settingsCreateMenuButton
        obj.CreatePrefButton = settingsCreatePrefButton

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
            btn = m.createMenuButton(pref)
            if first = true then
                btn.scrollOffset = title.height
                first = false
            end if
            btn.SetDimensions(m.width, 60)
            btn.SetPadding(0, 0, 0, m.padding*2)
            btn.listBox = listBox
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

function settingsCreateMenuButton(pref as object) as object
    btn = createButton(pref.title, FontRegistry().font16, pref.command)
    btn.focusInside = true
    btn.fixed = false
    btn.halign = m.JUSTIFY_LEFT
    btn.zOrder = 100

    ' special properties for the menu buttons
    btn.overlay = m
    btn.screen = m.screen
    btn.focusNonSiblings = false
    btn.options = pref.options
    btn.prefType = pref.prefType

    btn.OnOkButton = "right"

    btn.OnSelected = settingsButtonOnSelected
    btn.OnFocus = settingsOnFocus
    btn.OnBlur = settingsOnBlur

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

sub settingsButtonOnSelected()
    m.screen.OnKeyPress(m.screen.kp_RT, false)
end sub

function settingsCreatePrefButton(text as string, command as dynamic, value as string, prefType) as object
    btn = createButtonPref(text, FontRegistry().font16, command, value, prefType)
    btn.focusInside = true
    btn.fixed = false
    btn.halign = m.JUSTIFY_LEFT
    btn.zOrder = 100

    ' special properties for the settings buttons
    btn.overlay = m
    btn.focusNonSiblings = false

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
        {title: "Dolby Digitial (AC3)", value: "ac3"},
        {title: "DTS (DCA)", value: "dca"},
    ]
    audio.Push({command: "surround_sound", title: "Receiver Capabilities", options: options, prefType: "bool"})

    ' volume boost
    options = [
        {title: "None",  value: "none"},
        {title: "Small", value: "small"},
        {title: "Large", value: "large"},
        {title: "Huge",  value: "huge"},
    ]
    audio.Push({command: "volume_boost", title: "Volume Boost", options: options, prefType: "enum"})

    ' ** VIDEO PREFS ** '
    video = CreateObject("roList")
    prefs.keys.push("Video")
    prefs.video = video

    ' locate/remote video qualities
    options = [
        {title: "20 Mbps",  value: "20"},
        {title: "12 Mbps",  value: "12"},
        {title: "10 Mbps",  value: "10"},
        {title: "8 Mbps",   value: "8"},
        {title: "4 Mbps",   value: "4"},
        {title: "3 Mbps",   value: "3"},
        {title: "2 Mbps",   value: "2"},
        {title: "1.5 Mbps", value: "1.5"},
        {title: "720 Kbps", value: "720"},
        {title: "320 Kbps", value: "320"},

    ]
    video.Push({command: "local_quality", title: "Local Streaming Quality", options: options, prefType: "enum"})
    video.Push({command: "remote_quality", title: "Remote Streaming Quality", options: options, prefType: "enum"})

    ' subtitle size
    options = [
        {title: "Tiny",   value: "tiny"},
        {title: "Small",  value: "small"},
        {title: "Normal", value: "normal"},
        {title: "Large",  value: "large"},
        {title: "Huge",   value: "huge"},
    ]
    video.Push({command: "subtitle_size", title: "Subtitle Size", options: options, prefType: "enum"})

    ' ** ADVANCED PREFS ** '
    advanced = CreateObject("roList")
    prefs.keys.push("Advanced")
    prefs.advanced = advanced

    ' locate/remote video qualities
    options1 = [
        {title: "20 Mbps",  value: "20"},
        {title: "12 Mbps",  value: "12"},
        {title: "10 Mbps",  value: "10"},
        {title: "8 Mbps",   value: "8"},
        {title: "4 Mbps",   value: "4"},
        {title: "3 Mbps",   value: "3"},
        {title: "2 Mbps",   value: "2"},
        {title: "1.5 Mbps", value: "1.5"},
        {title: "720 Kbps", value: "720"},
        {title: "320 Kbps", value: "320"},

    ]

    options2 = [
        {title: "Tiny",   value: "tiny"},
        {title: "Small",  value: "small"},
        {title: "Normal", value: "normal"},
        {title: "Large",  value: "large"},
        {title: "Huge",   value: "huge"},
    ]

    advanced.Push({command: "testing1", title: "testing 1", options: options1, prefType: "enum"})
    advanced.Push({command: "testing2", title: "testing 2", options: options2, prefType: "enum"})
    advanced.Push({command: "testing3", title: "testing 3", options: options1, prefType: "enum"})
    advanced.Push({command: "testing4", title: "testing 4", options: options2, prefType: "enum"})
    advanced.Push({command: "testing5", title: "testing 5", options: options1, prefType: "enum"})
    advanced.Push({command: "testing6", title: "testing 6", options: options2, prefType: "enum"})

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
        btn = m.overlay.createPrefButton(option.title, m.command, option.value, m.prefType)
        btn.isSelected = (option.value = m.options[0].value)
        btn.SetDimensions(m.width, m.height)
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
