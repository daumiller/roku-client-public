function VBoxClass() as object
    if m.VBoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoxClass())
        obj.ClassName = "VBox"

        obj.FocusDirections = ["up", "down"]

        ' Methods
        obj.PerformLayout = vboxPerformLayout
        obj.GetPreferredWidth = vboxGetPreferredWidth
        obj.GetPreferredHeight = vboxGetPreferredHeight
        obj.AddSpacer = vboxAddSpacer

        m.VBoxClass = obj
    end if

    return m.VBoxClass
end function

function createVBox(homogeneous as boolean, expand as boolean, fill as boolean, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(VBoxClass())

    obj.Init()

    obj.homogeneous = homogeneous
    obj.expand = expand
    obj.fill = fill
    obj.spacing = spacing

    return obj
end function

sub vboxAddSpacer(delta as integer)
    m.AddComponent(createSpacer(0, delta))
end sub

sub vboxPerformLayout()
    m.needsLayout = false
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    offsets = m.CalculateOffsets(m.height, m.y, "GetPreferredHeight", m.valign)

    ' Now that we have all the offsets, setting each child's frame is simple.

    offsets.Reset()
    m.components.Reset()
    nextOffset = offsets.Next()

    while offsets.IsNext() and m.components.IsNext()
        offset = nextOffset
        nextOffset = offsets.Next()
        component = m.components.Next()
        maxHeight = nextOffset - offset - m.spacing

        if m.fill then
            height = maxHeight
            width = m.width
        else
            height = component.GetPreferredHeight()
            if height > maxHeight then height = maxHeight
            offset = offset + int((maxHeight - height) / 2)

            width = component.GetPreferredWidth()
            if width = 0 or width > m.width then width = m.width
        end if

        xOffset = m.GetXOffsetAlignment(m.x, m.width, width, firstOf(component.phalign, component.halign))
        component.SetFrame(xOffset, offset, width, height)
    end while
end sub

function vboxGetPreferredWidth() as integer
    maxWidth = 0
    for each component in m.components
        width = component.GetPreferredWidth()
        if width > maxWidth then maxWidth = width
    next
    return maxWidth
end function

function vboxGetPreferredHeight() as integer
    totalHeight = m.spacing * (m.components.Count() - 1)
    for each component in m.components
        totalHeight = totalHeight + component.GetPreferredHeight()
    next
    return totalHeight
end function
