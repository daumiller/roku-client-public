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
        obj.ToString = bsToString

        ' debugging
        obj.OnInfoButton = bsNoOp
        obj.OnRewindButton = bsNoOp

        ' no-op methods
        obj.OnPlayButton = bsNoOp
        obj.OnRevButton = bsNoOp
        obj.OnFwdButton = bsNoOp

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

sub bsNoOP(arg1=invalid as dynamic)
    ' no-op defaults
end sub

function bsToString() as string
    if type(m.screen) = "roAssociativeArray" then
        screenType = type(m.screen.screen)
    else
        screenType = type(m.screen)
    end if

    return "name="+tostr(m.screenName) + ", id=" + tostr(m.screenID) + ", type=" + screenType + ", count=" + tostr(Application().screens.Count())
end function
