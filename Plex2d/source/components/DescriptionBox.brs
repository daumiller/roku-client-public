function DescriptionBoxClass() as object
    if m.DescriptionBox = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        ' Default settings
        obj.spacing = 0
        obj.title = { font: FontRegistry().font18b, color: Colors().TextClr}
        obj.subtitle = { font: FontRegistry().font18, color: &hc0c0c0c0 }

        ' Methods
        obj.Show = dboxShow
        obj.Hide = dboxHide
        obj.IsDisplayed = function() : return (m.components.count() > 0) : end function

        m.DescriptionBox = obj
    end if

    return m.DescriptionBox
end function

function createDescriptionBox(screen as object)
    obj = CreateObject("roAssociativeArray")
    obj.Append(DescriptionBoxClass())

    ' Initialize the manual components on the screen
    obj.components = screen.GetManualComponents("DescriptionBox")

    return obj
end function

function dboxHide() as boolean
    pendingDraw = false
    if m.IsDisplayed() then
        pendingDraw = true
        m.DestroyComponents()
    end if

    return pendingDraw
end function

function dboxShow(item as object) as boolean
    pendingDraw = m.Hide()
    if item.plexObject = invalid or item.plexObject.Get("ratingKey") = invalid then return pendingDraw
    contentType = item.plexObject.Get("type", "")
    viewGroup = item.plexObject.container.Get("viewGroup", "")

    ' *** Component Description *** '
    compDesc = createVBox(false, false, false, m.spacing)
    compDesc.SetFrame(m.x, m.y, m.width, m.height)

    if contentType = "episode" or contentType = "season" and contentType <> viewGroup then
        if contentType <> viewGroup
            title = item.plexObject.GetFirst(["grandparentTitle", "parentTitle"])
        else
            title = item.plexObject.Get("title", "")
        end if
    else
        title = item.plexObject.GetLongerTitle()
    end if

    label = createLabel(title, m.title.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.title.color)
    compDesc.AddComponent(label)

    subtitle = createObject("roList")
    if contentType = "movie" then
        subtitle.push(item.plexObject.Get("year"))
    else if contentType = "season" or (contentType = "episode" and viewGroup <> contentType) then
        subtitle.push(item.plexObject.Get("title"))
    end if

    if contentType = "season" or contentType = "show" then
        subtitle.push(item.plexObject.GetUnwatchedCountString())
    end if

    if contentType <> "movie" and contentType <> "season" and contentType <> "show" then
        if item.plexObject.Has("originallyAvailableAt") then
            subtitle.push(item.plexObject.GetOriginallyAvailableAt())
        else if item.plexObject.Has("AddedAt")
            subtitle.push(item.plexObject.GetAddedAt())
        end if
    end if

    if item.plexObject.Has("duration") then
        subtitle.push(item.plexObject.GetDuration())
    end if

    label = createLabel(joinArray(subtitle, " / "), m.subtitle.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.subtitle.color)
    compDesc.AddComponent(label)

    m.components.push(compDesc)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    return (pendingDraw or m.IsDisplayed())
end function
