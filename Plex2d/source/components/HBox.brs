function HBoxClass() as object
    if m.HBoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoxClass())
        obj.ClassName = "HBox"

        ' Methods
        obj.PerformLayout = hboxPerformLayout
        obj.GetPreferredWidth = hboxGetPreferredWidth
        obj.GetPreferredHeight = hboxGetPreferredHeight

        m.HBoxClass = obj
    end if

    return m.HBoxClass
end function

function createHBox(homogeneous as boolean, expand as boolean, fill as boolean, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HBoxClass())

    obj.Init()

    obj.homogeneous = homogeneous
    obj.expand = expand
    obj.fill = fill
    obj.spacing = spacing

    return obj
end function

sub hboxPerformLayout()
    m.needsLayout = false
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    offsets = m.CalculateOffsets(m.width, m.x, "GetPreferredWidth", m.halign)

    ' Now that we have all the offsets, setting each child's frame is simple.

    offsets.Reset()
    m.components.Reset()
    nextOffset = offsets.Next()

    while offsets.IsNext() and m.components.IsNext()
        offset = nextOffset
        nextOffset = offsets.Next()
        component = m.components.Next()
        maxWidth = nextOffset - offset - m.spacing

        if m.fill then
            width = maxWidth
        else
            width = component.GetPreferredWidth()
            if width > maxWidth then width = maxWidth
            offset = offset + int((maxWidth - width) / 2)
        end if

        component.SetFrame(offset, m.y, width, m.height)
    end while
end sub

function hboxGetPreferredWidth() as integer
    if m.width <> 0 then return m.width

    totalWidth = m.spacing * (m.components.Count() - 1)
    for each component in m.components
        totalWidth = totalWidth + component.GetPreferredWidth()
    next
    return totalWidth
end function

function hboxGetPreferredHeight() as integer
    maxHeight = 0
    for each component in m.components
        height = component.GetPreferredHeight()
        if height > maxHeight then maxHeight = height
    next
    return maxHeight
end function
