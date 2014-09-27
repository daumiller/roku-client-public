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
end sub
