function UsersScreen() as object
    if m.UsersScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Users Screen"

        obj.Show = usersShow
        obj.GetComponents = usersGetComponents
        obj.CreateCard = usersCreateCard

        m.UsersScreen = obj
    end if

    return m.UsersScreen
end function

function createUsersScreen(clearScreens=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(UsersScreen())

    obj.Init()

    ' TODO(rob): fix logic. for now, we'll consider userSwitched false
    ' if we create this screen. There may be times we need the option
    ' to back out (if we use this for switching after login)
    MyPlexAccount().userSwitched = false

    if clearScreens = true then
        Application().ClearScreens()
    end if

    return obj
end function

sub usersGetComponents()
    m.DestroyComponents()

    ' User list container
    m.buttons = { width: 200, height: 200 + FontRegistry().font16.GetOneLineHeight(), cols: 3, rows: 2, spacing: 10 }
    m.buttons.x = int(1280/2 - (m.buttons.width*m.buttons.cols)/2)
    m.buttons.y = 200
    m.buttons.scrollHeight = m.buttons.y + (m.buttons.height*m.buttons.rows) + m.buttons.spacing*(m.buttons.rows - 1)

    userBox = createVBox(false, false, false, 10)
    userBox.SetFrame(m.buttons.x, m.buttons.y, m.buttons.width*m.buttons.cols, m.buttons.height*m.buttons.rows)
    ' TODO(rob): wrap option for SetScrollable
    userBox.SetScrollable(m.buttons.scrollHeight)

    ' User Buttons
    mpa = MyPlexAccount()
    for i = 0 to mpa.homeUsers.Count()-1
        mod = i mod m.buttons.cols
        if mod = 0 then
            hbox = createHBox(false, false, false, 10)
        end if

        button = m.CreateCard(mpa.homeUsers[i])
        button.shiftableParent = userBox
        hbox.AddComponent(button)

        if mod = 0 then
            userBox.AddComponent(hbox)
        end if
    end for
    m.components.push(userBox)

    ' Title
    title = createLabel("PLEX LOGO", FontRegistry().font18b)
    title.SetFrame(m.buttons.x, m.buttons.y - m.buttons.height/2, userBox.width, m.buttons.height/2)
    title.halign = title.JUSTIFY_CENTER
    title.valign = title.ALIGN_MIDDLE
    m.components.Push(title)
end sub

sub usersShow()
    ApplyFunc(ComponentsScreen().Show, m)
end sub

function usersCreateCard(user as object) as object
    ' assign key to selected user (checkmark/focus)
    if user.id = MyPlexAccount().id then user.isSelected = true

    button = createUserCard(user, FontRegistry().font16, "switch_user")
    button.width = m.buttons.width
    button.height = m.buttons.height
    button.fixed = false
    button.SetMetadata(user)

    ' set the focused item to the signed in user
    if user.isSelected = true or m.focusedItem = invalid then m.focusedItem = button

    return button
end function
