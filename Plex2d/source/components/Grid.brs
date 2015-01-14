function GridClass() as object
    if m.GridClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.ClassName = "Grid"

        ' Constants
        obj.ORIENTATION_SQUARE = 0
        obj.ORIENTATION_PORTRAIT = 1
        obj.ORIENTATION_LANDSCAPE = 2

        ' Methods
        obj.PerformLayout = gridPerformLayout
        obj.GetPreferredWidth = gridGetPreferredWidth

        m.GridClass = obj
    end if

    return m.GridClass
end function

function createGrid(orientation as integer, rows as integer, spacing=0 as integer, title=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(GridClass())

    obj.Init()

    if title <> invalid then
        obj.title = createLabel(ucase(title), FontRegistry().font16)
        obj.AddComponent(obj.title)
    end if

    obj.orientation = orientation
    obj.rows = rows
    obj.spacing = spacing

    return obj
end function

sub gridPerformLayout()
    m.needsLayout = false
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    ' Figure out how much height we have available.
    contentArea = m.GetContentArea()
    availableHeight = contentArea.height
    xOffset = m.x + contentArea.x
    yOffset = m.y + contentArea.y

    Debug("Laying out grid at (" + tostr(xOffset) + "," + tostr(yOffset) + "), available height is " + tostr(availableHeight))

    m.components.Reset()
    rows = m.rows
    cols = cint(iif(m.title <> invalid, m.components.count()-1, m.components.count()) / rows)

    if m.title <> invalid then
        title = m.components.Next()
        title.SetFrame(xOffset, yOffset-m.spacing-title.font.GetOneLineHeight(), title.GetPreferredWidth(), title.font.GetOneLineHeight())
        title.fixed = false
    end if

    grid = CreateObject("roArray", rows * cols, false)

    itemHeight = int((availableHeight - (m.spacing * (rows - 1))) / rows)
    itemWidth = m.GetWidthForOrientation(m.orientation, itemHeight)

    Debug("Each grid item will be " + tostr(itemWidth) + "x" + tostr(itemHeight))

    xOffsets = CreateObject("roArray", cols, false)
    xOffsets[0] = xOffset
    for i = 1 to cols - 1
        xOffsets[i] = xOffsets[i-1] + m.spacing + itemWidth
    end for

    yOffsets = CreateObject("roArray", rows, false)
    yOffsets[0] = yOffset
    for i = 1 to rows - 2
        yOffsets[i] = yOffsets[i-1] + m.spacing + itemHeight
    end for
    yOffsets[rows - 1] = yOffset + availableHeight - itemHeight

    count = 0
    for colNum = 0 to cols - 1
        for rowNum = 0 to rows - 1
            component = m.components.Next()
            count = count + 1
            if component = invalid then exit for
            component.fixed = false

            component.SetFrame(xOffsets[colNum], yOffsets[rowNum], itemWidth, itemHeight)

            grid[rowNum*cols + colNum] = component

            ' Set focus relationships.

            if rowNum > 0 then
                sibling = grid[(rowNum-1)*cols + colNum]
                component.SetFocusSibling("up", sibling)
                sibling.SetFocusSibling("down", component)
            end if

            if colNum > 0 then
                sibling = grid[rowNum*cols + colNum - 1]
                component.SetFocusSibling("left", sibling)
                sibling.SetFocusSibling("right", component)
            end if
        end for
    end for

    ' TODO(schuyler): The grid basically wants to assert its width, but right now
    ' the frame is set by whoever created the grid (or its parent container). How
    ' should it tell that what it wants its width to be?

    rightX = xOffsets[cols - 1] + itemWidth
    m.preferredWidth = rightX - m.x
    m.width = m.preferredWidth
end sub

function gridGetPreferredWidth() as integer
    if m.needsLayout then m.PerformLayout()

    return m.preferredWidth
end function
