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

        ' Listener Methods
        obj.OnFailedFocus = settingsOnFailedFocus

        m.SettingsClass = obj
    end if

    return m.SettingsClass
end function

function createSettings(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SettingsClass())

    obj.screen = screen
    obj.titleText = "Settings"
    obj.storage = invalid

    obj.Init()

    return obj
end function

sub settingsInit()
    ApplyFunc(OverlayClass().Init, m)

    m.width = 660
    m.height = 200
    m.maxHeight = 560
    m.x = int(AppSettings().GetWidth()/2 - m.width/2)

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
    m.title = createLabel(m.titleText, FontRegistry().font18)
    m.title.halign = m.title.JUSTIFY_CENTER
    m.title.valign = m.title.ALIGN_MIDDLE
    m.title.zOrder = m.zOrderOverlay
    m.title.SetColor(Colors().Text, m.colors.title)
    m.title.height = 70
    m.components.push(m.title)

    border = { px: 1, color: m.colors.border }
    settingsBox = createHBox(true, true, true, border.px)
    menuBox = createVBox(false, false, false, 0)
    listBox = createVBox(false, false, false, 0)
    settingsBox.AddComponent(menuBox)
    settingsBox.AddComponent(listBox)

    prefs = m.GetPrefs()
    for each group in prefs
        label = createLabel(group.title, FontRegistry().font18)
        label.fixed = false
        label.SetColor(Colors().Text, m.colors.category)
        label.SetDimensions(m.width, 60)
        label.SetPadding(0, 0, 0, m.padding)
        label.valign = label.ALIGN_MIDDLE
        label.zOrder = m.zOrderOverlay
        menuBox.AddComponent(label)
        first = true
        for each pref in group.settings
            ' hide restricted prefs from managed users
            if not (pref.isRestricted = true and MyPlexAccount().isManaged) then
                btn = m.createMenuButton(pref)
                btn.scrollGroupTop = label
                btn.SetDimensions(m.width, 60)
                btn.SetPadding(0, 0, 0, m.padding*2)
                btn.listBox = listBox
                menuBox.AddComponent(btn)
            end if
        end for
    end for
    m.components.push(settingsBox)

    ' Resize height and position based on the menu box (width is hard coded)
    height = m.title.height
    for each comp in menuBox.components
        height = height + comp.GetPreferredHeight()
    end for
    height = height + (menuBox.spacing * (menuBox.components.count()-1))
    if height > m.height then
        m.height = iif(height < m.maxHeight, height, m.maxHeight)
    end if

    ' Set the positions after resizing
    m.y = int(AppSettings().GetHeight()/2 - m.height/2)
    m.title.SetFrame(m.x, m.y, m.width, m.title.height)
    settingsBox.SetFrame(m.x + border.px, m.y + m.title.height, m.width - border.px*2, m.height - m.title.height)
    menuBox.SetScrollable(settingsBox.height, false, false, "left")
    listBox.SetScrollable(settingsBox.height)

    ' Version string
    if m.storage = invalid then
        version = createLabel(AppSettings().GetGlobal("appVersionStr"), FontRegistry().font14)
        version.halign = version.JUSTIFY_RIGHT
        version.valign = version.ALIGN_MIDDLE
        version.zOrder = m.zOrderOverlay
        version.SetColor(Colors().TextDim)
        xOffset = m.x + m.width - version.GetPreferredWidth()*2
        version.SetFrame(xOffset, m.y, version.GetPreferredWidth(), 70)
        m.components.push(version)
    end if

    ' Settings background
    bkg = createBlock(m.colors.background)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = m.zOrderOverlay - 1
    m.components.push(bkg)

    ' Settings box border
    rect = computeRect(settingsBox)

    borderLeft = createBlock(border.color)
    borderLeft.SetFrame(rect.left - border.px, rect.up, border.px, rect.height)
    borderLeft.zOrder = m.zOrderOverlay - 1
    m.components.push(borderLeft)

    borderRight = createBlock(border.color)
    borderRight.SetFrame(rect.right, rect.up, border.px, rect.height)
    borderRight.zOrder = m.zOrderOverlay - 1
    m.components.push(borderRight)

    borderMid = createBlock(border.color)
    borderMid.setFrame(int(rect.left + rect.width/2 - border.px/2), rect.up, border.px, rect.height)
    borderMid.zOrder = m.zOrderOverlay - 1
    m.components.push(borderMid)

    borderBottom = createBlock(border.color)
    borderBottom.SetFrame(rect.left, rect.down - border.px, rect.width, border.px)
    borderBottom.zOrder = m.zOrderOverlay - 1
    m.components.push(borderBottom)
end sub

function settingsCreateMenuButton(pref as object) as object
    btn = createButton(pref.title, FontRegistry().font16, pref.key)
    btn.focusInside = true
    btn.fixed = false
    btn.halign = btn.JUSTIFY_LEFT
    btn.zOrder = m.zOrderOverlay

    ' special properties for the menu buttons
    btn.overlay = m
    btn.screen = m.screen
    btn.options = pref.options
    btn.prefType = pref.prefType
    btn.prefDefault = pref.default

    btn.OnSelected = settingsOnSelected
    btn.OnFocus = settingsOnFocus
    btn.OnBlur = settingsOnBlur
    btn.GetEnumSettingValue = settingsGetEnumSettingValue
    btn.GetBoolSettingValue = settingsGetBoolSettingValue

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

function settingsCreatePrefButton(text as string, command as dynamic, value as string, prefType as string) as object
    btn = createSettingsButton(text, FontRegistry().font16, command, value, prefType, m.storage)
    btn.focusInside = true
    btn.fixed = false
    btn.halign = btn.JUSTIFY_LEFT
    btn.zOrder = m.zOrderOverlay
    btn.overlay = m

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

    if m.prefType = "enum" then
        enumValue = m.GetEnumSettingValue(m.command, m.prefDefault)
    end if

    for each option in m.options
        if m.prefType = "bool" then
            btn = m.overlay.createPrefButton(option.title, option.key, "", "bool")
            btn.isSelected = m.GetBoolSettingValue(option.key, option.default)
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

function settingsGetEnumSettingValue(key as string, default as dynamic) as dynamic
    if m.overlay.storage <> invalid then
        return firstOf(m.overlay.storage[key], default)
    else
        return AppSettings().GetPreference(key)
    end if
end function

function settingsGetBoolSettingValue(key as string, default as dynamic) as boolean
    if m.overlay.storage <> invalid then
        return (firstOf(m.overlay.storage[key], default) = "1")
    else
        return AppSettings().GetBoolPreference(key)
    end if
end function

sub settingsOnFailedFocus(direction as string, focusedItem=invalid as dynamic)
    if not m.IsActive() then return
    if m.storage <> invalid and direction = "left" then
        m.Close(true)
    end if
end sub
