function OverlayClass() as object
    if m.OverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "OverlayClass"

        obj.Show = overlayShow
        obj.Init = overlayInit
        obj.OnKeyRelease = overlayOnKeyRelease
        obj.Close = overlayClose
        obj.IsActive = overlayIsActive
        obj.AssignOverlayID = overlayAssignOverlayID

        m.OverlayClass = obj
    end if

    return m.OverlayClass
end function

sub overlayAssignOverlayID()
    if m.overlayID = invalid then
        m.overlayID = m.screen.overlayScreen.Count()
    end if

    m.zOrderOverlay = ZOrders().OVERLAY + m.overlayID
    m.components = m.screen.GetManualComponents(m.ClassName + tostr(m.overlayID))

    for each overlay in m.screen.overlayScreen
        if overlay.overlayID = m.overlayID then return
    end for

    m.screen.overlayScreen.Push(m)
end sub

sub overlayInit()
    ApplyFunc(ComponentClass().Init, m)

    ' Support for multiple overlay screens
    m.AssignOverlayID()

    m.enableBackButton = true
    m.enableOverlay = false
    m.blocking = false

    ' remember the current focus and invalidate it
    m.fromFocusedItem = m.screen.focusedItem
    m.screen.lastFocusedItem = invalid
    m.screen.FocusedItem = invalid

    m.OrigScreenFunctions = {
        OnKeyRelease: m.screen.OnKeyRelease,
        OrigOnKeyRelease: m.screen.OrigOnKeyRelease
        OnKeyboardRelease: m.screen.OnKeyboardRelease,
        OrigOnKeyboardRelease: m.screen.OrigOnKeyboardRelease
        OnFocusIn: m.screen.OnFocusIn,
        OrigOnFocusIn: m.screen.OrigOnFocusIn
        OnFocusOut: m.screen.OnFocusOut,
        OrigOnFocusOut: m.screen.OrigOnFocusOut,
        OnRevButton: m.screen.OnRevButton,
        OrigOnRevButton: m.screen.OrigOnRevButton,
        OnFwdButton: m.screen.OnFwdButton,
        OrigOnFwdButton: m.screen.OrigOnFwdButton,
    }
    m.screen.OrigOnKeyRelease = firstOf(m.screen.OrigOnKeyRelease, m.screen.OnKeyRelease)
    m.screen.OnKeyRelease = m.OnKeyRelease
    m.screen.OrigOnKeyboardRelease = firstOf(m.screen.OrigOnKeyboardRelease, m.screen.OnKeyboardRelease)
    m.screen.OnKeyboardRelease = firstOf(m.OnKeyboardRelease, compOnKeyboardRelease)
    m.screen.OrigOnFocusIn = firstOf(m.screen.OrigOnFocusIn, m.screen.OnFocusIn)
    m.screen.OnFocusIn = firstOf(m.OnFocusIn, compOnFocusIn)
    m.screen.OrigOnFocusOut = firstOf(m.screen.OrigOnFocusOut, m.screen.OnFocusOut)
    m.screen.OnFocusOut = firstOf(m.OnFocusOut, compOnFocusOut)
    m.screen.OrigOnRevButton = firstOf(m.screen.OrigOnRevButton, m.screen.OnRevButton)
    m.screen.OnRevButton = firstOf(m.OnRevButton, compOnRevButton)
    m.screen.OrigOnFwdButton = firstOf(m.screen.OrigOnFwdButton, m.screen.OnFwdButton)
    m.screen.OnFwdButton = firstOf(m.OnFwdButton, compOnFwdButton)

    m.buttons = CreateObject("roList")
    m.customFonts = CreateObject("roAssociativeArray")
end sub

' From the context of the underlying screen. Process everything as
' we would, but intercept the back button and close the overlay.
sub overlayOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK then
        Debug("back button pressed: closing overlay")
        m.overlayScreen.Peek().Close(true)
    else
        m.OrigOnKeyRelease(keyCode)
    end if
end sub

sub overlayOnKeyboardRelease(keyCode as integer, value as string)
    m.OrigOnKeyboardRelease(keyCode, value)
end sub

sub overlayClose(backButton=false as boolean, redraw=true as boolean)
    if m.enableBackButton = false then EnableBackButton()
    m.blocking = false

    ' deactivate the lazy load timer (do not invalidate)
    if m.screen.lazyLoadTimer <> invalid then
        m.screen.lazyLoadTimer.active = false
    end if

    ' reset screen OnKeyRelease to original
    m.screen.Append(m.OrigScreenFunctions)

    TextureManager().RemoveTextureByOverlayId(m.uniqID)
    m.DisableListeners()
    m.DestroyComponents()
    m.customFonts.clear()

    m.screen.overlayScreen.Pop()

    ' refocus on the item we initially came from
    m.screen.lastFocusedItem = invalid

    ' normally we want to redraw the screen if an overlay is closed
    ' however we don't want to redraw if we are pushing or popping
    ' a new screen.
    if redraw then
        if m.fromFocusedItem <> invalid then
            m.screen.OnFocus(m.fromFocusedItem)
        else
            m.screen.screen.HideFocus(true, true)
        end if
    else
        m.screen.screen.HideFocus(true, false)
        m.screen.focusedItem = m.fromFocusedItem
    end if

    ' Let the parent screen know we closed
    m.Trigger("close", [m, backButton])
end sub

sub overlayShow(blocking=false as boolean)
    Application().CloseLoadingModal()
    if m.enableBackButton = false then DisableBackButton()

    m.GetComponents()

    ' dim the underlying screen
    if m.enableOverlay = false then
        dimmer = createBlock(Colors().OverlayMed)
        dimmer.SetFrame(0, 0, 1280, 720)
        dimmer.zOrder = m.zOrderOverlay - 1
        m.components.unshift(dimmer)
    end if

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    m.screen.FocusItemManually(m.screen.focusedItem)

    ' Enable listeners once we completed drawing the screen
    m.EnableListeners()

    m.blocking = blocking
    if m.blocking = true then
        timeout = 0
        while m.blocking = true
            timeout = Application().ProcessOneMessage(timeout)
        end while
    end if
end sub

function overlayIsActive() as boolean
    return m.Equals(m.screen.overlayScreen.Peek())
end function
