function SettingsClass() as object
    if m.SettingsClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())

        obj.ClassName = "SettingsClass"

        ' Methods
        obj.Init = settingsInit
        obj.GetComponents = settingsGetComponents
        obj.CreateMenuButton = settingsCreateMenuButton
        obj.CreatePrefButton = settingsCreatePrefButton
        obj.GetPrefs = settingsGetPrefs

        m.SettingsClass = obj
    end if

    return m.SettingsClass
end function

function createSettings(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SettingsClass())

    obj.screen = screen
    obj.title = "Settings"
    obj.screenPref = false

    obj.Init()

    return obj
end function

sub settingsInit()
    ApplyFunc(OverlayClass().Init, m)

    m.width = 660
    m.height = 560
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)
    m.scrollHeight = m.y + m.height

    m.colors = {
        category: Colors().Button and &hffffff90,
        border: Colors().Button and &hffffff90,
        highlight: Colors().Button,
        background: Colors().Black,
        title: Colors().Button,
    }

    m.padding = 10
end sub

sub settingsGetComponents()
    title = createLabel(m.title, FontRegistry().font18)
    title.halign = title.JUSTIFY_CENTER
    title.valign = title.ALIGN_MIDDLE
    title.zOrder = 100
    title.SetColor(Colors().Text, m.colors.title)
    title.SetFrame(m.x, m.y, m.width, 70)
    m.components.push(title)

    border = { px: 1, color: m.colors.border }
    settingsBox = createHBox(true, true, true, border.px)
    settingsBox.SetFrame(m.x + border.px, m.y + title.height, m.width - border.px*2, m.height - title.height)
    menuBox = createVBox(false, false, false, 0)
    listBox = createVBox(false, false, false, 0)
    settingsBox.AddComponent(menuBox)
    settingsBox.AddComponent(listBox)

    listBox.SetScrollable(m.scrollHeight)
    menuBox.SetScrollable(m.scrollHeight)

    prefs = m.GetPrefs()
    for each group in prefs
        title = createLabel(group.title, FontRegistry().font18)
        title.fixed = false
        title.SetColor(Colors().Text, m.colors.category)
        title.SetDimensions(m.width, 60)
        title.SetPadding(0, 0, 0, m.padding)
        title.valign = title.ALIGN_MIDDLE
        title.zOrder = 100
        menuBox.AddComponent(title)
        first = true
        for each pref in group.settings
            ' hide restricted prefs from managed users
            if not (pref.isRestricted = true and MyPlexAccount().isManaged) then
                btn = m.createMenuButton(pref)
                if first = true then
                    btn.scrollOffset = title.height
                    first = false
                end if
                btn.SetDimensions(m.width, 60)
                btn.SetPadding(0, 0, 0, m.padding*2)
                btn.listBox = listBox
                menuBox.AddComponent(btn)
            end if
        end for
    end for
    m.components.push(settingsBox)

    ' settings background
    bkg = createBlock(m.colors.background)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = 99
    m.components.push(bkg)

    ' settings box border
    rect = computeRect(settingsBox)

    borderLeft = createBlock(border.color)
    borderLeft.SetFrame(rect.left - border.px, rect.up, border.px, rect.height)
    borderLeft.zOrder = 99
    m.components.push(borderLeft)

    borderRight = createBlock(border.color)
    borderRight.SetFrame(rect.right, rect.up, border.px, rect.height)
    borderRight.zOrder = 99
    m.components.push(borderRight)

    borderMid = createBlock(border.color)
    borderMid.setFrame(int(rect.left + rect.width/2 - border.px/2), rect.up, border.px, rect.height)
    borderMid.zOrder = 99
    m.components.push(borderMid)

    borderBottom = createBlock(border.color)
    borderBottom.SetFrame(rect.left, rect.down - border.px, rect.width, border.px)
    borderBottom.zOrder = 99
    m.components.push(borderBottom)
end sub

function settingsCreateMenuButton(pref as object) as object
    btn = createButton(pref.title, FontRegistry().font16, pref.key)
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
    btn.OnSelected = settingsOnSelected
    btn.OnFocus = settingsOnFocus
    btn.OnBlur = settingsOnBlur

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

function settingsCreatePrefButton(text as string, command as dynamic, value as string, prefType as string) as object
    btn = createButtonPref(text, FontRegistry().font16, command, value, prefType, m.screenPref)
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
    return AppSettings().GetGlobalSettings()
end function

sub settingsOnSelected()
    m.screen.OnKeyPress(m.screen.kp_RT, false)
end sub

sub settingsOnFocus()
    if tostr(m.listBox.curCommand) = m.command then
        ' TODO(rob): we can probably rip the focus sibling out when we keep
        ' state, as I'd expect we'll always focus to the selected pref
        m.SetFocusSibling("right", m.screen.lastFocusedItem)
        return
    end if
    m.listBox.curCommand = m.command

    ' highlight the focused item
    m.SetColor(Colors().Text, m.overlay.colors.highlight)
    m.draw(true)

    'TODO(rob): better way to reinit the list box
    m.listBox.DestroyComponents()
    m.listBox.lastFocusableItem = invalid

    settings = AppSettings()
    if m.prefType = "enum" then
        enumValue = settings.GetPreference(m.command)
    end if

    for each option in m.options
        if m.prefType = "bool" then
            btn = m.overlay.createPrefButton(option.title, option.key, "", "bool")
            btn.isSelected = settings.GetBoolPreference(option.key)
        else if m.prefType = "enum" then
            btn = m.overlay.createPrefButton(option.title, m.command, option.value, "enum")
            btn.isSelected = (option.value = enumValue)
        end if

        ' hide restricted prefs from managed users
        if not (option.isRestricted = true and MyPlexAccount().isManaged) then
            btn.SetDimensions(m.width, m.height)
            btn.SetPadding(0, 0, 0, m.padding.left)
            btn.SetFocusSibling("left", m)
            m.listBox.AddComponent(btn)
        end if
    end for

    CompositorScreen().DrawComponent(m.listBox)
    m.SetFocusSibling("right", m.listBox.components[0])

    m.screen.screen.DrawAll()
end sub

sub settingsOnBlur(toFocus as object)
    if toFocus.options <> invalid then
        m.SetColor(Colors().Text)
        m.draw(true)
    end if
end sub
