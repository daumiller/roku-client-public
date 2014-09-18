function HomeTestScreen() as object
    if m.HomeTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "HomeTest Screen"

        obj.GetComponents = homeTestGetComponents

        m.HomeTestScreen = obj
    end if

    return m.HomeTestScreen
end function

function createHomeTestScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HomeTestScreen())

    obj.server = server

    obj.Init()

    return obj
end function

sub homeTestGetComponents()
    m.components.Clear()
    m.focusedItem = invalid

    hub = createHub(1, 1, 10)
    hub.SetFrame(100, 100, 1280, 500)
    for i = 1 to 5
        block = createBlock(Colors().PlexClr)
        block.SetFocusable("test")
        if m.focusedItem = invalid then m.focusedItem = block
        hub.AddComponent(block)
    end for
    hub.ShowMoreButton("more")
    m.components.Push(hub)
    ' m.components.Clear()

    ' ' dummy section data
    ' sectionData = []
    ' for count = 0 to 5
    '     sectionData.push({name: "section " + tostr(count), focus: (count = 0), command: "TBD"})
    ' end for
    ' ' dummy hub data
    ' dummyHub = {items: []}
    ' for count = 0 to 5
    '     dummyHub.items.push({
    '         poster: "http://roku.rarforge.com/images/sn-poster.jpg",
    '         art: "https://roku.rarforge.com/images/sn-art.jpg",
    '     })
    ' end for

    ' ' mainBox: This will get intersting. I am not sure how we want to handle it.
    ' ' Total hubs and hubs width dynamic, so we'll need to be able to add all the
    ' ' components, without resizing, and ignore rendering off screen components.
    ' mainBox = createHBox(false, false, false, 30)
    ' mainBox.SetFrame(50, 125, 1280*2, 720-125)

    ' ' HBox: sections container (buttons)
    ' sections = createVBox(false, false, false, 10)
    ' sections.halign = sections.JUSTIFY_RIGHT
    ' for each section in sectionData
    '     button = createButton(section.name, FontRegistry().font16, section.command)
    '     button.SetColor(&hffffffff, &h1f1f1fff)
    '     button.width = 128
    '     button.height = 72
    '     if section.focus then m.focusedItem = button
    '     sections.AddComponent(button)
    ' end for
    ' mainBox.AddComponent(sections)

    ' ' HBox: hubs container
    ' hubs = createHBox(false, false, false, 30)

    ' ' hub1
    ' dummyHub.htype = 2
    ' hub = createHub(dummyHub, 10)
    ' hubs.AddComponent(hub)

    ' ' hub2
    ' dummyHub.htype = 1
    ' hub = createHub(dummyHub, 10)
    ' hubs.AddComponent(hub)

    ' ' hub3
    ' dummyHub.htype = 3
    ' hub = createHub(dummyHub, 10)
    ' hubs.AddComponent(hub)

    ' ' add the hubs to the mainBox
    ' mainBox.AddComponent(hubs)

    ' m.components.Push(mainBox)
end sub
