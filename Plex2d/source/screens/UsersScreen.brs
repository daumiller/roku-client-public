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
    m.buttons = { width: 200, height: 200 + FontRegistry().font16.GetOneLineHeight(), maxCols: 3, rows: 2, spacing: 10 }

    ' Obtain use count to determine max columns for positioning
    homeUsers = MyPlexAccount().homeUsers
    m.buttons.cols = iif(homeUsers.Count() > m.buttons.maxCols, m.buttons.maxCols, homeUsers.Count())
    m.buttons.x = int(1280/2 - (m.buttons.width*m.buttons.cols)/2)
    m.buttons.y = int(720/2 - m.buttons.height/2)

    ' show all rows, and scroll on every row
    scrollHeight = 720 + m.buttons.height
    scrollTriggerDown = m.buttons.y + m.buttons.height

    userBox = createVBox(false, false, false, m.buttons.spacing)
    userBox.SetFrame(m.buttons.x, m.buttons.y, m.buttons.width * m.buttons.cols, m.buttons.height * m.buttons.rows)
    ' TODO(rob): wrap option for SetScrollable
    userBox.SetScrollable(scrollHeight, scrollTriggerDown)

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
    xOffset = int(1280/2 - logo.width/2)
    yOffset = int((m.buttons.y/2) - (logo.height/2) + m.buttons.spacing)
    logo.SetFrame(xOffset, yOffset, logo.width, logo.height)
    m.components.Push(logo)
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
