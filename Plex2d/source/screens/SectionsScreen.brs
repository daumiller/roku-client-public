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
    if m.buttonsContext.request = invalid then
        request = createPlexRequest(m.server, m.item.GetAbsolutePath("key"))
        m.buttonsContext = request.CreateRequestContext("sections", createCallable("OnResponse", m))
        Application().StartRequest(request, m.buttonsContext)
    end if

    ' hub requests
    if m.hubsContext.request = invalid then
        request = createPlexRequest(m.server, "/hubs/sections/" + m.item.Get("key"))
        m.hubsContext = request.CreateRequestContext("hubs", createCallable("OnResponse", m))
        Application().StartRequest(request, m.hubsContext)
    end if

    if m.hubsContext.response <> invalid and m.buttonsContext.response <> invalid then
        ' switch into browse mode if the section hubs are empty. By default out first
        ' button on the section screen is the browse by all
        if m.hubsContext.items.Count() = 0 then
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
    button = createButton(container.GetSingleLineTitle(), FontRegistry().LARGE, "show_grid")
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

    ' We could very easily allow any keys here. For example, we could
    ' whitelist certain keys, or allow everything that isn't secondary.
    ' We could allow By Folder. But for now, we're just allowing all and
    ' unwatched. We'll reevaluate as we sort out filtering and browsing.
    '
    allowedKeys = {all: 1, unwatched: 1}

    for each item in m.buttonsContext.items
        if allowedKeys.DoesExist(item.Get("key", "")) then
            item.Set("type", firstOf(item.Get("type"), m.contentType, ""))

            ' Convert the unwatched endpoint to a filtered endpoint. We'll
            ' probably need to do this for any keys we may include.
            if item.Get("key") = "unwatched" then
                if item.Get("type", "") = "show" then
                    key = "all?type=2&unwatchedLeaves=1"
                else
                    key = "all?unwatched=1"
                end if
                item.Set("key", key)
            end if

            buttons.push(m.createButton(item))
        end if
    end for

    return buttons
end function
