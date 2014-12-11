function SectionsScreen() as object
    if m.SectionsScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HubsScreen())

        obj.Show = sectionsShow
        obj.AfterItemFocused = sectionsAfterItemFocused

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
    obj.server = item.container.server
    obj.contentType = item.Get("type")

    return obj
end function

sub sectionsShow()
    if NOT Application().IsActiveScreen(m) then return

    ' create the hub requests or show cached hubs. We'll need a way to refresh a
    ' hub to update watched status, and maybe other attributes. We do need caching
    ' because some hubs are very dynamic (maybe not on the home screen)

    ' section requests
    if m.buttonsContainer.request = invalid then
        request = createPlexRequest(m.server, m.item.container.getAbsolutePath(m.item.Get("key")))
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
        ApplyFunc(ComponentsScreen().Show, m)
    else
        Debug("HubsShow:: waiting for all requests to be completed")
    end if
end sub

sub sectionsAfterItemFocused(item as object)
    pendingDraw = m.DescriptionBox.Show(item)
    if pendingDraw then m.screen.DrawAll()
end sub

function sectionsCreateButton(container as object) as object
    button = createButton(container.GetSingleLineTitle(), FontRegistry().font16, "show_grid")
    button.setMetadata(container.attrs)
    button.plexObject = container
    button.width = 200
    button.height = 66
    button.fixed = false
    button.setColor(Colors().TextClr, Colors().BtnBkgClr)
    return button
end function

function sectionsGetButtons() as object
    buttons = []
    for each container in m.buttonsContainer.items
        if container.Get("type") = invalid then container.attrs.type = m.contentType
        if container.Get("key") = "all" then
            buttons.push(m.createButton(container))
        end if
    end for

    return buttons
end function
