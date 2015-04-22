function DropDownButtonClass() as object
    if m.DropDownButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(GlyphButtonClass())
        obj.ClassName = "DropDownButton"

        ' Methods
        obj.Init = ddbuttonInit
        obj.Show = ddbuttonShow
        obj.SetDropDownPosition = ddbuttonSetDropDownPosition
        obj.GetOptions = ddbuttonGetOptions
        obj.AddCallableButton = ddbuttonAddCallableButton

        ' ddbutton overlay
        obj.CreateOverlay = ddoverlayCreateOverlay
        obj.GetComponents = ddoverlayGetComponents

        m.DropDownButtonClass = obj
    end if

    return m.DropDownButtonClass
end function

function createDropDownButton(text as string, font as object, screen as object, useIndicator=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font)

    obj.useIndicator = useIndicator

    return obj
end function

function createGlyphDropDownButton(text as string, font as object, glyphText as string, glyphFont as object, screen as object, useIndicator=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DropDownButtonClass())

    obj.screen = screen

    obj.Init(text, font, glyphText, glyphFont)

    obj.useIndicator = useIndicator

    return obj
end function

sub ddbuttonInit(text as string, font as object, glyphText=invalid as dynamic, glyphFont=invalid as dynamic)
    ApplyFunc(GlyphButtonClass().Init, m, [text, font, glyphText, glyphFont])

    m.command = "show_dropdown"

    ' options roList of AA to build components
    m.options = createObject("roList")

    m.SetDropDownPosition("down")
    m.SetIndicator(m.ALIGN_BOTTOM, m.JUSTIFY_RIGHT)
end sub

sub ddbuttonShow()
    m.overlay = m.CreateOverlay(m.screen)
    m.overlay.Show()
    m.overlay.AddListener(m.screen, "OnFailedFocus", CreateCallable("OnFailedFocus", m.overlay))
end sub

sub ddbuttonSetDropDownPosition(direction as string, dropdownSpacing=invalid as dynamic)
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

function ddbuttonGetOptions() as object
    return m.options
end function

function ddbuttonAddCallableButton(func as object, args=[] as object) as object
    callable = CreateCallable(func, invalid, invalid, args)
    option = {callableButton: callable}
    m.options.Push(option)

    return option
end function
