function HubClass() as object
    if m.HubClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.ClassName = "Hub"

        ' Constants
        obj.ORIENTATION_SQUARE = 0
        obj.ORIENTATION_PORTRAIT = 1
        obj.ORIENTATION_LANDSCAPE = 2

        ' TODO(schuyler): Kind of making these up
        obj.LAYOUT_HERO_4 = 1
        obj.LAYOUT_ART_3 = 2
        obj.LAYOUT_ART_2 = 3
        obj.LAYOUT_HERO_3 = 4

        ' Methods
        obj.PerformLayout = hubPerformLayout
        obj.MaxChildrenForLayout = hubMaxChildrenForLayout
        obj.ShowMoreButton = hubShowMoreButton
        obj.GetWidthForOrientation = hubGetWidthForOrientation
        obj.GetPreferredWidth = hubGetPreferredWidth

        m.HubClass = obj
    end if

    return m.HubClass
end function

function createHub(orientation as integer, layout as integer, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HubClass())

    obj.Init()

    obj.orientation = orientation
    obj.layout = layout
    obj.spacing = spacing
    obj.moreButton = invalid

    return obj
end function

sub hubPerformLayout()
    m.needsLayout = false
    if m.moreButton <> invalid then m.components.RemoveTail()
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    ' Figure out how much height we have available. We just need to account for
    ' our spacing and the space reserved for the more button.

    buttonHeight = 44
    contentArea = m.GetContentArea()
    availableHeight = contentArea.height - m.spacing - buttonHeight
    xOffset = m.x + contentArea.x
    yOffset = m.y + contentArea.y

    Debug("Laying out hub at (" + tostr(xOffset) + "," + tostr(yOffset) + "), available height is " + tostr(availableHeight))

    ' Generally speaking, we end up laying out some number of rows and columns.
    ' So if we need to layout a hero first, go ahead and do that now. Then we
    ' can take care of the rows and cols in a general way.

    m.components.Reset()

    lastHero = invalid

    if m.layout = m.LAYOUT_HERO_4 or m.layout = m.LAYOUT_HERO_3 then
        component = m.components.Next()

        ' TODO(schuyler): Fast forward to the future and suppose that our
        ' components are cards with artwork based on metadata items. We'll
        ' want to tweak what we request based on the orientation and size,
        ' so how does that work? Is it just a matter of creating an Image
        ' subclass that knows to tweak the URL based on the SetFrame call
        ' (which should always happen before Draw anyway)?

        heroWidth = m.GetWidthForOrientation(m.ORIENTATION_PORTRAIT, availableHeight)
        component.SetFrame(xOffset, yOffset, heroWidth, availableHeight)

        xOffset = xOffset + heroWidth + m.spacing
        Debug("Hero width was " + tostr(heroWidth) + ", xOffset is now " + tostr(xOffset))

        ' Set the focus for the more button, but not the reverse behavior.
        if m.moreButton <> invalid then
            component.SetFocusSibling("down", m.moreButton)
        end if

        if m.layout = m.LAYOUT_HERO_4 then
            rows = 2
            cols = 2
        else if m.layout = m.LAYOUT_HERO_3 then
            rows = 3
            cols = 1
        end if

        lastHero = component
    else if m.layout = m.LAYOUT_ART_2 then
        rows = 2
        cols = 1
    else if m.layout = m.LAYOUT_ART_3 then
        rows = 3
        cols = 1
    else
        Error("Unknown hub layout: " + tostr(m.layout))
        stop
    end if

    grid = CreateObject("roArray", rows * cols, false)

    ' Ok, at this point the components cursor should be pointing at the
    ' next child to render and rows and cols should both be set. We can
    ' figure out the height of each element, and then start laying them
    ' out.

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

    for rowNum = 0 to rows - 1
        for colNum = 0 to cols - 1
            component = m.components.Next()
            if component = invalid then exit for

            component.SetFrame(xOffsets[colNum], yOffsets[rowNum], itemWidth, itemHeight)

            grid[rowNum*cols + colNum] = component

            ' Set focus relationships. If there's a more button, always
            ' set the down button to there but not vice versa.
            if m.moreButton <> invalid then
                component.SetFocusSibling("down", m.moreButton)
            end if

            if rowNum > 0 then
                sibling = grid[(rowNum-1)*cols + colNum]
                component.SetFocusSibling("up", sibling)
                sibling.SetFocusSibling("down", component)
            end if

            if colNum > 0 then
                sibling = grid[rowNum*cols + colNum - 1]
                component.SetFocusSibling("left", sibling)
                sibling.SetFocusSibling("right", component)
            else if lastHero <> invalid then
                ' Set left from here to the last hero, but not vice versa.
                component.SetFocusSibling("left", lastHero)
            end if
        end for
    end for

    ' TODO(schuyler): The hub basically wants to assert its width, but right now
    ' the frame is set by whoever created the hub (or its parent container). How
    ' should it tell that what it wants its width to be?

    rightX = xOffsets[cols - 1] + itemWidth
    m.preferredWidth = rightX - m.x
    m.width = m.preferredWidth

    if m.moreButton <> invalid then
        m.moreButton.x = rightX - m.moreButton.width
        m.moreButton.y = m.y + contentArea.y + contentArea.height - m.moreButton.height
        m.components.AddTail(m.moreButton)
    end if
end sub

function hubMaxChildrenForLayout() as integer
    if m.layout = m.LAYOUT_ART_2 then
        return 2
    else if m.layout = m.LAYOUT_ART_3 then
        return 3
    else if m.layout = m.LAYOUT_HERO_4 then
        return 5
    else if m.layout = m.LAYOUT_HERO_3 then
        return 4
    end if

    Error("Unknown hub layout: " + tostr(m.layout))
    stop
end function

sub hubShowMoreButton(moreCommand as dynamic)
    m.needsLayout = true

    if m.moreButton <> invalid then
        if moreCommand = invalid then
            m.components.RemoveTail()
            m.moreButton.Destroy()
            m.moreButton = invalid
        else
            m.moreButton.command = moreCommand
        end if
    else if moreCommand <> invalid then
        m.moreButton = createButton("More", FontRegistry().font16, moreCommand)
        m.moreButton.SetColor(&hffffffff, &h1f1f1fff)
        m.moreButton.width = 72
        m.moreButton.height = 44
        m.components.AddTail(m.moreButton)
    end if
end sub

function hubGetWidthForOrientation(orientation as integer, height as integer) as integer
    if orientation = m.ORIENTATION_SQUARE then
        return height
    else if orientation = m.ORIENTATION_LANDSCAPE then
        return int(height * 1.777)
    else if orientation = m.ORIENTATION_PORTRAIT then
        return int(height * 0.679)
    else
        Error("Unknown hub orientation: " + tostr(orientation))
        stop
    end if
end function

function hubGetPreferredWidth() as integer
    if m.needsLayout then m.PerformLayout()

    return m.preferredWidth
end function
