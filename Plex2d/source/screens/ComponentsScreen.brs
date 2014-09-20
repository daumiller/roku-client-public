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
        obj.Deactivate = compDeactivate

        obj.GetComponents = compGetComponents

        ' Manual focus methods
        obj.GetFocusManual = compGetFocusManual
        obj.CalculateFocusPoint = compCalculateFocusPoint

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
    m.focusX = invalid
    m.focusY = invalid
    m.lastFocusedItem = invalid
    m.lastDirection = invalid
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
        if m.focusX = invalid or m.focusY = invalid then
            m.focusX = m.focusedItem.x + int(m.focusedItem.width / 2)
            m.focusY = m.focusedItem.y + int(m.focusedItem.height / 2)
        end if

        m.screen.DrawFocus(m.focusedItem)
    end if

    m.screen.DrawAll()
end sub

' TODO(rob) screen is not required to be passed, but we might want to ignore
' clearing some objects depending on the screen? I.E. DialogScreen. We will
' also need to exclude resetting the compositor.
sub compDeactivate(screen = invalid as dynamic)
    Debug("Deactivate ComponentsScreen: clearing components and custom fonts")
    for each comp in m.components
        comp.Destroy()
    end for
    m.components.clear()
    m.customFonts.clear()
    m.focusedItem = invalid
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
            m.screen.ClearDebugSprites()
            m.screen.DrawDebugRect(m.focusX, m.focusY, 15, 15, &hffffffff, true)

            direction = KeyCodeToString(keyCode)

            ' If we're doing the opposite of our last direction, go back to
            ' where we came from.
            '
            if m.lastFocusedItem <> invalid and direction = OppositeDirection(m.lastDirection) then
                toFocus = m.lastFocusedItem
            else
                toFocus = m.focusedItem.GetFocusSibling(KeyCodeToString(keyCode))
                ' TODO(rob) disabled known focus siblings to test manual focus on every component
                toFocus = invalid
            end if

            ' manually find the closest component to focus
            if toFocus = invalid then
                Debug("I'm lonely... I don't have any siblings [locate a relative]")
                toFocus = m.GetFocusManual(KeyCodeToString(keyCode))
            else
                ' We didn't have to search focus candidates, but we still need
                ' to update our focus point.
                '
                point = m.CalculateFocusPoint(toFocus, direction)
                m.focusX = point.x
                m.focusY = point.y
                m.screen.DrawDebugRect(point.x, point.y, 15, 15, &h00ff00ff, true)
            end if

            if toFocus <> invalid then
                m.lastFocusedItem = m.focusedItem
                m.lastDirection = direction

                ' TODO(schuyler): Do we want to call things like OnBlur and OnFocus to let the components know?
                m.focusedItem = toFocus
                m.OnItemFocused(toFocus)
            end if
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
    Debug("component item selected with command: " + tostr(item.command))
    ' TODO(schuyler): What makes sense here? Maybe generic command processing?
    ' TODO(rob): Here is some generic processing :)
    if item.command <> invalid then
        if item.command = "cardTestScreen" then
            Application().PushScreen(createCardTestScreen())
        else
            Debug("command not defined: " + tostr(item.command))
        end if
    end if
end sub

function computeRect(component as object) as object
    return {
        left: component.x,
        up: component.y,
        width: component.width,
        height: component.height,
        right: component.x + component.width,
        down: component.y + component.height
    }
end function

function compCalculateFocusPoint(component as object, direction as string) as object
    point = {}
    rect = computeRect(component)
    oppositeDir = OppositeDirection(direction)

    if direction = "left" or direction = "right" then
        point.x = rect[oppositeDir]
        if m.focusY < rect.up then
            point.y = rect.up
        else if m.focusY > rect.down then
            point.y = rect.down
        else
            point.y = m.focusY
        end if
    else
        point.y = rect[oppositeDir]
        if m.focusX < rect.left then
            point.x = rect.left
        else if m.focusX > rect.right then
            point.x = rect.right
        else
            point.x = m.focusX
        end if
    end if

    return point
end function

function compGetFocusManual(direction as string) as dynamic
    ' These should never happen...
    if m.focusedItem = invalid or m.focusX = invalid or m.focusY = invalid then return invalid

    Debug("Evaluating manual " + direction + " focus for " + tostr(m.focusedItem))

    oppositeDir = OppositeDirection(direction)

    candidates = CreateObject("roList")

    ' Ask each component to add to our list of candidates.
    for each component in m.components
        component.GetFocusableItems(candidates)
    next

    ' Move our current focus point to the edge of the current component in
    ' the direction we're moving.
    '
    focusedRect = computeRect(m.focusedItem)
    if direction = "left" or direction = "right" then
        m.focusX = focusedRect[direction]
    else
        m.focusY = focusedRect[direction]
    end if

    Debug("Focus point is " + tostr(m.focusX) + ", " + tostr(m.focusY))

    ' Keep track of some things for the best candidate. We need to know the
    ' offset along both the navigational axis and the orthogonal axis. All
    ' other distances and scores are based on these values.
    '
    best = {
        navOffset: 0,
        orthOffset: 0,
        distance: 0,
        x: 0,
        y: 0,
        item: invalid
    }

    for each candidate in candidates
        if not candidate.Equals(m.focusedItem) then
            candPt = m.CalculateFocusPoint(candidate, direction)

            ' Calculate the focus point for the candidate.
            if direction = "left" or direction = "right" then
                orthOffset = m.focusY - candPt.y

                if direction = "left" then
                    navOffset = m.focusX - candPt.x
                else
                    navOffset = candPt.x - m.focusX
                end if
            else
                orthOffset = m.focusX - candPt.x

                if direction = "up" then
                    navOffset = m.focusY - candPt.y
                else
                    navOffset = candPt.y - m.focusY
                end if
            end if

            ' Items are only real candidates if they have a positive navOffset.
            if navOffset > 0 then
                if orthOffset < 0 then orthOffset = -1 * orthOffset

                ' Ok, it's a real candidate. We don't need to do any real math
                ' if it's not better than our best so far in at least one way.
                '
                if best.item = invalid or navOffset < best.navOffset or orthOffset < best.orthOffset then
                    if navOffset = 0 then
                        dotDistance = 0
                    else
                        dotDistance = int(Sqr(navOffset*navOffset + orthOffset*orthOffset))
                    end if

                    ' TODO(schuyler): Do we need to account for overlap?
                    distance = dotDistance + navOffset + 2*orthOffset
                    Debug("Evaluated " + tostr(candidate))
                    Debug("navOffset=" + tostr(navOffset) + " orthOffset=" + tostr(orthOffset) + " dotDistance=" + tostr(dotDistance) + " distance=" + tostr(distance))

                    if best.item = invalid or distance < best.distance then
                        Debug("Found a new best item: " + tostr(candidate))
                        if best.item <> invalid then
                            m.screen.DrawDebugRect(best.x, best.y, 15, 15, &h0000ffff, true)
                        end if
                        best.navOffset = navOffset
                        best.orthOffset = orthOffset
                        best.distance = distance
                        best.x = candPt.x
                        best.y = candPt.y
                        best.item = candidate
                        m.screen.DrawDebugRect(candPt.x, candPt.y, 15, 15, &h00ff00ff, true)
                    else
                        Debug("Candidate " + tostr(candidate) + " turned out to be worse than " + tostr(best.item))
                        m.screen.DrawDebugRect(candPt.x, candPt.y, 15, 15, &h0000ffff, true)
                    end if
                else
                    m.screen.DrawDebugRect(candPt.x, candPt.y, 15, 15, &hff0000ff, true)
                    Debug("Candidate " + tostr(candidate) + " is obviously worse than " + tostr(best.item))
                end if
                sleep(500)
            end if
        end if
    next

    ' If we found something then return it. Otherwise, we can at least move the
    ' focus point to the edge of our current component.
    '
    if best.item <> invalid then
        m.focusX = best.x
        m.focusY = best.y
    end if

    return best.item
end function
