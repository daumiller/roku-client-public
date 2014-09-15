function HBoxClass() as object
    if m.HBoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoxClass())
        obj.ClassName = "HBox"

        ' Methods
        obj.PerformLayout = hboxPerformLayout

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

    availableWidth = m.width - ((numChildren-1) * m.spacing)

    ' There are three main properties that affect how we layout our children.
    ' First, we check to see if we have homogeneous children, which means that
    ' preferred dimensions are irrelevant and we give everything the same space.
    ' Expand is similar in that it controls whether or not the children should
    ' collectively take up all of our space (homogeneous implies expand), but
    ' different in that if one component has a larger preferred width then it
    ' will end up with more space. Fill is only relevant when expand is set
    ' and controls whether the space for a particular child will be filled by
    ' the child itself or by spacing between elements to make up the difference.

    ' For all of the possible layouts, our main task is to calculate the offset
    ' of each child's starting "area". Then the available width for each child
    ' is simply the distance between offsets (less spacing). If we're filling,
    ' we'll force the width to fill the area. Otherwise we'll center the child
    ' in its area. Regardless, the real work is in calculating the offsets.

    offsets = CreateObject("roArray", numChildren + 1, false)
    offsets[0] = m.x

    if m.homogeneous then
        for i = 1 to numChildren
            offsets[i] = offsets[0] + (i * m.spacing) + int((i * availableWidth) / numChildren)
        end for
    else
        totalPreferredWidth = 0
        for each component in m.components
            totalPreferredWidth = totalPreferredWidth + component.GetPreferredWidth()
        next

        if m.expand and totalPreferredWidth < availableWidth then
            totalExtraSpace = availableWidth - totalPreferredWidth
            usedExtraSpace = 0
            index = 1

            for each component in m.components
                extraSpace = int((index * totalExtraSpace) / numChildren) - usedExtraSpace
                offsets[index] = offsets[index-1] + m.spacing + extraSpace + component.GetPreferredWidth()
                usedExtraSpace = usedExtraSpace + extraSpace
                index = index + 1
            next
        else if totalPreferredWidth > availableWidth then
            ' We need to shrink things to fit.
            cumulativeWidth = 0
            index = 1

            for each component in m.components
                cumulativeWidth = cumulativeWidth + component.GetPreferredWidth()
                offsets[index] = offsets[0] + (index * m.spacing) + int(cumulativeWidth * availableWidth / totalPreferredWidth)
                index = index + 1
            next
        else
            ' Nothing to do, just set the offsets according to preferred width.
            index = 1

            ' If we have a different alignment then adjust the first offset accordingly.
            if m.halign = m.JUSTIFY_CENTER then
                offsets[0] = offsets[0] + int((availableWidth - totalPreferredWidth) / 2)
            else if m.halign = m.JUSTIFY_RIGHT then
                offsets[0] = offsets[0] + availableWidth - totalPreferredWidth
            end if

            for each component in m.components
                offsets[index] = offsets[index-1] + m.spacing + component.GetPreferredWidth()
                index = index + 1
            next
        end if
    end if

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
