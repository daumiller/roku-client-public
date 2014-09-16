function ComponentsScreen() as object
    if m.ComponentsScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BaseScreen())

        ' Key code constants
        obj.kp_BK   = 0
        obj.kp_UP   = 2
        obj.kp_DN   = 3
        obj.kp_LT   = 4
        obj.kp_RT   = 5
        obj.kp_OK   = 6
        obj.kp_RW   = 7
        obj.kp_REV  = 8
        obj.kp_FWD  = 9
        obj.kp_INFO = 10
        obj.kp_PLAY = 13

        ' Standard screen methods
        obj.Init = compInit
        obj.Show = compShow

        obj.GetComponents = compGetComponents

        ' Message handling
        obj.HandleMessage = compHandleMessage
        obj.OnItemFocused = compOnItemFocused
        obj.OnItemSelected = compOnItemSelected
        obj.OnKeyPress = compOnKeyPress
        obj.OnKeyHeld = compOnKeyHeld
        obj.OnKeyRelease = compOnKeyRelease

        m.ComponentsScreen = obj
    end if

    return m.ComponentsScreen
end function

sub compInit()
    ApplyFunc(BaseScreen().Init, m)

    m.screen = CompositorScreen()
    m.screen.Reset()

    m.components = CreateObject("roList")
    m.focusedItem = invalid
    m.keyPressTimer = invalid
    m.lastKey = -1
    m.customFonts = CreateObject("roAssociativeArray")
end sub

sub compShow()
    ' TODO(schuyler): Can we avoid always resetting and drawing everything?
    m.screen.Reset()

    m.GetComponents()

    for each comp in m.components
        m.screen.DrawComponent(comp)
    next

    if m.focusedItem <> invalid then
        m.screen.DrawFocus(m.focusedItem)
    end if

    m.screen.DrawAll()
end sub

sub compGetComponents()
end sub

function compHandleMessage(msg as object) as boolean
    handled = false

    if type(msg) = "roUniversalControlEvent" then
        handled = true
        keyCode = msg.GetInt()

        ' We can always cancel our timer for held keys. Either this is
        ' a release event for that key and it's the perfect time to
        ' cancel the timer, or it's a press event for some other key.
        ' Since multiple keys can't be pressed, we assume the other
        ' key isn't held anymore.

        if m.keyPressTimer <> invalid then
            m.keyPressTimer.active = false
            m.keyPressTimer = invalid
        end if

        if keyCode >= 100 then
            m.OnKeyRelease(keyCode - 100)
            m.lastKey = -1
        else
            m.lastKey = keyCode
            m.OnKeyPress(keyCode, false)

            m.keyPressTimer = createTimer("holdDownKeyPress")
            m.keyPressTimer.SetDuration(500, true)
            Application().AddTimer(m.keyPressTimer, createCallable("OnKeyHeld", m))
        end if
    end if

    return handled
end function

sub compOnKeyHeld(timer as object)
    ' TODO(schuyler): Support forceRemoteRelease?

    if m.lastKey <> -1 then
        ' After the first held event, shorten the timer's duration.
        timer.SetDuration(150, true)

        m.OnKeyPress(m.lastKey, true)
    else
        timer.active = false
    end if
end sub

sub compOnKeyPress(keyCode as integer, repeat as boolean)
    if keyCode = m.kp_RT or keyCode = m.kp_LT or keyCode = m.kp_UP or keyCode = m.kp_DN then
        if m.focusedItem <> invalid then
            toFocus = m.focusedItem.GetFocusSibling(KeyCodeToString(keyCode))
            if toFocus <> invalid then
                ' TODO(schuyler): Do we want to call things like OnBlur and OnFocus to let the components know?
                m.focusedItem = toFocus
                m.OnItemFocused(toFocus)
            end if

            ' TODO(schuyler): Consider adding an else here and looking for the
            ' closest focusable element in that direction.
        end if
    else if keyCode = m.kp_REV or keyCode = m.kp_FWD then
        ' TODO(schuyler): Handle focus (big) shift
        ' m.OnItemFocused(m.focusedItem)
    end if
end sub

sub compOnKeyRelease(keyCode as integer)
    ' TODO(schuyler): What keys can we handle generically in this base screen?
    ' OK and Back for sure. Maybe play and info as well?

    if keyCode = m.kp_OK then
        if m.focusedItem <> invalid and m.focusedItem.selectable = true then
            ' TODO(schuyler): Lock remote events?
            m.OnItemSelected(m.focusedItem)
        end if
    else if keyCode = m.kp_BK then
        ' TODO(schuyler): Lock remote events?
        Application().popScreen(m)
    end if
end sub

sub compOnItemFocused(item as object)
    m.screen.DrawFocus(item, true)
end sub

sub compOnItemSelected(item as object)
    ' TODO(schuyler): What makes sense here? Maybe generic command processing?
end sub
