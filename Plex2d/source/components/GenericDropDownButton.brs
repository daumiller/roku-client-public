function GenericDropDownButtonClass() as object
    if m.GenericDropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "GenericDropDownButton"

        ' Methods
        obj.Init = gddbInit
        obj.Show = gddbShow
        obj.SetDropDownPosition = gddbSetDropDownPosition
        obj.GetOptions = gddbGetOptions
        obj.AddCallableButton = gddbAddCallableButton

        ' Overlay methods
        obj.CreateOverlay = ddoverlayCreateOverlay
        obj.GetComponents = ddoverlayGetComponents

        m.GenericDropDownButtonClass = obj
    end if

    return m.GenericDropDownButtonClass
end function

sub gddbInit()
    m.command = "show_dropdown"

    ' options roList of AA to build components
    m.options = createObject("roList")

    m.SetDropDownPosition("down")
    m.SetIndicator(m.ALIGN_BOTTOM, m.JUSTIFY_RIGHT)
end sub

sub gddbShow()
    m.overlay = m.CreateOverlay(m.screen)
    m.overlay.Show()
    m.overlay.AddListener(m.screen, "OnFailedFocus", CreateCallable("OnFailedFocus", m.overlay))
end sub

sub gddbSetDropDownPosition(direction as string, dropdownSpacing=invalid as dynamic)
    ' Supported: bottom, right and left. "up" is used dynamically
    ' (for now) when we reset the position to fit on the screen.

    ' Support to prefer a direction, but use the opposite based
    ' on available space. We can extend this later to up/down.
    '
    if direction = "rightLeft" then
        direction = "right"
        m.dropDownDynamicPosition = true
    else if direction = "leftRight" then
        direction = "left"
        m.dropDownDynamicPosition = true
    end if

    m.dropDownPosition = direction
    m.scrollbarPosition = iif(direction = "left", direction, "right")
    if dropdownSpacing <> invalid then
        m.dropdownSpacing = dropdownSpacing
    end if
end sub

function gddbGetOptions() as object
    return m.options
end function

function gddbAddCallableButton(func as object, args=[] as object) as object
    callable = CreateCallable(func, invalid, invalid, args)
    option = {callableButton: callable}
    m.options.Push(option)

    return option
end function
