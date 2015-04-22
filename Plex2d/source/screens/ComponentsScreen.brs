function ComponentsScreen() as object
    if m.ComponentsScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BaseScreen())
        obj.Append(ListenersMixin())
        obj.Append(EventsMixin())

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
        displayHeight = AppSettings().GetHeight()
        displayWidth = AppSettings().GetWidth()
        obj.LazyLoadOnTimer = compLazyLoadOnTimer
        obj.LazyLoadExec = compLazyLoadExec
        obj.ll_timerDur = 1500

        ' Horizontal settings
        obj.ll_unloadX = int(displayWidth * 1.5)
        obj.ll_triggerX = displayWidth
        obj.ll_loadX = int(displayWidth * 1.5)

        ' vertical settings. These are fairly conservative on purpose (memory constraints)
        obj.ll_triggerY = displayHeight/4
        obj.ll_unloadY = int(displayHeight/2)
        obj.ll_loadY = int(displayHeight/2)

        ' Standard screen methods
        obj.Init = compInit
        obj.Show = compShow
        obj.Deactivate = compDeactivate
        obj.Activate = compActivate
        obj.ShowFailure = compShowFailure

        obj.GetComponents = compGetComponents
        obj.GetManualComponents = compGetManualComponents
        obj.DestroyComponents = compDestroyComponents
        obj.CloseOverlays = compCloseOverlays

        ' Manual focus methods
        obj.GetFocusManual = compGetFocusManual
        obj.CalculateFocusPoint = compCalculateFocusPoint
        obj.ToggleScrollbar = compToggleScrollbar

        ' Shifting methods
        obj.CalculateShift = compCalculateShift
        obj.ShiftComponents = compShiftComponents
        obj.CalculateFirstOrLast = compCalculateFirstOrLast

        ' Message handling
        obj.HandleMessage = compHandleMessage
        obj.HandleCommand = compHandleCommand
        obj.OnItemSelected = compOnItemSelected
        obj.OnKeyboardRelease = compOnKeyboardRelease
        obj.OnKeyPress = compOnKeyPress
        obj.OnKeyHeld = compOnKeyHeld
        obj.OnKeyRelease = compOnKeyRelease
        obj.OnPlayButton = compOnPlayButton
        obj.CancelRequests = compCancelRequests
        obj.OnFwdButton = compOnFwdButton
        obj.OnRevButton = compOnRevButton

        ' Focus handling
        obj.OnFocus = compOnFocus
        obj.OnFocusIn = compOnFocusIn
        obj.OnFocusOut = compOnFocusOut
        obj.FocusItemManually = compFocusItemManually
        obj.SetRefocusItem = compSetRefocusItem
        obj.HasRefocusItem = compHasRefocusItem
        obj.IsRefocusItem = compIsRefocusItem
        obj.RefreshAvailableComponents = compRefreshAvailableComponents

        ' Playback methods
        obj.CreatePlayerForItem = compCreatePlayerForItem

        m.ComponentsScreen = obj
    end if

    return m.ComponentsScreen
end function

sub compActivate()
    m.Init()
    m.Show()
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
    m.overlayScreen = CreateObject("roList")

    ' quick references to m.components - clear on methods: show, deactivate
    m.onScreenComponents = CreateObject("roList")
    m.fixedComponents = CreateObject("roList")
    m.shiftableComponents = CreateObject("roList")
    m.animatedComponents = CreateObject("roList")

    ' lazy load timer (loading off screen components)
    m.lazyLoadTimer = createTimer("lazyLoad")
    m.lazyLoadTimer.SetDuration(m.ll_timerDur)
    m.lazyLoadTimer.active = false
end sub

sub compShow()
    ' deactivate the lazy load timer (do not invalidate)
    if m.lazyLoadTimer <> invalid and m.lazyLoadTimer.active = true then
        m.lazyLoadTimer.active = false
    end if

    ' clear any components references (refreshing a screen)
    m.onscreenComponents.Clear()
    m.shiftableComponents.Clear()
    m.fixedComponents.Clear()
    m.animatedComponents.Clear()

    m.screen.HideFocus(true)

    Application().CheckLoadingModal()
    m.GetComponents()

    ' free up memory before drawing new components (close loading modal)
    Application().CloseLoadingModal()

    for each comp in m.components
        m.screen.DrawComponent(comp, m)
        comp.GetFocusableItems(m.onScreenComponents)

        ' obtain a list of the shiftable components now (cache it)
        ' TODO(rob) use on the HUB screens
        comp.GetShiftableItems(m.shiftableComponents, m.shiftableComponents)
    next

    ' Obtain a list of fixed components. These will be used as a helper
    ' along with the onScreenComponents, when manually trying to focus.
    ' note: onScreenComponents will change over time when shifting and
    ' will only include non-fixed (shiftable) components.
    for each comp in m.onScreenComponents
        if comp.fixed = true then
            m.fixedComponents.push(comp)
        end if
    end for

    if m.focusedItem = invalid then
        candidates = []
        for each component in m.components
            component.GetFocusableItems(candidates)
        next
        m.focusedItem = candidates[0]
    end if

    ' Try to refocus if applicable
    hasRefocusItem = m.HasRefocusItem()
    if m.refocus <> invalid or hasRefocusItem then
        ' Try onScreen components before any shiftable components. Screens like
        ' the preplay do not have any shiftable components.
        found = invalid
        candidates = CreateObject("roList")
        candidates.Append(m.onscreenComponents)
        candidates.Append(m.shiftableComponents)

        ' Prefer a specific refocus, but allow fallback to the id
        for each component in candidates
            if component.focusable = true then
                if hasRefocusItem and m.IsRefocusItem(component) then
                    found = component
                    Debug("Found an exact match to refocus")
                    exit for
                else if m.refocus <> invalid and component.id = m.refocus.id then
                    found = component
                    Debug("Found possible match to refocus based on component id")
                    ' Exit loop if we don't have a specific refocus item
                    if not hasRefocusItem then exit for
                end if
            end if
        end for

        if found <> invalid then
            m.focusedItem = found
        else
            Warn("Could not find a valid component to refocus. " + m.ToString())
        end if

        ' Invalidate any refocus if we didn't find a match
        if m.refocus <> invalid and m.focusedItem <> invalid and m.focusedItem.id <> m.refocus.id then
            m.refocus = invalid
        end if
        m.Delete("refocusKey")
    end if

    if m.focusedItem <> invalid then
        m.OnFocus(m.focusedItem, invalid)
    end if

    ' Always make sure we have a focus point regardless of having a focusItem. We
    ' may display a dialog on screens without initially having a focusable item.
    if m.focusX = invalid then m.focusX = 0
    if m.focusY = invalid then m.focusY = 0

    m.screen.DrawAll()

    ' process any animated components
    for each comp in m.animatedComponents
        comp.Animate()
    end for

    ' Enable listeners once we completed drawing the screen
    m.EnableListeners()

    ' Hook to show the filter box if it exists
    if m.FilterBox <> invalid then
        m.FilterBox.Show()
    end if

    ' Clear any unused cache
    TextureManager().ClearCache()
end sub

' TODO(rob) screen is not required to be passed, but we might want to ignore
' clearing some objects depending on the screen? I.E. DialogScreen. We will
' also need to exclude resetting the compositor.
sub compDeactivate(screen=invalid as dynamic)
    Debug("Deactivate ComponentsScreen: clear components, texture manager, and custom fonts")

    ' disable any lazyLoad timer
    if m.lazyLoadTimer <> invalid then
        m.lazyLoadTimer.active = false
        m.lazyLoadTimer = invalid
    end if

    ' clear any preference overrides we may have set
    AppSettings().PopPrefOverrides(m.screenID)

    TextureManager().RemoveTextureByScreenId(m.screenID)
    m.DestroyComponents()
    ' components we have created manually (AA of roList)
    for each key in m.manualComponents
        for each comp in m.manualComponents[key]
            comp.Destroy()
        end for
        m.manualComponents[key].Clear()
    end for
    m.manualComponents.Clear()

    ' references to m.components
    m.shiftableComponents.Clear()
    m.fixedComponents.Clear()
    m.onScreenComponents.Clear()
    m.animatedComponents.Clear()

    m.customFonts.Clear()
    m.focusedItem = invalid

    m.DisableListeners()

    ' Encourage some extra memory cleanup
    RunGarbageCollector()
end sub

sub compDestroyComponents(clear=true as boolean)
    ' Reset the nextComponentId if we are clearing components
    ' from the active screen. This method is inherited in a
    ' component, so we must verify the caller.
    '
    if Application().IsActiveScreen(m) then
        GetGlobalAA().AddReplace("nextComponentId", 1)
    end if

    if m.focusedItem <> invalid then
        Verbose("compDestroyComponents:: focusedItem")
        m.focusedItem.Destroy()
        m.focusedItem = invalid
    end if

    if m.components.count() > 0 then
        Verbose("compDestroyComponents:: before: " + tostr(m.components.count()))
        for each comp in m.components
            comp.Destroy()
        end for
        if clear then
            m.components.Clear()
        end if
        Verbose("compDestroyComponents:: after: " + tostr(m.components.count()))
    end if
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

        m.isKeyRepeat = false
        if keyCode >= 100 then
            if m.DrawFocusOnRelease = true then
                m.DrawFocusOnRelease = false
                m.screen.DrawFocus(m.focusedItem, true)
            end if
            m.OnKeyRelease(keyCode - 100)
            m.lastKey = -1
        else
            m.lastKey = keyCode
            m.OnKeyPress(keyCode, m.isKeyRepeat)

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

        ' If we've received a key release event, don't simulate another key
        ' press. We may have received a key release but not processed it yet
        ' because of slower events ahead of it in the queue (e.g. URL or texture
        ' events).
        '
        if Application().HasQueuedMessage(IsKeyReleaseMessage) then
            timer.active = false
            if m.DrawFocusOnRelease = true then
                m.DrawFocusOnRelease = false
                m.screen.DrawFocus(m.focusedItem, true)
            end if
        else
            m.OnKeyPress(m.lastKey, true)
        end if
    else
        timer.active = false
    end if
end sub

sub compOnKeyPress(keyCode as integer, repeat as boolean)
    m.isKeyRepeat = repeat
    if keyCode = m.kp_RT or keyCode = m.kp_LT or keyCode = m.kp_UP or keyCode = m.kp_DN then
        direction = KeyCodeToString(keyCode)
        toFocus = invalid

        ' Locate the next focusable item baed on direction and current focus
        if m.focusedItem <> invalid then
            perfTimer().mark()
            m.screen.ClearDebugSprites()
            m.screen.DrawDebugRect(m.focusX, m.focusY, 15, 15, Colors().Text, true)

            ' If the component knows its sibling, always use that.
            toFocus = m.focusedItem.GetFocusSibling(KeyCodeToString(keyCode))

            ' Check if we allow disallow manual focus or exiting the parent
            if toFocus = invalid then
                if m.focusedItem.ManualFocusIsAllowed() <> true then
                    Debug("manual focus not allowed from component")
                    continue = false
                else if not m.focusedItem.NonParentExitIsAllowed(direction) then
                    Debug("manual focus not allowed from component: direction=" + tostr(direction))
                    continue = false
                else if m.focusedItem.parent <> invalid and not m.focusedItem.parent.NonParentExitIsAllowed(direction) then
                    Debug("manual focus not allowed by parent: direction=" + tostr(direction) )
                    continue = false
                else
                    continue = true
                end if

                ' I do not think we need to have a distinction when we disallow
                ' manual focus vs failing to a focusable component.
                if continue = false then
                    m.Trigger("OnFailedFocus", [direction, m.focusedItem])
                    return
                end if
            end if

            ' If we're doing the opposite of our last direction, go back to
            ' where we came from.
            if toFocus = invalid and m.lastFocusedItem <> invalid and m.lastFocusedItem.focusable = true and direction = OppositeDirection(m.lastDirection) then
                toFocus = m.lastFocusedItem
            end if

        ' Use the last focused item if nothing is currently focused
        else if m.lastFocusedItem <> invalid then
            toFocus = m.lastFocusedItem
        end if

        ' fallback to manual search for focusable component
        if toFocus = invalid and m.focusedItem <> invalid then
            ' Try to keep the focus contained to the parent, if applicable.
            parentComponents = firstOf(m.focusedItem.shiftableParent, m.focusedItem.parent, {}).components
            if parentComponents <> invalid then
                toFocus = m.GetFocusManual(KeyCodeToString(keyCode), parentComponents)
            end if

            ' All else failed, search manually.
            if toFocus = invalid and m.focusedItem.NonParentFocusIsAllowed(direction) then
                ' support to manually focus on an overlay screen. Force GetFocusManual
                ' to only use the components on the overlay as focus candidates
                if m.overlayScreen.Count() > 0 then
                    components = m.overlayScreen.Peek().components
                else
                    components = invalid
                end if

                toFocus = m.GetFocusManual(KeyCodeToString(keyCode), components)
            end if
        end if

        if toFocus <> invalid then
            perfTimer().Log("Determined next focus")
            m.lastDirection = direction
            m.OnFocus(toFocus, m.focusedItem, direction)
        else
            m.Trigger("OnFailedFocus", [direction, m.focusedItem])
        end if
    else if keyCode = m.kp_REV or keyCode = m.kp_FWD then
        if m.isKeyRepeat then m.DrawFocusOnRelease = true
        if keyCode = m.kp_FWD then
            m.OnFwdButton(m.focusedItem)
        else
            m.OnRevButton(m.focusedItem)
        end if
    else if keyCode = m.kp_BK and m.isKeyRepeat then
        m.isKeyRepeat = false
        m.keyPressTimer.active = false
        m.keyPressTimer = invalid
        Application().GoHome()
        Locks().LockOnce("BackButton")
    end if
end sub

sub compOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_OK then
        if m.focusedItem <> invalid and m.focusedItem.selectable = true then
            m.OnItemSelected(m.focusedItem)
        end if
    else if keyCode = m.kp_BK then
        Application().popScreen(m)
    else if keyCode = m.kp_RW then
        m.OnRewindButton()
    else if keyCode = m.kp_INFO then
        m.OnInfoButton()
    else if keyCode = m.kp_PLAY then
        m.OnPlayButton(m.focusedItem)
    else if keyCode > 13 or (keyCode = 1 or keyCode = 11 or keyCode = 12) then
        m.OnKeyboardRelease(keyCode, chr(keyCode))
    end if
end sub

sub compOnPlayButton(item as object)
    m.CreatePlayerForItem(item.plexObject)
end sub

sub compFocusItemManually(toFocus as object)
    m.OnFocus(toFocus, m.focusedItem)

    ' clear lastFocusedItem (no focus sibling wanted)
    m.lastFocusedItem = invalid
end sub

sub compOnItemSelected(item as object)
    Debug("component item selected with command: " + tostr(item.command))

    if item.OnSelected <> invalid then
        Debug("Defer to items OnSelected method")
        item.OnSelected(m)
    else if item.command <> invalid then
        if not m.HandleCommand(item.command, item) then
            dialog = createDialog("Command not defined", "command: " + tostr(item.command), m)
            dialog.Show()
            Debug("command not defined: " + tostr(item.command))
        end if
    end if
end sub

function compHandleCommand(command as string, item as dynamic) as boolean
    handled = true

    ' Handle some generic commands here. Anything specific to a screen type
    ' should be handled in that screen type.

    if command = "go_home" then
        Application().GoHome()
    else if command = "show_dropdown" then
        item.Show()
    else if command = "show_item" and item.plexObject <> invalid then
        ' We want to show a screen for a PlexObject of some sort. Look at the
        ' type and try to choose the best screen type.
        '
        itemType = firstOf(item.plexObject.Get("type"), item.plexObject.type)

        if itemType = invalid then
            Error("Don't know how to show an item with no type")
        else if itemType = "clip" then
            m.CreatePlayerForItem(item.plexObject)
        else if itemType = "movie" or itemType = "episode" or itemType = "clip" then
            ' Simple preplay
            Application().PushScreen(createPreplayScreen(item.plexObject))
        else if itemType = "album" then
            Application().PushScreen(createAlbumScreen(item.plexObject))
        else if itemType = "artist" then
            Application().PushScreen(createArtistScreen(item.plexObject))
        else if itemType = "playlist" then
            Application().PushScreen(createPlaylistScreen(item.plexObject))
        else if itemType = "show" then
            Application().PushScreen(createPreplayContextScreen(item.plexObject))
        else if item.plexObject.IsDirectory() then
            Application().PushScreen(createGridScreen(item.plexObject))
        else
            dialog = createDialog("Item type not handled yet", "type: " + itemType, m)
            dialog.Show()
        end if
    else if command = "show_users" then
        Application().PushScreen(createUsersScreen(false))
    else if command = "switch_user" then
        user = item.metadata

        ' allow the existing authenticated user to switch (refresh)
        if MyPlexAccount().isAuthenticated = true and user.id = MyPlexAccount().id then
            Application().Trigger("change:user", [MyPlexAccount(), false])
        ' PIN prompt protected user, unless switching from an admin user
        else if user.IsProtected and (MyPlexAccount().isAuthenticated = false or MyPlexAccount().isAdmin = false) then
            ' pinPrompt handles switching and error feedback
            pinPrompt = createPinPrompt(m, user)
            pinPrompt.Show(true)
        else if not MyPlexAccount().SwitchHomeUser(user.id) then
            ' provide feedback on failure to switch to non protected users
            ' TODO(rob): need verbiage for failure
            dialog = createDialog("Unable to switch users", "Please check your connection and try again.", m)
            dialog.Show()
        end if
    else if command = "now_playing" then
        Application().PushScreen(createNowPlayingScreen(AudioPlayer().GetCurrentItem()))
    else if command = "play" or command = "shuffle" then
        plexItem = firstOf(item.plexObject, m.item)

        if plexItem <> invalid then
            options = createPlayOptions()
            options.shuffle = (command = "shuffle")

            m.CreatePlayerForItem(plexItem, options)
        end if
    else if command = "play_next" or command = "add_to_queue" then
        plexItem = firstOf(item.plexObject, m.item)
        playQueue = addItemToPlayQueue(plexItem, (command = "play_next"))

        if playQueue = invalid then
            ' TODO(schuyler): All of this error handling is lame...
            dialog = createDialog("Unable to play item", "We're unable to add this item to your play queue", m)
            dialog.Show()
        end if
    else if command = "play_music_video" then
        plexItem = firstOf(item.plexObject, m.item)
        foundExtra = false

        if plexItem <> invalid then
            extraItem = plexItem.GetPrimaryExtra()

            if extraItem <> invalid then
                foundExtra = true
                m.CreatePlayerForItem(extraItem)
            end if
        end if

        if not foundExtra then
            dialog = createDialog("Unable to load music video", "We're unable to find a music video for this track", m)
            dialog.Show()
        end if
    else if command = "play_plex_mix" then
        plexItem = firstOf(item.plexObject, m.item)
        foundPlexMix = false

        if plexItem <> invalid then
            ' The track should have been fetched with details including related
            ' items already. We _could_ make a blocking request now if
            ' relatedItems is invalid, but since we think we already have the
            ' details we're not bothering.

            relatedItem = plexItem.GetRelatedItem("plexmix")
            if relatedItem <> invalid then
                ' TODO(schuyler): Also, if we create a Plex Mix for the currently playing track, it restarts the track.
                m.screen.DrawLock(5000)
                pq = createPlayQueueForItem(relatedItem)
                player = GetPlayerForType(pq.type)
                if player <> invalid then
                    player.SetPlayQueue(pq, true)
                    foundPlexMix = true
                end if
            end if
        end if

        if not foundPlexMix then
            dialog = createDialog("Unable to create Plex Mix", "We're unable to create a Plex Mix for this track", m)
            dialog.Show()
        end if
    else if command = "go_to_artist" then
        plexItem = firstOf(item.plexObject, m.item)
        Application().PushScreen(createArtistScreen(plexItem, plexItem.Get("grandparentKey")))
    else if command = "go_to_album" then
        plexItem = firstOf(item.plexObject, m.item)
        Application().PushScreen(createAlbumScreen(plexItem, plexItem.Get("parentKey")))
    else if command = "toggle_watched" then
        plexItem = firstOf(item.plexObject, m.item)

        if plexItem.IsUnwatched() or plexItem.InProgress() then
            plexItem.Scrobble(item.commandCallback)
        else
            plexItem.Unscrobble(item.commandCallback)
        end if
    else
        handled = false
    end if

    ' TODO(schuyler): Is this the best way to do this?
    if item <> invalid and item.closeOverlay = true then
        m.overlayScreen.Peek().Close()
    end if

    return handled
end function

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
    ' Shortcut until we rework the focus point logic (roku-client/issues/282).
    if component.Equals(MiniPlayer()) then return component
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

function compGetFocusManual(direction as string, focusableComponenents=invalid as dynamic) as dynamic
    ' These should never happen...
    if m.focusedItem = invalid or m.focusX = invalid or m.focusY = invalid then return invalid

    ' Debug("Evaluating manual " + direction + " focus for " + tostr(m.focusedItem))

    oppositeDir = OppositeDirection(direction)

    candidates = CreateObject("roList")

    ' focusableComponenents: use to override the screens components and
    ' onScreenComponents. Useful for overlays needing their own focus logic.
    ' m.onScreenComponents: quick bypass to only check the onScreen components.
    ' This is already done on first load and when shifting.
    if focusableComponenents <> invalid then
        for each component in focusableComponenents
            component.GetFocusableItems(candidates)
        next
    else if m.onScreenComponents <> invalid then
        for each component in m.onScreenComponents
            if component.focusable then candidates.push(component)
        next
        for each component in m.fixedComponents
            if component.focusable then candidates.push(component)
        next

        ' Add the mini player to the candidates if focusable
        if m.overlayScreen.Count() = 0 and MiniPlayer().focusable then
            candidates.push(MiniPlayer())
        end if
    end if

    ' fall back if we do not have any valid candidates (slower check)
    if candidates.count() = 0 and focusableComponenents = invalid then
        ' Ask each component to add to our list of candidates.
        for each component in m.components
            component.GetFocusableItems(candidates)
        next
    end if

    ' Move our current focus point to the edge of the current component in
    ' the direction we're moving.
    focusedRect = computeRect(m.focusedItem)
    if direction = "left" or direction = "right" then
        m.focusX = focusedRect[direction]
    else
        m.focusY = focusedRect[direction]
    end if

    ' draw where we moved the focus point
    m.screen.DrawDebugRect(m.focusX, m.focusY, 15, 15, Colors().Orange, true)

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
        ' exclude parent check if the candidate is a child of the same shiftableParent or Parent, or is parentless.
        if candidate.shiftableParent <> invalid and candidate.shiftableParent.equals(m.focusedItem.shiftableParent) then
            excludeParentCheck = true
        else if candidate.parent = invalid or candidate.parent <> invalid and candidate.parent.Equals(m.focusedItem.parent) then
            excludeParentCheck = true
        else
            excludeParentCheck = false
        end if

        ' ignore current focused item, or any item above their parents y position (VBox veritical scroll)
        if not candidate.Equals(m.focusedItem) and (excludeParentCheck = true or candidate.y >= candidate.parent.y) then
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
            ' TODO(schuyler): Excluding candidates with a zero offset can
            ' actually be problematic since we moved our focus point to the
            ' edge of the item in the direction of navigation. If we have
            ' "dense" components with no space between them, then the best
            ' candidate will have a zero nav offset.
            '
            if navOffset > 0 then
                if orthOffset < 0 then orthOffset = -1 * orthOffset

                ' Prioritize items that overlap on the orth axix.
                ' TODO(schuyler): This is hopelessly wrong, isn't it? It always
                ' looks at up and down without regard for the direction of
                ' navigation.
                '
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

    ' Let the pending focus item override what we will actually focus on. Basically,
    ' this handles focusing on a desired item within the parent. e.g. jumpBox: focus
    ' on the current character in use, instead of the closest character in relation
    ' to the last focused item.
    if best.item <> invalid and type(best.item.GetFocusManual) = "roFunction" then
        candidate = best.item.GetFocusManual()
        if candidate <> invalid then
            best.item = candidate
            best.x = best.item.x
            best.y = best.item.y
        end if
    end if

    ' If we found something then return it. Otherwise, we can at least move the
    ' focus point to the edge of our current component.
    '
    if best.item <> invalid then
        m.focusX = best.x
        m.focusY = best.y
    end if

    return best.item
end function

sub compCalculateShift(toFocus as object, refocus=invalid as dynamic)
    if toFocus.fixed = true then return

    ' allow the component to override the method. e.g. VBox vertical scrolling
    ' * shiftableParent for containers in containers (e.g. users screen: vbox -> hbox -> component)
    ' * continue with the standard container shift (horizontal scroll), after override
    if toFocus.shiftableParent <> invalid and type(toFocus.shiftableParent.CalculateShift) = "roFunction" then
        toFocus.shiftableParent.CalculateShift(toFocus, refocus, m)
    else if toFocus.parent <> invalid and type(toFocus.parent.CalculateShift) = "roFunction" then
        toFocus.parent.CalculateShift(toFocus, refocus, m)
    end if

    ' TODO(rob) handle vertical shifting. revisit safeLeft/safeRight - we can't
    ' just assume these arbitary numbers are right.
    shift = {
        x: 0
        y: 0
        safeRight: 1230
        safeLeft: 50
    }

    ' Improve our caculation time. We can safely ignore the parent checks if the
    ' toFocus and current focus are siblings of a vbox parent.
    parent = toFocus.parent
    if parent <> invalid and (parent.ignoreParentShift = true or parent.isVScrollable = true and parent.Equals(m.focusedItem.parent)) then
        ignoreParent = true
    else
        ignoreParent = false
    end if

    focusRect = computeRect(toFocus)
    ' reuse the last position on refocus
    if refocus <> invalid and focusRect.left <> refocus.left then
        shift.x = refocus.left - focusRect.left
    ' verify the component is on the screen if no parent exists
    else if ignoreParent then
        if parent.demandLeft <> invalid then
            shift.x = parent.demandLeft - focusRect.left
        else if focusRect.right > shift.safeRight
            shift.x = shift.safeRight - focusRect.right
        else if focusRect.left < shift.safeLeft then
            shift.x = shift.safeLeft - focusRect.left
        end if
    ' verify the components parent is on the screen (only tested with hubs)
    else
        parentCont = CreateObject("roList")
        checkComp = parent.GetShiftableItems(parentCont, parentCont)
        cont = {
            checkShift: invalid
            left: invalid
            right: invalid
        }

        ' adhere to the parents wanted left position
        if parent <> invalid and parent.first = true then
            shift.demandLeft = shift.safeLeft
            shift.forceShift = (m.lastDirection <> "left")
        else if parent.demandLeft <> invalid then
            shift.demandLeft = parent.demandLeft
        end if

        ' calculate the min/max left/right offsets in the parent container
        for each component in parentCont
            focusRect = computeRect(component)
            if cont.left = invalid or focusRect.left < cont.left then cont.left = focusRect.left
            if cont.right = invalid or focusRect.right > cont.right then cont.right = focusRect.right
        next

        ' ignore shifting if the entire container is on the screen, unless we force it.
        if not shift.forceShift = true and shift.demandLeft <> invalid and cont.left > shift.safeLeft and cont.right < shift.safeRight then
            shift.demandLeft = invalid
        end if

        ' calculate the shift

        ' shift left: only if the container right is off the screen (safeRight)
        if (cont.right > shift.safeRight) or (shift.demandLeft <> invalid and cont.left <> shift.demandLeft) then
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
        m.screen.hideFocus()
        m.shiftComponents(shift, refocus)
    end if
end sub

sub compShiftComponents(shift as object, refocus=invalid as dynamic)
    ' disable any lazyLoad timer
    ' TODO(schuyler): I added this check to avoid a crash, but it just meant we
    ' crashed somewhere else. We'll need to figure this out.
    if m.lazyLoadTimer <> invalid then
        m.lazyLoadTimer.active = false
        m.lazyLoadTimer.components = invalid
    end if

    ' If we are shifting by a lot, we'll need to "jump" and clear some components
    ' as we cannot animate it (for real) due to memory limitations (and speed).
    if shift.x > 1280 or shift.x < -1280 then
        ' cancel any pending textures before we have a large shift
        TextureManager().CancelAll(false)

        ' Two Passes:
        '  1. Get a list of components on the screen after shift
        '      while unloading components offscreen
        '  2: Recalculate the shift (first last grid check) and
        '     shift all coponents without shifting sprites. Then
        '     fire off events to lazy load if needed.

        ' Pass 1
        onScreen = CreateObject("roList")
        for each comp in m.shiftableComponents
            if comp.IsOnScreen(shift.x, shift.y) then
                onScreen.push(comp)
            end if
        end for

        ' Pass 2
        shift.x = m.CalculateFirstOrLast(onScreen, shift)
        onScreen.Clear()
        for each comp in m.shiftableComponents
            comp.ShiftPosition(shift.x, shift.y, false)
            if comp.IsOnScreen() then
                comp.ShiftPosition(0, 0)
                onScreen.push(comp)
            else if comp.sprite <> invalid or comp.region <> invalid then
                comp.Unload()
            end if
        end for

        m.onScreenComponents = onScreen

        m.LazyLoadExec(onScreen)
        return
    end if

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

    ' set the onScreen components (helper for the manual Focus)
    m.onScreenComponents = partShift

    ' verify we are not shifting the components to far (first or last component). This
    ' will modify shift.x based on the first or last component viewable on screen. It
    ' should be quick to iterate partShift (on screen components after shifting).
    skipIgnore = (m.focusedItem.parent <> invalid and m.focusedItem.parent.ignoreFirstLast = true)
    shift.x = m.CalculateFirstOrLast(partShift, shift, skipIgnore)

    ' return if we calculated zero shift
    if shift.x = 0 and shift.y = 0 then return

    ' lazy-load any components that will be on-screen after we shift
    ' and cancel any pending texture requests
    TextureManager().CancelAll(false)
    m.LazyLoadExec(partShift)

    if refocus = invalid then
        AnimateShift(shift, partShift, m.screen)
    else
        for each component in partShift
            component.ShiftPosition(shift.x, shift.y, true)
        end for
    end if
    perfTimer().Log("Shifted ON screen items, expect *high* ms  (partShift)")

    for each comp in fullShift
        comp.ShiftPosition(shift.x, shift.y, false)
    end for
    perfTimer().Log("Shifted OFF screen items (fullShift)")

    ' draw the focus before we lazy load
    if m.DrawFocusOnRelease <> true then
        m.screen.DrawFocus(m.focusedItem, true)
    end if

    ' lazy-load any components off screen, but within our range (ll_triggerX)
    ' create a timer to load when the user has stopped shifting (LazyLoadOnTimer)
    ' TODO(rob): we should attach the screen or screen ID just to be verify
    ' when we execute the lazy load, that we're still in the same context.
    if lazyLoad.trigger = true then
        lazyLoad.components = CreateObject("roList")

        ' add any off screen component withing range
        for each candidate in fullShift
            if candidate.SpriteIsLoaded() = false and candidate.IsOnScreen(0, 0, m.ll_loadX, m.ll_loadY) then
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
    if timer.chunks = invalid and (timer.components = invalid or timer.components.count() = 0) then return

    ' mark timer to retry if the last keypress is < timer duration
    if AppSettings().GetGlobal("roDeviceInfo").TimeSinceLastKeypress() * 1000 >= timer.durationmillis then
        Debug("compLazyLoadOnTimer:: exec lazy load")
        ' process the grid chunks first
        if timer.chunks <> invalid then
            m.LoadGridChunk(timer.chunks, 0, timer.chunks.count())
        end if
        ' process any components last
        if timer.components <> invalid then
            m.LazyLoadExec(timer.components, -1)
        end if
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
    if not Application().IsActiveScreen(m) then return
    if components.count() = 0 then return
    for each comp in components
        if comp.SpriteIsLoaded() = false then
            Debug("Drawing (lazy-load) zOrder " + tostr(zOrder) + ", " + tostr(comp))
            comp.Draw()
            ' add the sprite placeholder to the compositors screen
            if comp.sprite = invalid then
                comp.sprite = m.screen.compositor.NewSprite(comp.x, comp.y, comp.region, zOrder)
            end if
            comp.On("redraw", createCallable("OnComponentRedraw", CompositorScreen(), "compositorRedraw"))
        end if
    end for
    perfTimer().Log("lazy-load components")
end sub

function compCalculateFirstOrLast(components as object, shift as object, skipIgnore=false as boolean) as integer
    minMax = {}
    for each comp in components
        if skipIgnore = true or comp.parent = invalid or not comp.parent.ignoreFirstLast = true then
            focusRect = computeRect(comp)
            if minMax.right = invalid or focusRect.right > minMax.right then minMax.right = focusRect.right
            if minMax.left = invalid or focusRect.left < minMax.left then minMax.left = focusRect.left
        end if
    end for

    ' ALL Components fit on screen, ignore shifting.
    if minMax.right <= shift.safeRight and minMax.left >= shift.safeLeft then return 0

    minMax.right = minMax.right + shift.x
    minMax.left = minMax.left + shift.x
    if minMax.right < shift.safeRight then
        shift.x = shift.x - (minMax.right - shift.safeRight)
    else if minMax.left > shift.safeLeft then
        shift.x = shift.x + (shift.safeLeft - minMax.left)
    end if
    perfTimer().Log("verified first/last on-screen component offsets: left=" + tostr(minMax.left) + ", right=" + tostr(minMax.right))

    return shift.x
end function

sub compCreatePlayerForItem(plexObject=invalid as dynamic, options=invalid as dynamic)
    if not IsAssociativeArray(plexObject) or not IsFunction(plexObject.isLibraryItem) then return
    if options = invalid then options = createPlayOptions()

    if plexObject.isLibraryItem() then
        ' If this is a video item with a resume point, ask if we should resume. We also
        ' need to obtain this prior to play queue creation for cinema trailers.
        if plexObject.IsVideoOrDirectoryItem() then
            if plexObject.GetInt("viewOffset") > 0 and options.resume = invalid then
                options.resume = VideoResumeDialog(plexObject, m)
                if options.resume = invalid then return
            end if
        end if

        pq = createPlayQueueForItem(plexObject, options)
        player = GetPlayerForType(pq.type)
        if player <> invalid then
            player.shouldResume = options.resume
            player.SetPlayQueue(pq, true)
        end if
    end if
end sub

sub compToggleScrollbar(visible=true as boolean, toFocus=invalid as dynamic, lastFocus=invalid as dynamic)
    if toFocus <> invalid then
        focusScroll = firstOf(toFocus.shiftableParent, toFocus.parent, {}).scrollbar
    else
        focusScroll = invalid
    end if

    if lastFocus <> invalid then
        lastFocusScroll = firstOf(lastFocus.shiftableParent, lastFocus.parent, {}).scrollbar
    else
        lastFocusScroll = invalid
    end if

    ' ignore if toFocus and lastFocus do not contain a scrollbar
    if focusScroll = invalid and lastFocusScroll = invalid then return

    ' hide scrollbar regardless of visible boolean if scrollbars are different
    if lastFocusScroll <> invalid and not lastFocusScroll.Equals(focusScroll) then
        lastFocusScroll.Hide()
    end if

    ' show current scrollbar if visible and new
    if visible = true and focusScroll <> invalid and not focusScroll.Equals(lastFocusScroll) then
        focusScroll.Show()
    end if
end sub

sub compOnFocus(toFocus as object, lastFocus=invalid as dynamic, direction=invalid as dynamic)
    if toFocus.Equals(lastFocus) then lastFocus = invalid
    if toFocus.focusBorder = false then m.screen.HideFocus(true)

    ' set focus and last focused item
    m.focusedItem = toFocus
    m.lastFocusedItem = lastFocus

    ' let the current focus know it's now blurred before shifting
    m.OnFocusOut(lastFocus, toFocus)

    m.CalculateShift(toFocus, m.refocus)
    m.Delete("refocus")

    ' reset the focus point after shifting
    if direction <> invalid then
        focusPoint = m.CalculateFocusPoint(toFocus, direction)
        m.focusX = focusPoint.x
        m.focusY = focusPoint.y
    else
        m.focusX = toFocus.x
        m.focusY = toFocus.y
    end if
    m.screen.DrawDebugRect(m.focusX, m.focusY, 15, 15, &hffffff80, true)

    ' let the new focus know it's now focused after shifting
    m.OnFocusIn(toFocus, lastFocus)

    if m.DrawFocusOnRelease <> true then
        m.screen.DrawFocus(toFocus, true)
    end if
end sub

sub compOnFocusIn(toFocus=invalid as dynamic, lastFocus=invalid as dynamic)
    if toFocus = invalid then return

    ' let the component know it's focus state
    toFocus.OnFocus()

    m.ToggleScrollbar(true, toFocus, lastFocus)
end sub

sub compOnFocusOut(lastFocus=invalid as dynamic, toFocus=invalid as dynamic)
    ' let the component know it's focus state
    if lastFocus <> invalid then
        lastFocus.OnBlur(toFocus)
    end if

    ' update the description box
    if m.DescriptionBox <> invalid then
        m.DescriptionBox.Show(toFocus)
    end if

    m.ToggleScrollbar(false, toFocus, lastFocus)
end sub

sub compCloseOverlays(redraw=true as boolean)
    while m.overlayScreen.Peek() <> invalid
        m.overlayScreen.Peek().Close(false, redraw)
    end while
end sub

sub compShowFailure(title=invalid as dynamic, text=invalid as dynamic, popScreen=true as boolean)
    ' Since we process messages while we are "blocking", it's possible we may recieve
    ' a another failure while we are currently displaying one. We can either close the
    ' errorDialog, and display the new one, or ignore it. I choose the first.
    if m.errorDialog <> invalid then return

    ' Use a default error message if we haven't set one
    if title = invalid then title = "Content Unavailable"
    if text = invalid then text = "An error occurred while trying to load this content, make sure the server is running."
    m.errorDialog = createDialog(title, text, m)
    m.errorDialog.Show(true)
    m.errorDialog = invalid
    if popScreen then Application().popScreen(m)
end sub

sub compOnKeyboardRelease(keyCode as integer, value as string)
    Verbose("no-op keyboard release: keyCode=" + tostr(keyCode) + ", value=" + value)
end sub

sub compCancelRequests()
    Application().CancelRequests(tostr(m.screenID))
end sub

sub compOnFwdButton(item=invalid as dynamic)
    ' no-op
end sub

sub compOnRevButton(item=invalid as dynamic)
    ' no-op
end sub

sub compRefreshAvailableComponents()
    m.onScreenComponents.Clear()
    m.shiftableComponents.Clear()
    m.fixedComponents.Clear()

    for each comp in m.components
        comp.GetFocusableItems(m.onScreenComponents)
        comp.GetShiftableItems(m.shiftableComponents, m.shiftableComponents)
    end for

    for each comp in m.onScreenComponents
        if comp.fixed = true then
            m.fixedComponents.push(comp)
        end if
    end for
end sub

function compHasRefocusItem() as boolean
    return IsAssociativeArray(m.refocusKey)
end function

sub compSetRefocusItem(item=invalid as dynamic, keys=["ratingKey", "uuid", "hubKey", "key"] as object)
    if not IsAssociativeArray(item) then return

    plexObject = iif(item.plexObject <> invalid, item.plexObject, item)
    if IsFunction(plexObject.GetFirst) and plexObject.GetFirst(keys) <> invalid then
        for each key in keys
            if plexObject.Has(key) then
                m.refocusKey = {
                    key: key,
                    value: plexObject.Get(key)
                    ' Append the container key to eliminate duplicates, and we'll
                    ' consider the match valid if the container key is invalid.
                    '
                    containerKey: plexObject.Container.Get("key")
                }
                exit for
            end if
        end for
    else
        ' Fallback to a root key in the component
        for each key in keys
            if item[key] <> invalid then
                m.refocusKey = {key: key, value: item[key]}
                exit for
            end if
        end for
    end if
end sub

function compIsRefocusItem(item=invalid as dynamic) as boolean
    if not m.HasRefocusItem() or not IsAssociativeArray(item) then return false

    plexObject = iif(item.plexObject <> invalid, item.plexObject, item)
    if IsFunction(plexObject.Get) and m.refocusKey.value = plexObject.Get(m.refocusKey.key) then
        ' Verify the container key is the same to eliminate duplicate plexObjects,
        ' however, we will allow the containerKey to be invalid and still match.
        if m.refocusKey.containerKey = invalid then
            return true
        else if plexObject.container <> invalid and m.refocusKey.containerKey = plexObject.container.Get("key") then
            return true
        end if
    end if

    return (m.refocusKey.value = item[m.refocusKey.key])
end function
