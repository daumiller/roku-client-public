function HubClass() as object
    if m.HubClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.ClassName = "Hub"

        ' Constants
        obj.ORIENTATION_SQUARE = ComponentClass().ORIENTATION_SQUARE
        obj.ORIENTATION_PORTRAIT = ComponentClass().ORIENTATION_PORTRAIT
        obj.ORIENTATION_LANDSCAPE = ComponentClass().ORIENTATION_LANDSCAPE

        ' TODO(schuyler): Kind of making these up

        ' Hero (grid optional) start at int:0
        obj.LAYOUT_HERO_2 = 2
        obj.LAYOUT_HERO_3 = 3
        obj.LAYOUT_HERO_5 = 5

        ' Grid (no hero) start at int:10
        obj.LAYOUT_GRID_1 = 11
        obj.LAYOUT_GRID_2 = 12
        obj.LAYOUT_GRID_3 = 13
        obj.LAYOUT_GRID_4 = 14

        ' Custom layouts start at int:20
        obj.LAYOUT_LANDSCAPE_1 = 20
        obj.LAYOUT_LANDSCAPE_5 = 21

        ' Methods
        obj.PerformLayout = hubPerformLayout
        obj.MaxChildrenForLayout = hubMaxChildrenForLayout
        obj.ShowMoreButton = hubShowMoreButton
        obj.GetPreferredWidth = hubGetPreferredWidth

        obj.CalculateStyle = hubCalculateStyle

        m.HubClass = obj
    end if

    return m.HubClass
end function

' TODO(rob): layout is not calculated on the fly. Can we remove this or do we need an option
' to force layout, and even orientation?
function createHub(title as string, orientation as integer, layout as integer, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HubClass())

    obj.Init()

    ' add a label component for the hubs title
    obj.title = createLabel(ucase(title), FontRegistry().font16)
    obj.AddComponent(obj.title)

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
    '  note: the hub will always have one component due to the title
    if numChildren-1 < 1 then return

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

    ' Set the title frame above the hub. We could set the title at the specified yOffset, but
    ' that could make it harder to lineup other containers. e.g. the sections vbox. For now
    ' we'll set the title directly above the hub, minus the font height and spacing.
    title = m.components.Next()
    title.SetFrame(xOffset, yOffset-m.spacing-title.font.GetOneLineHeight(), 0, title.font.GetOneLineHeight())
    title.fixed = false

    if m.layout = m.LAYOUT_HERO_2 or m.layout = m.LAYOUT_HERO_3 or m.layout = m.LAYOUT_HERO_5 or m.layout = m.LAYOUT_LANDSCAPE_1 then
        component = m.components.Next()
        component.fixed = false

        ' TODO(schuyler): Fast forward to the future and suppose that our
        ' components are cards with artwork based on metadata items. We'll
        ' want to tweak what we request based on the orientation and size,
        ' so how does that work? Is it just a matter of creating an Image
        ' subclass that knows to tweak the URL based on the SetFrame call
        ' (which should always happen before Draw anyway)?

        ' TODO(rob): ^^ SetOrientation() implements choosing image based on
        ' the orientation.

        if m.layout = m.LAYOUT_HERO_3 and (m.ORIENTATION = m.ORIENTATION_LANDSCAPE or m.ORIENTATION = m.ORIENTATION_SQUARE) then
            availableHeight = int(availableHeight/3) * 3
            childHeight = availableHeight/3
            heroHeight = availableHeight - childHeight - m.spacing
            heroWidth = m.GetWidthForOrientation(m.orientation, heroHeight, component) + m.spacing
            availableHeight = childHeight
        else if m.layout = m.LAYOUT_LANDSCAPE_1 then
            heroHeight = availableHeight - availableHeight/3 - m.spacing
            heroWidth = m.GetWidthForOrientation(m.orientation, heroHeight, component) + m.spacing
            rows = 0
            cols = 0
        else
            heroHeight = availableHeight
            heroWidth = m.GetWidthForOrientation(m.orientation, heroHeight, component)
            ' Set the focus for the more button, but not the reverse behavior.
            if m.moreButton <> invalid then
                component.SetFocusSibling("down", m.moreButton)
            end if
            lastHero = component
        end if

        component.SetFrame(xOffset, yOffset, heroWidth, heroHeight)
        component.SetOrientation(m.orientation)

        xOffset = xOffset + heroWidth + m.spacing
        Debug("Hero width was " + tostr(heroWidth) + ", xOffset is now " + tostr(xOffset))

        if m.layout = m.LAYOUT_HERO_2 then
            rows = 1
            cols = 1
        else if m.layout = m.LAYOUT_HERO_3 then
            if m.ORIENTATION = m.ORIENTATION_LANDSCAPE or m.ORIENTATION = m.ORIENTATION_SQUARE then
                yOffset = yOffset + component.height + m.spacing
                xOffset = xOffset - component.width - m.spacing
                rows = 1
                cols = 2
            else
                rows = 2
                cols = 1
            end if
        else if m.layout = m.LAYOUT_HERO_5 then
            rows = 2
            cols = 2
        end if
    else if m.layout = m.LAYOUT_LANDSCAPE_5 then
        itemHeight = availableHeight/2 - m.spacing/2
        itemWidth = m.GetWidthForOrientation(m.orientation, itemHeight, m.components.peek())
        itemYOffset = yOffset

        Debug("Each grid item will be " + tostr(itemWidth) + "x" + tostr(itemHeight))
        for count = 0 to 1
            component = m.components.Next()
            component.fixed = false
            component.SetFrame(xOffset, itemYOffset, itemWidth, itemHeight)
            component.SetOrientation(m.orientation)
            itemYOffset = itemYOffset + itemHeight + m.spacing
        end for
        xOffset = xOffset + itemWidth + m.spacing
        rows = 3
        cols = 1
    else if m.layout = m.LAYOUT_GRID_4 then
        rows = 2
        cols = 2
    else if m.layout = m.LAYOUT_GRID_3 then
        rows = 3
        cols = 1
    else if m.layout = m.LAYOUT_GRID_2 then
        rows = 2
        cols = 1
    else if m.layout = m.LAYOUT_GRID_1 then
        rows = 1
        cols = 1
    else
        Fatal("Unknown hub layout: " + tostr(m.layout))
    end if

    if rows = 0 or cols = 0 then
        rightX = xOffset - m.spacing
    else
        grid = CreateObject("roArray", rows * cols, false)

        ' Ok, at this point the components cursor should be pointing at the
        ' next child to render and rows and cols should both be set. We can
        ' figure out the height of each element, and then start laying them
        ' out.

        itemHeight = int((availableHeight - (m.spacing * (rows - 1))) / rows)
        itemWidth = m.GetWidthForOrientation(m.orientation, itemHeight, m.components.peek())

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
                component.fixed = false

                component.SetFrame(xOffsets[colNum], yOffsets[rowNum], itemWidth, itemHeight)
                component.SetOrientation(m.orientation)

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

        rightX = xOffsets[cols - 1] + itemWidth
    end if
    ' TODO(schuyler): The hub basically wants to assert its width, but right now
    ' the frame is set by whoever created the hub (or its parent container). How
    ' should it tell that what it wants its width to be?

    m.preferredWidth = rightX - m.x
    m.width = m.preferredWidth

    ' set the title frame width (now that we have the hub width)
    title.width = m.width

    if m.moreButton <> invalid then
        m.moreButton.x = rightX - m.moreButton.width
        m.moreButton.y = m.y + contentArea.y + contentArea.height - m.moreButton.height
        ' TODO(rob) any reason we used AddTail intead of AddComponent? changed this to utilized some extra
        ' logic in AddComponent (adding the parent to the component)
        ' m.components.AddTail(m.moreButton)
        m.AddComponent(m.moreButton)
    end if
end sub

function hubMaxChildrenForLayout() as integer
    if m.maxChildren <> invalid then
        return m.maxChildren
    else
        Fatal("Unknown maxChildren for layout: " + tostr(m.layout))
    end if
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
        m.moreButton.fixed = false
        m.moreButton.setMetadata(m.container.attrs)
        m.moreButton.plexObject = m.container
        ' TODO(rob) any reason we used AddTail intead of AddComponent? changed this to utilized some extra
        ' logic in AddComponent (adding the parent to the component)
        ' m.components.AddTail(m.moreButton)
        m.AddComponent(m.moreButton)
    end if
end sub

function hubGetPreferredWidth() as integer
    if m.needsLayout then m.PerformLayout()

    return m.preferredWidth
end function

sub hubCalculateStyle(container as object)
    m.container = container
    m.hubIdentifier = container.Get("hubIdentifier")
    m.hubType = firstOf(container.Get("type"), "")

    ' Force the orientation on a few known types [default poster]
    if m.hubType = "playlist" or m.hubType = "album" or m.hubType = "artist" then
        m.orientation = m.ORIENTATION_SQUARE
    else if m.hubType = "clip" then
        m.orientation = m.ORIENTATION_LANDSCAPE
    else if m.hubType = "photo" then
        m.orientation = m.ORIENTATION_LANDSCAPE
    end if

    size = container.GetInt("size")
    if size > 5 then size = 5
    m.maxChildren = size

    if m.hubIdentifier = "home.continue" and size > 1 then
        m.orientation = m.ORIENTATION_LANDSCAPE
    end if

    if size = 1 then
        if m.orientation = m.ORIENTATION_LANDSCAPE then
            m.layout = m.LAYOUT_LANDSCAPE_1
        else
            m.layout = m.LAYOUT_GRID_1
        end if
    else if size = 2 then
        if m.orientation = m.ORIENTATION_LANDSCAPE or m.orientation = m.ORIENTATION_SQUARE then
            m.layout = m.LAYOUT_GRID_2
        else
            m.layout = m.LAYOUT_HERO_2
        end if
    else if m.hubIdentifier = "home.continue" then
        m.layout = m.LAYOUT_GRID_3
    else if size = 3 then
        m.layout = m.LAYOUT_HERO_3
        ' m.LAYOUT_HERO_3 handles landscape and portrait
    else if size = 4 then
        ' m.LAYOUT_GRID_4 handles all types
        m.layout = m.LAYOUT_GRID_4
    else if size = 5 then
        if m.orientation = m.ORIENTATION_LANDSCAPE then
            m.layout = m.LAYOUT_LANDSCAPE_5
        else if m.orientation = m.ORIENTATION_SQUARE then
            m.maxChildren = 4
            m.layout = m.LAYOUT_GRID_4
        else
            m.layout = m.LAYOUT_HERO_5
        end if
    end if
end sub
