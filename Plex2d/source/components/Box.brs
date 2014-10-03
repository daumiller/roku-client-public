function BoxClass() as object
    if m.BoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.Append(AlignmentMixin())

        ' AlignmentMixin Methods Overrides
        obj.GetXOffsetAlignment = boxGetXOffsetAlignment
        obj.GetYOffsetAlignment = boxGetYOffsetAlignment

        obj.lastFocusableItem = invalid

        obj.AddComponent = boxAddComponent
        obj.CalculateOffsets = boxCalculateOffsets

        m.BoxClass = obj
    end if

    return m.BoxClass
end function

function boxCalculateOffsets(totalSize as integer, initialOffset as integer, sizeFn as string, alignment as integer) as object
    numChildren = m.components.Count()

    availableSize = totalSize - ((numChildren-1) * m.spacing)

    ' There are three main properties that affect how we layout our children.
    ' First, we check to see if we have homogeneous children, which means that
    ' preferred dimensions are irrelevant and we give everything the same space.
    ' Expand is similar in that it controls whether or not the children should
    ' collectively take up all of our space (homogeneous implies expand), but
    ' different in that if one component has a larger preferred size then it
    ' will end up with more space. Fill is only relevant when expand is set
    ' and controls whether the space for a particular child will be filled by
    ' the child itself or by spacing between elements to make up the difference.

    ' For all of the possible layouts, our main task is to calculate the offset
    ' of each child's starting "area". Then the available size for each child
    ' is simply the distance between offsets (less spacing). If we're filling,
    ' we'll force the size to fill the area. Otherwise we'll center the child
    ' in its area. Regardless, the real work is in calculating the offsets.

    offsets = CreateObject("roArray", numChildren + 1, false)
    offsets[0] = initialOffset

    if m.homogeneous then
        for i = 1 to numChildren
            offsets[i] = offsets[0] + (i * m.spacing) + int((i * availableSize) / numChildren)
        end for
    else
        totalPreferredSize = 0
        for each component in m.components
            totalPreferredSize = totalPreferredSize + component[sizeFn]()
        next

        if m.expand and totalPreferredSize < availableSize then
            totalExtraSpace = availableSize - totalPreferredSize
            usedExtraSpace = 0
            index = 1

            for each component in m.components
                extraSpace = int((index * totalExtraSpace) / numChildren) - usedExtraSpace
                offsets[index] = offsets[index-1] + m.spacing + extraSpace + component[sizeFn]()
                usedExtraSpace = usedExtraSpace + extraSpace
                index = index + 1
            next
        else if totalPreferredSize > availableSize then
            ' We need to shrink things to fit.
            cumulativeSize = 0
            index = 1

            for each component in m.components
                cumulativeSize = cumulativeSize + component[sizeFn]()
                offsets[index] = offsets[0] + (index * m.spacing) + int(cumulativeSize * availableSize / totalPreferredSize)
                index = index + 1
            next
        else
            ' Nothing to do, just set the offsets according to preferred size.
            index = 1

            ' If we have a different alignment then adjust the first offset accordingly.
            if alignment = 1 then
                offsets[0] = offsets[0] + int((availableSize - totalPreferredSize) / 2)
            else if alignment = 2 then
                offsets[0] = offsets[0] + availableSize - totalPreferredSize
            end if

            for each component in m.components
                offsets[index] = offsets[index-1] + m.spacing + component[sizeFn]()
                index = index + 1
            next
        end if
    end if

    return offsets
end function

sub boxAddComponent(child as object)
    ApplyFunc(ContainerClass().AddComponent, m, [child])

    if child.focusable then
        if m.lastFocusableItem <> invalid then
            child.SetFocusSibling(m.FocusDirections[0], m.lastFocusableItem)
            m.lastFocusableItem.SetFocusSibling(m.FocusDirections[1], child)
        end if

        m.lastFocusableItem = child
    end if
end sub

' AlignmentMixin for BOX Containers
function boxGetXOffsetAlignment(xOffset as integer, contWidth as integer, compWidth as integer, halign=invalid as dynamic) as integer
    if halign = invalid then return xOffset

    if halign = m.JUSTIFY_CENTER then
        xOffset = xOffset - int((compWidth - contWidth) / 2)
    else if halign = m.JUSTIFY_RIGHT then
        xOffset = xOffset + contWidth - compWidth
    end if

    return xOffset
end function

function boxGetYOffsetAlignment(yOffset as integer, contHeight as integer, compHeight as integer, valign=invalid as dynamic) as integer
    if valign = invalid then return yOffset

    if valign = m.ALIGN_MIDDLE then
        yOffset = yOffset - int((compHeight - contHeight) / 2)
    else if valign = m.ALIGN_BOTTOM then
        yOffset = yOffset + contHeight - compHeight
    end if

    return yOffset
end function
