function SectionsScreen() as object
    if m.SectionsScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = sectionsShow

        obj.GetButtons = sectionsGetButtons
        obj.CreateButton = sectionsCreateButton

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
    obj.server = item.GetServer()

    ' override home movie section type as clip
    if item.IsPersonalLibrarySection() and item.Get("type", "") = "movie" then
        obj.contentType = "clip"
    else
        obj.contentType = item.Get("type")
    end if

    return obj
end function

sub sectionsShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.buttonsContainer.request = invalid then
        request = createPlexRequest(m.server, m.item.GetAbsolutePath("key"))
        context = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.buttonsContainer = context
    end if

    ' hub requests
    if m.hubsContainer.request = invalid then
        request = createPlexRequest(m.server, "/hubs/sections/" + m.item.Get("key"))
        context = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, context)
        m.hubsContainer = context
    end if

    if m.hubsContainer.response <> invalid and m.buttonsContainer.response <> invalid then
        ' switch into browse mode if the section hubs are empty. By default out first
        ' button on the section screen is the browse by all
        if m.hubsContainer.items.Count() = 0 then
            browseItem = m.GetButtons()[0]
            if browseItem <> invalid and browseItem.plexObject <> invalid then
                Debug("Section Hub are empty, switching to browse mode")
                Application().PopScreen(m, false)
                Application().PushScreen(createGridScreen(browseItem.plexObject))
                return
            end if
        end if
        ApplyFunc(ComponentsScreen().Show, m)
    else
        Debug("HubsShow:: waiting for all requests to be completed")
    end if
end sub

function sectionsCreateButton(container as object) as object
    button = createButton(container.GetSingleLineTitle(), FontRegistry().font16, "show_grid")
    button.setMetadata(container.attrs)
    button.plexObject = container
    button.width = 200
    button.height = 66
    button.fixed = false
    button.setColor(Colors().Text, Colors().Button)
    return button
end function

function sectionsGetButtons() as object
    buttons = []
    for each container in m.buttonsContainer.items
        if container.Get("key") = "all" then
            container.attrs.type = firstOf(container.Get("type"), m.contentType)
            buttons.push(m.createButton(container))
        end if
    end for

    return buttons
end function
