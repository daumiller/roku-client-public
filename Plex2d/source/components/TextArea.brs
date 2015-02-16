function TextAreaClass() as object
    if m.TextAreaClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(AlignmentMixin())
        obj.Append(VBoxClass())
        obj.ClassName = "TextArea"

        ' Methods
        obj.Init = textareaInit
        obj.SetFrame = textareaSetFrame
        obj.PerformLayout = textareaPerformLayout
        obj.SetVisible = textareaSetVisible
        obj.SetPadding = textareaSetPadding
        obj.SetColor = textareaSetColor

        m.TextAreaClass = obj
    end if

    return m.TextAreaClass
end function

function createTextArea(text as string, font as object, spacing=0 as integer, scrollPos="right" as string) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(TextAreaClass())

    obj.Init()

    obj.text = text
    obj.font = font
    obj.spacing = spacing

    obj.SetScrollable(obj.font.GetOneLineHeight(), false, false, scrollPos)

    return obj
end function

sub textareaSetFrame(x as integer, y as integer, width as integer, height as integer)
    ApplyFunc(VBoxClass().SetFrame, m, [x, y, width, height])
    m.origY = y
    m.origHeight = height
end sub

sub textareaInit()
    ApplyFunc(VBoxClass().Init, m)

    ' Default VBox methods
    m.homogeneous = false
    m.expand = false
    m.fill = false

   ' Override default colors
    m.fgColor = invalid
    m.bgColor = invalid
    m.bgColorFocus = invalid

    ' Default shifting rules
    m.stopShiftIfInView = true
    m.fixedHorizontal = true

    ' Text padding
    m.textPadding = {
        marginBottom: 0,
        marginTop: 0,
        width: 0,
    }
end sub

sub textareaPerformLayout()
    m.DestroyComponents()
    zOrder = iif(m.zOrder <> invalid and m.zOrder > 1, m.zOrder, 2)

    ' Reset the yOffset and Height based on the padding prefs (margins)
    m.y = m.origY + m.textPadding.marginTop
    m.height = m.origHeight - m.textPadding.marginBottom

    for each line in createLabel(m.text, m.font).GetAllLines(m.width - m.textPadding.width)
        label = createLabel(line, m.font)
        label.width = m.width
        label.halign = m.halign
        label.fixed = false
        label.fixedHorizontal = (m.fixedHorizontal = true)
        label.focusBorder = false
        label.zOrder = zOrder
        label.zOrderInit = m.zOrderInit

        label.SetFocusable(invalid, true)
        label.SetPadding(0, m.textPadding.right, 0, m.textPadding.left)
        if m.fgColor <> invalid then
            label.SetColor(m.fgColor)
        end if

        ' Methods to focus the text area. Always focus the first item,
        ' and maintain current focus of the text area ongoing.
        label.GetFocusManual = textareaGetFocusManual
        label.OnFocus = textareaOnFocus
        label.OnBlur = textareaOnBlur
        label.isTextArea = true
        if m.firstFocusItem = invalid then m.firstFocusItem = label

        m.AddComponent(label)
    end for

    ' Perform a VBox layout when we have all of our components
    ApplyFunc(VBoxClass().PerformLayout, m)

    ' Add a background component if we a bgColor
    if m.bgColor <> invalid then
        m.background = createBlock(m.bgColor)
        m.background.SetFrame(m.x, m.y - m.textPadding.marginTop, m.width, m.height + m.textPadding.marginBottom)
        m.background.zOrder = zOrder - 1
        m.background.zOrderInit = m.zOrderInit

        ' allow the background to shift horizontally if applicable
        m.background.fixed = false
        m.background.fixedHorizontal = (m.fixedHorizontal = true)
        m.background.fixedVertical = true

        m.components.Unshift(m.background)
    end if

    if m.components.Count() <= 1 then return

    ' Update which lines are focusable. This will stop scrolling
    ' when the final components are all inve view
    lastScrollInView = m.containerHeight - m.contentHeight + m.y

    m.components.Reset()
    while m.components.IsNext()
        component = m.components.Next()
        if m.containerHeight <= m.contentHeight or component.origY >= lastScrollInView + component.height then
            component.SetFocusable(invalid, false)
        end if
    end while
end sub

sub textareaSetPadding(pTop as integer, pRight=invalid as dynamic, pBottom=invalid as dynamic, pLeft=invalid as dynamic)
    pad = m.textPadding

    ApplyFunc(PaddingMixin().SetPadding, pad, [pTop, pRight, pBottom, pLeft])

    pad.left = pad.padding.left
    pad.right = pad.padding.right
    pad.width = pad.left + pad.right

    if pad.padding.top > 0 then
        pad.marginTop =  pad.padding.top
        pad.marginBottom =  pad.padding.top
    end if

    if pad.padding.bottom > 0 then
        pad.marginBottom = pad.marginBottom + pad.padding.bottom
    end if
end sub

sub textareaSetVisible(visible=true as boolean)
    ApplyFunc(VBoxClass().SetVisible, m, [visible])

    ' Due to padding, the background may be outside the visible constraints, so
    ' we'll set it visiable regardless.
    if m.background <> invalid then m.background.SetVisible(visible)

    if m.visible = visible then return
    m.visible = visible

    ' Toggle focus based on visibility
    m.components.Reset()
    while m.components.IsNext()
        component = m.components.Next()
        component.ToggleFocusable(visible)
    end while
end sub

function textareaGetFocusManual() as dynamic
    return m.parent.firstFocusItem
end function

sub textareaOnFocus()
    m.parent.firstFocusItem = m

    if m.parent.isFocused = true then return
    m.parent.isFocused = true

    if m.parent.background <> invalid then
        m.parent.background.bgColor = firstOf(m.parent.bgColorFocus, m.parent.bgColor)
        m.parent.background.Draw()
        m.parent.background.SetVisible(true)
    end if
end sub

sub textareaOnBlur(toFocus as object)
    if toFocus.isTextArea = true then return

    if m.parent.isFocused = false then return
    m.parent.isFocused = false

    if m.parent.background <> invalid then
        m.parent.background.bgColor = m.parent.bgColor
        m.parent.background.Draw()
    end if
end sub

sub textareaSetColor(fgColor as integer, bgColor=invalid as dynamic, bgColorFocus=invalid)
    m.fgColor = fgColor
    m.bgColor = bgColor
    m.bgColorFocus = bgColorFocus
end sub
