function JumpBoxClass() as object
    if m.JumpBoxClass = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(HBoxClass())
        obj.ClassName = "JumpBox"

        ' Methods
        obj.OnFocusIn = jumpboxOnFocusIn
        obj.PerformLayout = jumpboxPerformLayout

        m.JumpBoxClass = obj
    end if

    return m.JumpBoxClass
end function

function createJumpBox(jumpItems as object, font as object, yOffset as integer, spacing as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(JumpBoxClass())

    obj.Init()

    obj.jumpItems = jumpItems
    obj.yOffset = yOffset
    obj.isFocused = false
    obj.spacing = spacing
    obj.font = font

    obj.fgColor = &h333333ff
    obj.fgColorActive = Colors().Text
    obj.fgColorFocus = &h000000ff
    obj.bgColorFocus = &h333333ff

    ' standard (unused) hbox variables
    obj.homogeneous = false
    obj.expand = false
    obj.fill = false

    return obj
end function

sub jumpboxPerformLayout()
    m.needsLayout = false

    btnHeight = m.font.getOneLineHeight()
    jumpWidth = 0
    for each jump in m.jumpItems
        button = createButton(jump.title, m.font, "jump_button")
        button.SetColor(m.fgColor)
        button.width = btnHeight
        button.height = btnHeight
        button.SetMetadata(jump)
        ' methods specific for the jumpBox Buttons
        button.GetFocusManual = jbbGetFocusManual
        button.OnBlur = jbbOnBlur
        button.OnFocus = jbbOnFocus
        button.isJumpItem = true

        m.AddComponent(button)
        jumpWidth = jumpWidth + button.width + m.spacing
    end for

    ' wrap the jumpBox
    if m.components.count() > 1 then
        first = m.components[0]
        last = m.components.peek()
        first.SetFocusSibling("left", last)
        last.SetFocusSibling("right", first)
    end if

    xOffset = int(1280/2 - jumpWidth/2)
    m.SetFrame(xOffset, m.yOffset, jumpWidth, 50)

    ApplyFunc(HBoxClass().PerformLayout, m)
end sub

' highlight and set the desired focusItem in the jumpBox
sub jumpboxOnFocusIn(item as object)
    if item.isJumpItem = true then return

    if item.jumpIndex <> invalid and m.components.count() > 0 then
        focus = invalid
        for index = 0 to m.components.count() - 1
            jump = m.components[index].metadata
            if item.jumpIndex >= jump.index and item.jumpIndex < jump.index + jump.size then
                focus = m.components[index]
                exit for
            end if
        end for

        if focus <> invalid and (m.focusedItem = invalid or NOT m.focusedItem.Equals(focus)) then
            if m.focusedItem <> invalid then
                m.focusedItem.SetColor(m.fgColor)
                m.focusedItem.draw(true)
            end if
            m.focusedItem = focus
            m.focusedItem.SetColor(m.fgColorFocus, m.bgColorFocus)
            m.focusedItem.draw(true)
            CompositorScreen().DrawAll()
        end if
    end if
end sub

sub jbbOnBlur(toFocus as object)
    ' ignore focus if we stay contained in the jump box, or parent is unfocused
    if toFocus.isJumpItem = true or m.parent.isFocused = false then return

    ' redraw the components (dim letters)
    m.parent.isFocused = false
    for each comp in m.parent.components
        if not comp.Equals(m.parent.focusedItem) then
            comp.SetColor(m.parent.fgColor)
            comp.draw(true)
        end if
    end for
end sub

sub jbbOnFocus()
    ' ignore redraw if parent has focus
    if m.parent.isFocused = true then return

    ' redraw the components (dim letters)
    m.parent.isFocused = true
    for each comp in m.parent.components
        if not comp.Equals(m.parent.focusedItem) then
            comp.SetColor(m.parent.fgColorActive, comp.bgColor)
            comp.draw(true)
        end if
    end for
end sub

function jbbGetFocusManual(direction as string, screen as object) as dynamic
    return m.parent.focusedItem
end function
