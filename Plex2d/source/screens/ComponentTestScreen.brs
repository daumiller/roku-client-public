function ComponentTestScreen() as object
    if m.ComponentTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "ComponentTest"

        obj.GetComponents = compTestGetComponents

        m.ComponentTestScreen = obj
    end if

    return m.ComponentTestScreen
end function

function createComponentTestScreen() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ComponentTestScreen())

    obj.Init()

    return obj
end function

sub compTestGetComponents()
    m.components.Clear()

    ' Let's start simple, just add a colored block at a fixed position.
    block = createBlock(Colors().PlexClr)
    block.x = 100
    block.y = 100
    block.width = 200
    block.height = 200
    m.components.Push(block)

    ' Add some labels
    lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed non luctus lorem, non vestibulum metus. Nunc ut nulla eu erat imperdiet posuere. Vivamus venenatis elementum vestibulum. Phasellus ut erat ullamcorper, fermentum mauris nec, hendrerit lacus. Suspendisse sodales dignissim leo. Etiam ornare erat ac ligula pulvinar, elementum dapibus arcu elementum. Mauris neque tellus, maximus vitae laoreet at, hendrerit rutrum turpis. Etiam vel imperdiet tortor."

    label = createLabel("Hello, world!", FontRegistry().font16)
    label.x = 310
    label.y = 100
    label.width = 200
    label.height = 200
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_CENTER
    label.valign = label.ALIGN_MIDDLE
    m.components.Push(label)

    label = createLabel(lorem, FontRegistry().font16)
    label.x = 520
    label.y = 100
    label.width = 200
    label.height = 200
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_CENTER
    label.valign = label.ALIGN_MIDDLE
    m.components.Push(label)

    label = createLabel(lorem, FontRegistry().font16)
    label.x = 730
    label.y = 100
    label.width = 200
    label.height = 200
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_RIGHT
    label.valign = label.ALIGN_BOTTOM
    label.wrap = true
    m.components.Push(label)

    label = createLabel("A", FontRegistry().font16)
    label.x = 940
    label.y = 100
    label.width = 200
    label.height = 200
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_TOP
    label.wrap = true
    m.components.Push(label)

end sub
