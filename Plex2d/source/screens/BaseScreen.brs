function BaseScreen()
    obj = m.BaseScreen

    if obj = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Standard screen properties
        obj.screen = invalid
        obj.screenName = "Unknown"

        ' Standard screen methods
        obj.Show = bsShow
        obj.Activate = bsActivate
        obj.Deactivate = bsDeactivate
        obj.Destroy = bsDestroy
        obj.HandleMessage = bsHandleMessage

        obj.reset()
        m.BaseScreen = obj
    end if

    Application().AssignScreenID(obj)

    return obj
end function

sub bsShow(screen)
    m.screen = screen
end sub

sub bsActivate(screen)
    m.screen = screen
end sub

sub bsDeactivate()
    m.screen = invalid
end sub

sub bsDestroy()
    m.Deactivate()
end sub

function bsHandleMessage(msg)
    if msg.isScreenClosed() then
        Application().PopScreen(m)
        return true
    end if

    return false
end function
