function HubsTestScreen() as object
    if m.HubsTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.screenName = "HubsTest Screen"

        ' Methods for debugging
        obj.GetSections = function() : return []: end function
        obj.GetHubs = hubsTestGetHubs
        obj.CreateDummyHub = hubsTestCreateDummyHub
        obj.OnRewindButton = hubsTestSwitchHubLayout

        m.HubsTestScreen = obj
    end if

    return m.HubsTestScreen
end function

function createHubsTestScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HubsTestScreen())

    obj.Init()

    obj.server = server
    m.layoutStyle = 1

    return obj
end function

function hubsTestGetHubs() as object
    hubs = []

    if m.layoutStyle = 1 then
        letters = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
        for each letter in letters
            hubs.push(m.CreateDummyHub(1, 1, ucase(letter)))
        end for
    else if m.layoutStyle = 2 then
        for count = 0 to 2
            hubs.push(m.CreateDummyHub(1, 1, tostr(count) + "A"))
            hubs.push(m.CreateDummyHub(2, 2, tostr(count) + "B", false))
            hubs.push(m.CreateDummyHub(2, 4, tostr(count) + "C", false))
            hubs.push(m.CreateDummyHub(1, 3, tostr(count) + "D"))
        end for
    else
        ' lazy logic - back to defaults
        m.layoutStyle = 0
        for count = 0 to 2
            hubs.push(m.CreateDummyHub(1, 1, tostr(count) + "A"))
            hubs.push(m.CreateDummyHub(2, 2, tostr(count) + "B"))
            hubs.push(m.CreateDummyHub(2, 3, tostr(count) + "C"))
        end for
    end if

    return hubs
end function

function hubsTestCreateDummyHub(orientation as integer, layout as integer, name as string, more = true as boolean) as object
    hub = createHub("HUB " + name, orientation, layout, 10)
    hub.height = 500
    ' set the test poset url based on the orientation (square/landscape = art)
    if orientation = 1 then
        url = "http://roku.rarforge.com/images/sn-poster.jpg"
    else
        url = "http://roku.rarforge.com/images/sn-art.jpg"
    end if
    for i = 1 to hub.MaxChildrenForLayout()
        card = createCard(url, name + tostr(i))
        card.SetFocusable("card")
        if m.focusedItem = invalid then m.focusedItem = card
        hub.AddComponent(card)
    end for
    if more then hub.ShowMoreButton("more")
    return hub
end function

function hubsTestSwitchHubLayout()
    ' clear memory!
    m.Deactivate(invalid)
    ' start fresh on the components screen
    m.Init()
    ' change layout style
    m.layoutStyle = m.layoutStyle+1

    ' TODO(rob) when should we clear any cached sections/headers?
    m.ClearCache()

    ' profit
    m.show()
end function
