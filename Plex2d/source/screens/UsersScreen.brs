function UsersScreen() as object
    if m.UsersScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Users Screen"

        obj.Show = usersShow
        obj.GetComponents = usersGetComponents
        obj.CreateCard = usersCreateCard
        obj.OnKeyPress = usersOnKeyPress
        obj.OnKeyRelease = usersOnKeyRelease
        obj.OnFwdButton = usersOnFwdButton
        obj.OnRevButton = usersOnRevButton
        obj.OnPlayButton = usersOnPlayButton
        obj.Deactivate = usersDeactivate
        obj.LockScreen = usersLockScreen

        m.UsersScreen = obj
    end if

    return m.UsersScreen
end function

function createUsersScreen(clearScreens=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(UsersScreen())

    obj.Init()

    obj.isLockScreen = (GetGlobalAA()["screenIsLocked"] = true)

    if clearScreens = true then
        Application().ClearScreens()
    end if

    return obj
end function

sub usersLockScreen(drawNow=false as boolean)
    m.isLockScreen = true
    m.lockLabel.SetColor(Colors().Orange)
    if drawNow then
        m.lockLabel.Draw(true)
        m.lockLabel.Redraw()
    end if
end sub

sub usersGetComponents()
    m.DestroyComponents()

    ' User list container
    m.buttons = { width: 200, height: 200 + FontRegistry().NORMAL.GetOneLineHeight(), maxCols: 3, rows: 2, spacing: 10 }

    ' Obtain use count to determine max columns for positioning
    MyPlexAccount().UpdateHomeUsers()
    homeUsers = MyPlexAccount().homeUsers
    m.buttons.cols = iif(homeUsers.Count() > m.buttons.maxCols, m.buttons.maxCols, homeUsers.Count())
    m.buttons.x = int(1280/2 - (m.buttons.width*m.buttons.cols)/2)
    m.buttons.y = int(720/2 - m.buttons.height/2)

    ' show all rows, and scroll on every row
    userBox = createVBox(false, false, false, m.buttons.spacing)
    userBox.SetFrame(m.buttons.x, m.buttons.y, m.buttons.width * m.buttons.cols, m.buttons.height * m.buttons.rows)
    userBox.SetScrollable(m.buttons.height, true, true, invalid)

    ' User Buttons
    for i = 0 to homeUsers.Count() - 1
        mod = i mod m.buttons.cols
        if mod = 0 then
            hbox = createHBox(false, false, false, m.buttons.spacing)
        end if

        button = m.CreateCard(homeUsers[i])
        button.shiftableParent = userBox
        hbox.AddComponent(button)

        if mod = 0 then
            userBox.AddComponent(hbox)
        end if
    end for
    m.components.push(userBox)

    ' Plex Logo
    logo = createImage("pkg:/images/plex-logo-light-200x65.png", 200, 65)
    logo.zOrder = ZOrders().HEADER
    xOffset = int(1280/2 - logo.width/2)
    yOffset = int((m.buttons.y/2) - (logo.height/2) + m.buttons.spacing)
    logo.SetFrame(xOffset, yOffset, logo.width, logo.height)
    m.components.Push(logo)

    ' Lock screen status
    height = m.buttons.y - (logo.y + logo.height)
    msgBox = createVBox(true, true, true, 0)
    msgBox.SetFrame(xOffset, logo.y + logo.height, logo.width, height)

    lockLabel = createLabel("Lock Screen", FontRegistry().LARGE_BOLD)
    lockLabel.SetPadding(10)
    lockLabel.SetColor(Colors().Transparent)
    lockLabel.zOrder = ZOrders().HEADER
    lockLabel.halign = lockLabel.JUSTIFY_CENTER
    msgBox.AddComponent(lockLabel)

    if MyPlexAccount().isOffline then
        offlineLabel = createLabel("Offline Mode", FontRegistry().LARGE_BOLD)
        offlineLabel.zOrder = ZOrders().HEADER
        offlineLabel.SetColor(Colors().Red)
        offlineLabel.halign = offlineLabel.JUSTIFY_CENTER
        msgBox.AddComponent(offlineLabel)
    end if

    m.components.Push(msgBox)

    ' Lock the screen if applicable. Support to convert an existing
    ' UsersScreen into a lock screen.
    m.lockLabel = lockLabel
    if m.isLockScreen then m.LockScreen(false)
end sub

sub usersShow()
    ApplyFunc(ComponentsScreen().Show, m)
end sub

function usersCreateCard(user as object) as object
    ' assign key to selected user (checkmark/focus)
    if user.id = MyPlexAccount().id then user.isSelected = true

    button = createUserCard(user, FontRegistry().NORMAL, "switch_user")
    button.width = m.buttons.width
    button.height = m.buttons.height
    button.fixed = false
    button.SetMetadata(user)

    ' set the focused item to the signed in user
    if user.isSelected = true or m.focusedItem = invalid then m.focusedItem = button

    return button
end function

sub usersDeactivate(screen = invalid as dynamic)
    if m.isLockScreen then
        GetGlobalAA().Delete("screenIsLocked")
    end if
    ApplyFunc(ComponentsScreen().Deactivate, m)
end sub

' Override (disable) any back button press/release if the screen is
' locked. We still need the back button to function in other screens.
' e.g. pin prompt overlay, video player (fling content when locked).
sub usersOnKeyRelease(keyCode as integer)
    if not m.isLockScreen or keyCode <> m.kp_BK
        ApplyFunc(ComponentsScreen().OnKeyRelease, m, [keyCode])
    end if
end sub

sub usersOnKeyPress(keyCode as integer, repeat as boolean)
    if not m.isLockScreen or keyCode <> m.kp_BK
        ApplyFunc(ComponentsScreen().OnKeyPress, m, [keyCode, repeat])
    end if
end sub

sub usersOnFwdButton(item=invalid as dynamic)
    if not m.isLockScreen then return
    AudioPlayer().Next()
end sub

sub usersOnRevButton(item=invalid as dynamic)
    if not m.isLockScreen then return
    AudioPlayer().Prev()
end sub

sub usersOnPlayButton(item=invalid as dynamic)
    if not m.isLockScreen then return
    AudioPlayer().OnPlayButton()
end sub
