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

        ' Lazy Load methods and constants
        ' ll_unload: how far off screen to unload (any direction)
        ' ll_trigger: when to trigger a lazy load (items within range not loaded). This should be > screen
        ' ll_load: how many to load when triggered (<= ll_unload, otherwise we'll load more than we allow)
        ' ll_timerDur: ms to wait before lazy loading the pending off screen components
        obj.LazyLoadOnTimer = compLazyLoadOnTimer
        obj.LazyLoadExec = compLazyLoadExec
        obj.ll_unload = int(1280*4)
        obj.ll_trigger = int(1280*2)
        obj.ll_load = int(1280*4)
        obj.ll_timerDur = 2000

        ' Standard screen methods
        obj.Init = compInit
        obj.Show = compShow
        obj.Deactivate = compDeactivate
        obj.Activate = compActivate
        obj.OnAccountChange = compOnAccountChange

        obj.GetComponents = compGetComponents
        obj.GetManualComponents = compGetManualComponents

        ' Manual focus methods
        obj.GetFocusManual = compGetFocusManual
        obj.CalculateFocusPoint = compCalculateFocusPoint

        ' Shifting methods
        obj.CalculateShift = compCalculateShift
        obj.ShiftComponents = compShiftComponents

        ' Message handling
        obj.HandleMessage = compHandleMessage
        obj.OnItemFocused = compOnItemFocused
        obj.OnItemSelected = compOnItemSelected
        obj.OnKeyPress = compOnKeyPress
        obj.OnKeyHeld = compOnKeyHeld
        obj.OnKeyRelease = compOnKeyRelease
        obj.OnInfoButton = compOnInfoButton

        obj.AfterItemFocused = function(item as dynamic) : Debug("AfterItemFocused::no-op") : end function

        Application().On("change:user", createCallable("OnAccountChange", obj))

        m.ComponentsScreen = obj
    end if

    return m.ComponentsScreen
end function

sub compActivate()
    m.Init()
    m.show()
end sub

sub compInit()
    ApplyFunc(BaseScreen().Init, m)

    m.screen = CompositorScreen()

    m.components = CreateObject("roList")
    m.focusedItem = invalid
    m.focusX = invalid
    m.focusY = invalid
    m.lastFocusedItem = invalid
    m.lastDirection = invalid
    m.keyPressTimer = invalid
    m.lastKey = -1
    m.customFonts = CreateObject("roAssociativeArray")
    m.manualComponents = CreateObject("roAssociativeArray")

    ' lazy load timer ( loading off screen components )
    m.lazyLoadTimer = createTimer("lazyLoad")
    m.lazyLoadTimer.SetDuration(m.ll_timerDur)
end sub

sub compShow()
    ' TODO(schuyler): Can we avoid always resetting and drawing everything?
    ' TODO(rob): update -- we no longer need to reset the screen. Components
    ' are destroyed properly now (have been for a while)
    ' m.screen.Reset()
    m.screen.HideFocus(true)

    Application().CheckLoadingModal()
    m.GetComponents()

    for each comp in m.components
        Application().CheckLoadingModal()
        m.screen.DrawComponent(comp)
    next

    ' close any loading modal before our first draw
    Application().CloseLoadingModal()

    if m.focusedItem = invalid then
        candidates = []
        for each component in m.components
            component.GetFocusableItems(candidates)
        next
        m.focusedItem = candidates[0]
    end if

    if m.focusedItem <> invalid then
        ' Make sure that we set an initial focus point.
        if m.focusX = invalid or m.focusY = invalid then
            m.focusX = m.focusedItem.x
            m.focusY = m.focusedItem.y
        end if

        m.screen.DrawFocus(m.focusedItem)
    end if

    m.screen.DrawAll()
end sub

' TODO(rob) screen is not required to be passed, but we might want to ignore
' clearing some objects depending on the screen? I.E. DialogScreen. We will
' also need to exclude resetting the compositor.
sub compDeactivate(screen = invalid as dynamic)
    Debug("Deactivate ComponentsScreen: clear components, texture manager, and custom fonts")
    TextureManager().RemoveTextureByScreenId(m.screenID)
    for each comp in m.components
        comp.Destroy()
    end for
    ' components we have created manually (AA of roList)
    for each key in m.manualComponents
        for each comp in m.manualComponents[key]
            comp.Destroy()
        end for
        m.manualComponents[key].clear()
    end for
    m.components.clear()
    m.manualComponents.clear()
    m.customFonts.clear()
    m.focusedItem = invalid
end sub

sub compGetComponents()
end sub

function compGetManualComponents(key as string) as object
    if m.manualComponents[key] = invalid then
        m.manualComponents[key] = CreateObject("roList")
    end if
    return m.manualComponents[key]
end function

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
            perfTimer().mark()
            m.screen.ClearDebugSprites()
            m.screen.DrawDebugRect(m.focusX, m.focusY, 15, 15, &hffffffff, true)

            direction = KeyCodeToString(keyCode)

            ' If the component knows its sibling, always use that.
            toFocus = m.focusedItem.GetFocusSibling(KeyCodeToString(keyCode))

            ' Check if we allow manual focus (dialogs/dropdown/etc)
            if toFocus = invalid
                ' ONLY focus siblings are allowed
                if m.focusedItem.FocusNonSiblings = false then return

                ' DropDowns: focus should stay contained to focus siblings, except UP
                if m.focusedItem.dropDown <> invalid then
                    if direction <> "up" then return

                    m.focusedItem.dropDown.hide()
                    toFocus = m.focusedItem.dropDown
                    m.focusedItem = invalid
                end if
            end if

            ' If we're doing the opposite of our last direction, go back to
            ' where we came from.
            '
            if toFocus = invalid and m.lastFocusedItem <> invalid and direction = OppositeDirection(m.lastDirection) then
                toFocus = m.lastFocusedItem
            end if

            if toFocus = invalid then
                ' All else failed, search manually.
                ' Debug("I'm lonely... I don't have any siblings [locate a relative]")
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

                perfTimer().Log("Determined next focus")

                m.CalculateShift(toFocus)

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
        if Locks().IsLocked("BackButton") then
            Debug(KeyCodeToString(keyCode) + " is disabled")
        else
            Application().popScreen(m)
        end if
    else if keyCode = m.kp_RW then
        m.OnRewindButton()
    else if keyCode = m.kp_INFO then
        m.OnInfoButton()
    end if
end sub

sub compOnItemFocused(item as object)
    m.screen.DrawFocus(item, true)
    m.AfterItemFocused(item)
end sub

sub compOnItemSelected(item as object)
    Debug("component item selected with command: " + tostr(item.command))
    ' TODO(schuyler): What makes sense here? Maybe generic command processing?
    ' TODO(rob): Here is some generic processing :)

    if item.OnSelected <> invalid then
        item.OnSelected()
    else if tostr(item.classname) = "DropDown" then
        if item.hide() then return
        item.show(m)
    else if item.command <> invalid then
        if item.command = "card" then
            itemType = item.plexObject.Get("type")
            if itemType = invalid then
                Debug("card object type is invalid")
            else if itemType = "movie" or itemType = "episode" or itemType = "clip" or itemType = "playlist" then
                Application().PushScreen(createPreplayScreen(item.plexObject))
            else
                dialog = createDialog("card type not handled yet", "type: " + itemType, m)
                dialog.Show()
            end if
        else if item.command = "cardTestScreen" then
            Application().PushScreen(createCardTestScreen())
        else if item.command = "section_button" then
            Application().PushScreen(createSectionsScreen(item.plexObject))
        else if item.command = "sign_out" then
            MyPlexAccount().SignOut()
        else if item.command = "sign_in" then
            Application().pushScreen(createPinScreen())
        else if item.command = "selected_server" then
            if item.metadata <> invalid then
                Application().pushScreen(createHomeScreen(item.metadata))
            end if
        else
            dialog = createDialog("Command not defined", "command: " + tostr(item.command), m)
            dialog.Show()
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

    ' Debug("Evaluating manual " + direction + " focus for " + tostr(m.focusedItem))

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

    ' draw where we moved the focus point
    m.screen.DrawDebugRect(m.focusX, m.focusY, 15, 15, Colors().PlexClr, true)

    ' Debug("Focus point is " + tostr(m.focusX) + ", " + tostr(m.focusY))

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

                ' Prioritize items that overlap on the orth axix.
                rect = computeRect(candidate)
                if focusedRect.up <= rect.up then
                    if focusedRect.down >= rect.down then
                        overlap = rect.height
                    else if focusedRect.down <= rect.up then
                        overlap = 0
                    else
                        overlap = focusedRect.down - rect.up
                    end if
                else
                    if focusedRect.down <= rect.down then
                        overlap = focusedRect.height
                    else if focusedRect.up >= rect.down then
                        overlap = 0
                    else
                        overlap = rect.down - focusedRect.up
                    end if
                end if

                ' If there's any overlap at all, consider the items to be on the
                ' same plane and give them a bonus.
                '
                if overlap <> 0 then orthOffset = 0

                ' Ok, it's a real candidate. We don't need to do any real math
                ' if it's not better than our best so far in at least one way.
                '
                if best.item = invalid or navOffset < best.navOffset or orthOffset <= best.orthOffset then
                    if orthOffset = 0 then
                        dotDistance = 0
                    else
                        dotDistance = int(Sqr(navOffset*navOffset + orthOffset*orthOffset))
                    end if

                    distance = dotDistance + navOffset + 2*orthOffset - int(sqr(overlap))

                    ' Debug("Evaluated " + tostr(candidate))
                    ' Debug("navOffset=" + tostr(navOffset) + " orthOffset=" + tostr(orthOffset) + " dotDistance=" + tostr(dotDistance) + " overlap=" + tostr(overlap) + " distance=" + tostr(distance))

                    if best.item = invalid or distance < best.distance then
                        ' Debug("Found a new best item: " + tostr(candidate))
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
                        ' Debug("Candidate " + tostr(candidate) + " turned out to be worse than " + tostr(best.item))
                        m.screen.DrawDebugRect(candPt.x, candPt.y, 15, 15, &h0000ffff, true)
                    end if
                else
                    m.screen.DrawDebugRect(candPt.x, candPt.y, 15, 15, &hff0000ff, true)
                    ' Debug("Candidate " + tostr(candidate) + " is obviously worse than " + tostr(best.item))
                end if
                ' sleep(500)
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

sub compCalculateShift(toFocus as object)
    if toFocus.fixed = true then return
    ' TODO(rob) handle vertical shifting. revisit safeLeft/safeRight - we can't
    ' just assume these arbitary numbers are right.
    shift = {
        x: 0
        y: 0
        safeRight: 1230
        safeLeft: 50
        ' place parent container of the component as this position
        ' * if invalid, the container will be shifted on screen to
        '   the shift.safeLeft or shift.safeRight position
        demandLeft: 300
    }

    ' verify the component is on the screen if no parent exists
    if toFocus.parent = invalid then
        focusRect = computeRect(toFocus)
        if focusRect.right > shift.safeRight
            shift.x = shift.safeRight - focusRect.right
        else if focusRect.left < shift.safeLeft then
            shift.x = shift.safeLeft - focusRect.left
        end if
    ' verify the components parent is on the screen (only tested with hubs)
    else
        parentCont = CreateObject("roList")
        checkComp = toFocus.parent.GetShiftableItems(parentCont, parentCont)
        cont = {
            checkShift: invalid
            left: invalid
            right: invalid
        }

        ' adhere to the parents wanted left position when focused
        if toFocus.parent.demandLeft <> invalid then
            shift.demandLeft = toFocus.parent.demandLeft
            shift.forceShift = true
        end if

        ' calculate the min/max left/right offsets in the parent container
        for each component in parentCont
            focusRect = computeRect(component)
            if cont.left = invalid or focusRect.left < cont.left then cont.left = focusRect.left
            if cont.right = invalid or focusRect.right > cont.right then cont.right = focusRect.right
        next

        ' calculate the shift

        ' shift left: only if the container right is off the screen (safeRight)
        if cont.right > shift.safeRight or shift.forceShift = true then
            if shift.demandLeft <> invalid then
                shift.x = (cont.left - shift.demandLeft) * -1
            else
                shift.x = shift.safeRight - cont.right
            end if
        ' shift right (special case): demandLeft<>invalid and container entire container < demandLeft
        else if shift.demandLeft <> invalid and cont.left < shift.demandLeft and cont.right < shift.demandLeft then
                shift.x = shift.demandLeft - cont.left
        ' shift right: if container left is off screen (safeLeft)
        else if cont.left < shift.safeLeft then
            if shift.demandLeft <> invalid then
                shift.x = shift.demandLeft - cont.left
            else
                shift.x = shift.safeLeft - cont.left
            end if
        end if
    end if

    if (shift.x <> 0 or shift.y <> 0) then
        TextureManager().CancelAll()
        m.screen.hideFocus()
        m.shiftComponents(shift)
    end if
end sub

sub compShiftComponents(shift)
    ' TODO(rob) the logic below has only been testing shifting the x axis.
    Debug("shift components by: " + tostr(shift.x) + "," + tostr(shift.y))
    perfTimer().mark()

    ' partShift: on screen or will be after shift (animate/scroll, partial shifting)
    ' fullShift: off screen before/after shifting (no animation, shift in full)
    partShift = CreateObject("roList")
    fullShift = CreateObject("roList")
    lazyLoad = CreateObject("roAssociativeArray")
    for each component in m.components
        component.GetShiftableItems(partShift, fullShift, lazyLoad, shift.x, shift.y)
    next
    perfTimer().Log("Determined shiftable items: " + "onscreen=" + tostr(partShift.count()) + ", offScreen=" + tostr(fullShift.count()))

    ' verify we are not shifting the components to far (first or last component). This
    ' will modify shift.x based on the first or last component viewable on screen. It
    ' should be quick to iterate partShift (on screen components after shifting).
    minMax = {}
    for each comp in partShift
        focusRect = computeRect(comp)
        if minMax.right = invalid or focusRect.right > minMax.right then minMax.right = focusRect.right
        if minMax.left = invalid or focusRect.left < minMax.left then minMax.left = focusRect.left
    end for
    minMax.right = minMax.right + shift.x
    minMax.left = minMax.left + shift.x
    if minMax.right < shift.safeRight then
        shift.x = shift.x - (minMax.right - shift.safeRight)
    else if minMax.left > shift.safeLeft then
        shift.x = shift.x + (shift.safeLeft - minMax.left)
    end if
    perfTimer().Log("verified first/last on-screen component offsets: left=" + tostr(minMax.left) + ", right=" + tostr(minMax.right))

    ' return if we calculated zero shift
    if shift.x = 0 and shift.y = 0 then return

    ' lazy-load any components that will be on-screen after we shift
    m.LazyLoadExec(partShift)

    ' Calculate the FPS shift amount. 15 fps seems to be a workable arbitrary number.
    ' Verify the px shifting are > than the fps, otherwise it's sluggish (non Roku3)
    fps = 15
    if shift.x <> 0 and abs(shift.x / fps) < fps then
        fps = int(abs(shift.x / fps))
    else if shift.y <> 0 and abs(shift.y / fps) < fps then
        fps = int(abs(shift.y / fps))
    end if

    ' TODO(rob) just a quick hack for slower roku's
    if appSettings().GetGlobal("animationFull") = false then fps = int(fps / 1.5)

    if shift.x < 0 then
        xd = int((shift.x / fps) + .9)
    else if shift.x > 0 then
        xd = int(shift.x / fps)
    else
        xd = 0
    end if

    if shift.y < 0 then
        yd = int((shift.y / fps) + .9)
    else if shift.y > 0 then
        yd = int(shift.y / fps)
    else
        yd = 0
    end if

    ' total px shifted to verfy we shifted the exact amount (when shifting partially)
    xd_shifted = 0
    yd_shifted = 0

    ' TODO(rob) only animate shifts if on screen (or will be after shift)
    for x=1 To fps
        xd_shifted = xd_shifted + xd
        yd_shifted = yd_shifted + yd

        ' we need to make sure we shifted the shift_xd amount,
        ' since can't move pixel by pixel
        if x = fps then
            if xd_shifted <> shift.x then
                if xd < 0 then
                    xd = xd + (shift.x - xd_shifted)
                else
                    xd = xd + (shift.x - xd_shifted)
                end if
            end if
            if yd_shifted <> shift.y then
                if yd < 0 then
                    yd = yd + (shift.y - yd_shifted)
                else
                    yd = yd + (shift.y - yd_shifted)
                end if
            end if
        end if

        for each comp in partShift
            comp.ShiftPosition(xd, yd)
        end for
        ' draw each shift after all components are shifted
        m.screen.drawAll()
    end for
    perfTimer().Log("Shifted ON screen items, expect *high* ms  (partShift)")

    for each comp in fullShift
        comp.ShiftPosition(shift.x, shift.y, false)
    end for
    perfTimer().Log("Shifted OFF screen items (fullShift)")

    ' draw the focus before we lazy load
    m.screen.DrawFocus(m.focusedItem, true)

    ' lazy-load any components off screen, but within our range (ll_trigger)
    ' create a timer to load when the user has stopped shifting (LazyLoadOnTimer)
    if lazyLoad.trigger = true then
        lazyLoad.components = CreateObject("roList")

        ' add any off screen component withing range
        for each candidate in fullShift
            if candidate.SpriteIsLoaded() = false and candidate.IsOnScreen(0, 0, ComponentsScreen().ll_load) then
                lazyLoad.components.Push(candidate)
            end if
        end for
        perfTimer().Log("Determined lazy load components (off screen): total=" + tostr(lazyLoad.components.count()))

        if lazyLoad.components.count() > 0 then
            m.lazyLoadTimer.active = true
            m.lazyLoadTimer.components = lazyLoad.components
            Application().AddTimer(m.lazyLoadTimer, createCallable("LazyLoadOnTimer", m))
            m.lazyLoadTimer.mark()
        end if
    end if

    if lazyLoad.components = invalid then
        m.lazyLoadTimer.active = false
        m.lazyLoadTimer.components = invalid
    end if

end sub

' Handle expiration of lazy load timer. We expect all components contained
' to be off screen. Shifting the components will reset the list.
sub compLazyLoadOnTimer(timer as object)
    if timer.components = invalid or timer.components.count() = 0 then return

    ' TODO(rob) we should set device as an AppSettings global
    device = CreateObject("roDeviceInfo")

    ' mark timer to retry if the last keypress is < timer duration
    if device.TimeSinceLastKeypress()*1000 >= timer.durationmillis then
        Debug("compLazyLoadOnTimer:: exec lazy load")
        m.LazyLoadExec(timer.components, -1)
    else
        ' re-mark the timer to retry when the user has stopped moving
        Debug("compLazyLoadOnTimer:: re-mark and retry")
        timer.active = true
        timer.mark()
    end if
end sub

' TODO(rob) assumed we know the zOrder since we call exec the lazyLoad
' by passing a list of components either on screen or off (which may not
' alway be true in the future)
sub compLazyLoadExec(components as object, zOrder=1 as integer)
    if components.count() = 0 then return
    for each comp in components
        if comp.SpriteIsLoaded() = false then
            Debug("******** Drawing (lazy-load) zOrder " + tostr(zOrder) + ", " + tostr(comp))
            comp.draw()
            ' add the sprite placeholder to the compositors screen
            if comp.sprite = invalid then
                comp.sprite = m.screen.compositor.NewSprite(comp.x, comp.y, comp.region, zOrder)
            end if
            ' set the sprites data to let all know it's NOT loaded yet
            comp.sprite.setData({lazyLoad: true, retainThisKey: true})
            comp.On("redraw", createCallable("OnComponentRedraw", CompositorScreen(), "compositorRedraw"))
        end if
    end for
    perfTimer().Log("lazy-load components")
end sub

sub compOnAccountChange(account as dynamic)
    Debug("Account changed to " + tostr(account.username) )
    Application().pushScreen(createLoadingScreen())
end sub

sub compOnInfoButton()
    item = m.focusedItem
    print "---- item ----"
    print item
    print "---- item.plexObject ----"
    print item.plexObject
    print "---- item.metadata ----"
    print item.metadata
    print "---- item.command ----"
    print item.command
end sub
