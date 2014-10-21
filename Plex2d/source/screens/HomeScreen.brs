function HomeScreen() as object
    if m.HomeScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = homeShow
        obj.AfterItemFocused = homeAfterItemFocused

        obj.screenName = "Home Screen"

        m.HomeScreen = obj
    end if

    return m.HomeScreen
end function

function createHomeScreen(server as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HomeScreen())

    obj.Init()

    obj.server = server

    return obj
end function

sub homeShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.buttonsContainer.request = invalid then
        request = createPlexRequest(m.server, "/library/sections")
        context = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.buttonsContainer = context
    end if

    ' hub requests
    if m.hubsContainer.request = invalid then
        request = createPlexRequest(m.server, "/hubs")
        context = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.hubsContainer = context
    end if

    if m.hubsContainer.response <> invalid and m.buttonsContainer.response <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)
    else
        Debug("HubsShow:: waiting for all requests to be completed")
    end if
end sub

sub homeAfterItemFocused(item as object)
    pendingDraw = m.DescriptionBox.Show(item)
    if pendingDraw then m.screen.DrawAll()
end sub
