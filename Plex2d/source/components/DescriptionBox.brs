function DescriptionBoxClass() as object
    if m.DescriptionBox = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        ' Default settings
        obj.spacing = 0
        obj.title = { font: FontRegistry().font18b, color: Colors().Text}
        obj.subtitle = { font: FontRegistry().font18, color: Colors().TextDim}

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
    obj.zOrder = 500

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
    plexObject = item.plexObject
    contentType = plexObject.Get("type", "")
    viewGroup = plexObject.container.Get("viewGroup", "")
    Debug("Show description: " + plexObject.toString() + ", contentType=" + contentType + ", viewGroup=" + viewGroup)

    ' *** Component Description *** '
    compDesc = createVBox(false, false, false, m.spacing)
    compDesc.SetFrame(m.x, m.y, m.width, m.height)

    if contentType = "episode" or contentType = "season" and contentType <> viewGroup then
        if contentType <> viewGroup
            title = plexObject.GetFirst(["grandparentTitle", "parentTitle"], "")
        else
            title = plexObject.Get("title", "")
        end if
    else if contentType = "album" and contentType = viewGroup then
        title = plexObject.Get("title", "")
    else if contentType = "album" or contentType = "clip" then
        title = plexObject.GetFirst(["grandparentTitle", "parentTitle", "title"], "")
    else
        title = plexObject.GetLongerTitle()
    end if

    label = createLabel(title, m.title.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.title.color)
    label.zOrder = m.zOrder
    compDesc.AddComponent(label)

    subtitle = createObject("roList")
    if contentType = "movie" then
        subtitle.push(plexObject.Get("year", ""))
    else if contentType = "season" or (contentType = "episode" and viewGroup <> contentType) then
        subtitle.push(plexObject.Get("title", ""))
    else if (contentType = "album" or contentType = "artist") and contentType = viewGroup then
        subtitle.push(plexObject.Get("year", ""))
        subtitle.push(plexObject.GetChildCountString())
    else if contentType = "album" or contentType = "clip" then
        subtitle.push(plexObject.Get("title", ""))
        subtitle.push(plexObject.Get("year", ""))
    end if

    if contentType = "season" or contentType = "show" then
        subtitle.push(plexObject.GetUnwatchedCountString())
    end if

    if contentType <> "movie" and contentType <> "season" and contentType <> "show" and contentType <> "album" and contentType <> "clip" then
        if plexObject.Has("originallyAvailableAt") then
            subtitle.push(plexObject.GetOriginallyAvailableAt())
        else if plexObject.Has("AddedAt")
            subtitle.push(plexObject.GetAddedAt())
        end if
    end if

    if plexObject.Has("duration") then
        subtitle.push(plexObject.GetDuration())
    end if

    label = createLabel(joinArray(subtitle, " / "), m.subtitle.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.subtitle.color)
    label.zOrder = m.zOrder
    compDesc.AddComponent(label)

    m.components.push(compDesc)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    return (pendingDraw or m.IsDisplayed())
end function
