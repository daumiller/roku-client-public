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
    'block = createBlock(Colors().PlexClr)
    'block.SetFrame(100, 100, 200, 200)
    'm.components.Push(block)

    urlImage = createImage("https://plex.tv/assets/img/pms-icon-f921d4d3a1a02c4437faa9e7fd4ba5cc.png", 200, 200)
    urlImage.SetFrame(100, 100, 200, 200)
    urlImage.SetPlaceholder("pkg:/images/plex-chevron.png")
    m.components.Push(urlImage)

    ' Add some labels
    lorem = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed non luctus lorem, non vestibulum metus. Nunc ut nulla eu erat imperdiet posuere. Vivamus venenatis elementum vestibulum. Phasellus ut erat ullamcorper, fermentum mauris nec, hendrerit lacus. Suspendisse sodales dignissim leo. Etiam ornare erat ac ligula pulvinar, elementum dapibus arcu elementum. Mauris neque tellus, maximus vitae laoreet at, hendrerit rutrum turpis. Etiam vel imperdiet tortor."

    label = createLabel("Hello, world!", FontRegistry().font16)
    label.SetFrame(310, 100, 200, 200)
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_CENTER
    label.valign = label.ALIGN_MIDDLE
    m.components.Push(label)

    label = createLabel(lorem, FontRegistry().font16)
    label.SetFrame(520, 100, 200, 200)
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_CENTER
    label.valign = label.ALIGN_MIDDLE
    m.components.Push(label)

    label = createLabel(lorem, FontRegistry().font16)
    label.SetFrame(730, 100, 200, 200)
    label.SetPadding(10)
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_RIGHT
    label.valign = label.ALIGN_BOTTOM
    label.wrap = true
    m.components.Push(label)

    label = createLabel("A", FontRegistry().font16)
    label.SetFrame(940, 100, 200, 200)
    label.bgColor = Colors().PlexClr
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_TOP
    label.wrap = true
    m.components.Push(label)

    ' Some horizontal boxes of blocks

    ' Nice and easy, homogeneous blocks that fill their area.
    hbox = createHBox(true, true, true, 10)
    hbox.SetFrame(100, 350, 1040, 40)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        ' This should be ignored since it's homogeneous and filled
        block.width = 100
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Homogeneous layout of boxes with different widths and fill not set.
    ' Each child should have the amount of space to work with, with the
    ' first few centered in that space and the last couple filling it.
    hbox = createHBox(true, true, false, 10)
    hbox.SetFrame(100, 400, 1040, 40)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 50
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Basic layout with nothing expanding or shrinking.
    hbox = createHBox(false, false, false, 10)
    hbox.SetFrame(100, 450, 1040, 7)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 50
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Same, but right justified.
    hbox = createHBox(false, false, false, 10)
    hbox.SetFrame(100, 467, 1040, 7)
    hbox.halign = hbox.JUSTIFY_RIGHT
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 50
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Same, but centered.
    hbox = createHBox(false, false, false, 10)
    hbox.SetFrame(100, 484, 1040, 7)
    hbox.halign = hbox.JUSTIFY_CENTER
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 50
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Basic layout that's too big to fit, so each child is shrunk.
    hbox = createHBox(false, false, false, 10)
    hbox.SetFrame(100, 500, 1040, 40)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 100
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Each child is expanded so that the container is filled, with each
    ' child centered in its area.
    hbox = createHBox(false, true, false, 10)
    hbox.SetFrame(100, 550, 1040, 40)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 50
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)

    ' Each child is expanded so that the container is filled, with each
    ' child filling its area.
    hbox = createHBox(false, true, true, 10)
    hbox.SetFrame(100, 600, 1040, 40)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.width = i * 50
        hbox.AddComponent(block)
    end for
    m.components.Push(hbox)
end sub
