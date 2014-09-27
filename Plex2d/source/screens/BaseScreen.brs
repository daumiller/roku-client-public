function BaseScreen()
    if m.BaseScreen = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Standard screen properties
        obj.screen = invalid
        obj.screenName = "Unknown"

        ' Standard screen methods
        obj.Init = bsInit
        obj.Show = bsShow
        obj.Activate = bsActivate
        obj.Deactivate = bsDeactivate
        obj.Destroy = bsDestroy
        obj.HandleMessage = bsHandleMessage

        obj.reset()
        m.BaseScreen = obj
    end if

    return m.BaseScreen
end function

sub bsInit()
    Application().AssignScreenID(m)
end sub

sub bsShow()
    ' m.screen = screen
end sub

sub bsActivate()
    ' m.screen = screen
end sub

sub bsDeactivate()
    ' m.screen = invalid
end sub

sub bsDestroy()
    m.Deactivate()
end sub

function bsHandleMessage(msg)
    if msg <> invalid and type(msg) <> "roUniversalControlEvent" then
        if msg.isScreenClosed() then
            Application().PopScreen(m)
            return true
        end if
    end if

    return false
end function
