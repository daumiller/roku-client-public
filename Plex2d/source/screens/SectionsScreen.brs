function SectionsScreen() as object
    if m.SectionsScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = sectionsShow
        obj.AfterItemFocused = sectionsAfterItemFocused

        obj.screenName = "Sections Screen"

        m.SectionsScreen = obj
    end if

    return m.SectionsScreen
end function

function createSectionsScreen(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SectionsScreen())

    obj.Init()

    obj.item = item
    obj.server = item.container.server

    return obj
end function

sub sectionsShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.sectionsContainer.request = invalid then
        request = createPlexRequest(m.server, "/library/sections/" + m.item.Get("key") )
        context = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.sectionsContainer = context
    end if

    ' hub requests
    if m.hubsContainer.request = invalid then
        request = createPlexRequest(m.server, "/hubs/sections/" + m.item.Get("key"))
        context = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.hubsContainer = context
    end if

    if m.hubsContainer.response <> invalid and m.sectionsContainer.response <> invalid then
        ApplyFunc(ComponentsScreen().Show, m)
    else
        Debug("HubsShow:: waiting for all requests to be completed")
    end if
end sub

sub sectionsAfterItemFocused(item as object)
    if item.plexObject = invalid or item.plexObject.isDirectory() then
        pendingDraw = m.DescriptionBox().Hide()
    else
        pendingDraw = m.DescriptionBox().Show(item)
    end if

    if pendingDraw then m.screen.DrawAll()
end sub
