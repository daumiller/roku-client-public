function ButtonGridClass() as object
    if m.ButtonGridClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.ClassName = "ButtonGrid"

        ' Methods
        obj.PerformLayout = buttonGridPerformLayout
        obj.GetPreferredWidth = buttonGridGetPreferredWidth
        obj.GetPreferredHeight = buttonGridGetPreferredHeight

        obj.AddButtons = buttonGridAddButtons
        obj.SetPlexObject = buttonGridSetPlexObject

        m.ButtonGridClass = obj
    end if

    return m.ButtonGridClass
end function

function createButtonGrid(rows as integer, cols as integer, buttonSize=36 as integer, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ButtonGridClass())

    obj.Init()

    obj.rows = rows
    obj.cols = cols
    obj.buttonSize = buttonSize
    obj.spacing = spacing

    return obj
end function

sub buttonGridPerformLayout()
    m.needsLayout = false

    numChildren = m.components.Count()

    if numChildren > m.rows * m.cols then
        Error("Have " + tostr(numChildren) + " buttons in a " + tostr(m.rows) + "x" + tostr(m.cols) + " grid")
        numChildren = m.rows * m.cols
    end if

    offsetSize = m.buttonSize + m.spacing

    for i = 0 to numChildren - 1
        button = m.components[i]
        row = int(i / m.rows)
        col = i mod m.cols

        button.SetFrame(m.x + col * offsetSize, m.y + row * offsetSize, m.buttonSize, m.buttonSize)

        ' TODO(schuyler): We shouldn't need to set explicit focus siblings, but
        ' if our spacing is 0 then the manual focus algorithm currently has some
        ' struggles.

        if row <> 0 then
            button.SetFocusSibling("up", m.components[i - m.cols])
            m.components[i - m.cols].SetFocusSibling("down", button)
        end if

        if col <> 0 then
            button.SetFocusSibling("left", m.components[i - 1])
            m.components[i - 1].SetFocusSibling("right", button)
        end if
    end for

    m.preferredWidth = m.GetPreferredWidth()
    m.preferredHeight = m.GetPreferredHeight()
    m.width = m.preferredWidth
    m.height = m.preferredHeight
end sub

function buttonGridGetPreferredWidth() as integer
    return m.buttonSize * m.cols + (m.cols - 1) * m.spacing
end function

function buttonGridGetPreferredHeight() as integer
    return m.buttonSize * m.rows + (m.rows - 1) * m.spacing
end function

sub buttonGridAddButtons(actions as object, buttonFields as object, screen as object, btnZOrder=invalid as dynamic)
    buttonColor = Colors().GetAlpha("Black", 30)
    if btnZOrder <> invalid then buttonFields.zOrder = btnZOrder

    for each action in actions
        if action.type = "dropDown" then
            btn = createDropDownButton(action.text, action.font, 50 * action.options.Count(), screen, false)
            btn.SetDropDownPosition(action.position)

            for each option in action.options
                option.halign = "JUSTIFY_LEFT"
                option.height = 50
                option.padding = { right: 10, left: 10, top: 0, bottom: 0}
                option.font = FontRegistry().NORMAL
                option.fields = buttonFields
                btn.options.Push(option)
            next

            if btnZOrder <> invalid then btn.zOrder = btnZOrder
        else
            btn = createButton(action.text, action.font, action.command)
            btn.Append(buttonFields)
        end if

        btn.bgColor = buttonColor
        btn.SetFocusMethod(btn.FOCUS_BACKGROUND, Colors().OrangeLight)

        m.AddComponent(btn)
    next
end sub

sub buttonGridSetPlexObject(plexObject as dynamic)
    for each comp in m.components
        if comp.options <> invalid then
            for each option in comp.options
                option.plexObject = plexObject
            next
        else
            comp.plexObject = plexObject
        end if
    next
end sub
