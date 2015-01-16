function OverlayClass() as object
    if m.OverlayClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "OverlayClass"

        obj.Show = overlayShow
        obj.Init = overlayInit
        obj.OnKeyRelease = overlayOnKeyRelease
        obj.Close = overlayClose

        m.OverlayClass = obj
    end if

    return m.OverlayClass
end function

sub overlayInit()
    ApplyFunc(ComponentClass().Init, m)
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
    }
    m.screen.OrigOnKeyRelease = firstOf(m.screen.OrigOnKeyRelease, m.screen.OnKeyRelease)
    m.screen.OnKeyRelease = m.OnKeyRelease
    m.screen.overlayScreen = m

    m.components = m.screen.GetManualComponents(m.ClassName)
    m.buttons = CreateObject("roList")
    m.customFonts = CreateObject("roAssociativeArray")
end sub

' From the context of the underlying screen. Process everything as
' we would, but intercept the back button and close the overlay.
sub overlayOnKeyRelease(keyCode as integer)
    if keyCode = m.kp_BK then
        Debug("back button pressed: closing overlay")
        m.overlayScreen.Close()
    else
        m.OrigOnKeyRelease(keyCode)
    end if
end sub

sub overlayClose()
    if m.enableBackButton = false then EnableBackButton()
    m.blocking = false

    ' reset screen OnKeyRelease to original
    m.screen.Append(m.OrigScreenFunctions)

    m.DestroyComponents()
    m.customFonts.clear()

    ' refocus on the item we initially came from
    m.screen.lastFocusedItem = invalid
    if m.fromFocusedItem <> invalid then
        m.screen.OnFocus(m.fromFocusedItem)
    else
        m.screen.screen.HideFocus(true, true)
    end if

    m.screen.overlayScreen = invalid
end sub

sub overlayShow(blocking=false as boolean)
    Application().CloseLoadingModal()
    if m.enableBackButton = false then DisableBackButton()

    m.GetComponents()

    ' dim the underlying screen
    if m.enableOverlay = false then
        dimmer = createBlock(Colors().OverlayMed)
        dimmer.SetFrame(0, 0, 1280, 720)
        dimmer.zOrder = 98
        m.components.unshift(dimmer)
    end if

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    m.screen.FocusItemManually(m.screen.focusedItem)

    m.blocking = blocking
    if m.blocking = true then
        timeout = 0
        while m.blocking = true
            timeout = Application().ProcessOneMessage(timeout)
        end while
    end if
end sub
