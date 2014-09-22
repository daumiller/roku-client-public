function HomeTestScreen() as object
    if m.HomeTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "HomeTest Screen"

        obj.GetComponents = homeTestGetComponents

        ' debug - switch hub layout styles
        obj.CreateHubs = homeTestCreateHubs
        obj.CreateHub = homeTestCreateHub
        obj.HandleRewind = homeTestHandleRewind

        m.HomeTestScreen = obj
    end if

    return m.HomeTestScreen
end function

function createHomeTestScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HomeTestScreen())

    obj.server = server

    obj.layoutStyle = 0

    obj.Init()

    return obj
end function

sub homeTestGetComponents()
    m.components.Clear()
    m.focusedItem = invalid

    ' TODO(rob) make pretty - testing just to see interaction with buttons
    headBkg = createBlock(&h000000e0)
    headBkg.SetFrame(0, 0, 1280, 72)
    m.components.Push(headBkg)

    headLogo = createImage("pkg:/images/plex_logo_HD_62x20.png", 62, 20)
    headLogo.SetFrame(100, 35, 62, 20)
    m.components.Push(headLogo)

    hbHeadButtons = createHBox(false, false, false, 25)
    hbHeadButtons.SetFrame(900, 35, 1280, 25)

    but1 = createButton("server", FontRegistry().font16, "server_selection")
    but1.width = 128
    hbHeadButtons.AddComponent(but1)

    but2 = createButton("options", FontRegistry().font16, "server_selection")
    but2.width = 128
    hbHeadButtons.AddComponent(but2)

    m.components.Push(hbHeadButtons)

    hubs = m.CreateHubs()
    m.components.Push(hubs)

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

function homeTestHandleRewind()
    ' clear memory!
    m.Deactivate(invalid)
    ' start fresh on the components screen
    m.Init()
    ' change layout style
    m.layoutStyle = m.layoutStyle+1
    ' profit
    m.show()
end function

function homeTestCreateHub(orientation as integer, layout as integer, name as string, more = true as boolean) as object
    hub = createHub(orientation, layout, 10)
    hub.height = 500
    for i = 1 to hub.MaxChildrenForLayout()
        label = createLabel(name + tostr(i), FontRegistry().font16)
        label.bgColor = Colors().CardBkgClr
        label.halign = label.JUSTIFY_CENTER
        label.valign = label.ALIGN_MIDDLE
        label.SetFocusable("test")
        if m.focusedItem = invalid then m.focusedItem = label
        hub.AddComponent(label)
    end for
    if more then hub.ShowMoreButton("more")
    return hub
end function

function homeTestCreateHubs() as object
    hbox = createHBox(false, false, false, 25)
    hbox.SetFrame(100, 100, 2000*10, 500)

    if m.layoutStyle = 1 then
        hbox.AddComponent(m.CreateHub(1, 1, "A"))
        hbox.AddComponent(m.CreateHub(1, 1, "B"))
        hbox.AddComponent(m.CreateHub(1, 1, "C"))
        hbox.AddComponent(m.CreateHub(1, 1, "D"))
        hbox.AddComponent(m.CreateHub(1, 1, "E"))
        hbox.AddComponent(m.CreateHub(1, 1, "F"))
    else if m.layoutStyle = 2 then
        hbox.AddComponent(m.CreateHub(1, 1, "A"))
        hbox.AddComponent(m.CreateHub(2, 2, "B", false))
        hbox.AddComponent(m.CreateHub(1, 3, "C"))
    else
        ' lazy logic - back to defaults
        m.layoutStyle = 0
        hbox.AddComponent(m.CreateHub(1, 1, "A"))
        hbox.AddComponent(m.CreateHub(2, 2, "B"))
        hbox.AddComponent(m.CreateHub(1, 3, "C"))
    end if

    print m.layoutStyle

    return hbox
end function
