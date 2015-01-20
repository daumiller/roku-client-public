function DescriptionBoxClass() as object
    if m.DescriptionBox = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        ' Default settings
        obj.spacing = 0
        obj.titlePrefs = { font: FontRegistry().font18b, color: Colors().Text}
        obj.subtitlePrefs = { font: FontRegistry().font18, color: Colors().TextDim}
        obj.zOrder = ZOrders().DESCBOX

        ' Methods
        obj.Show = dboxShow
        obj.Hide = dboxHide
        obj.Build = dboxBuild
        obj.IsDisplayed = function() : return (m.components.count() > 0) : end function

        m.DescriptionBox = obj
    end if

    return m.DescriptionBox
end function

function createStaticDescriptionBox(title as string, subtitle as string)
    obj = CreateObject("roAssociativeArray")
    obj.Append(DescriptionBoxClass())

    obj.title = title
    obj.subtitle = subtitle

    return obj.Build()
end function

function dboxBuild()
    vbox = createVBox(false, false, false, m.spacing)

    title = createLabel(m.title, m.titlePrefs.font)
    title.halign = title.JUSTIFY_LEFT
    title.valign = title.ALIGN_MIDDLE
    title.SetColor(m.titlePrefs.color)
    title.zOrder = m.zOrder
    vbox.AddComponent(title)

    subtitle = createLabel(m.subtitle, m.subtitlePrefs.font)
    subtitle.halign = title.JUSTIFY_LEFT
    subtitle.valign = title.ALIGN_MIDDLE
    subtitle.zOrder = m.zOrder
    subtitle.SetColor(m.subtitlePrefs.color)
    vbox.AddComponent(subtitle)

    return vbox
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
    plexObject = item.plexObject
    contentType = plexObject.Get("type", "")
    viewGroup = plexObject.container.Get("viewGroup", "")
    Debug("Show description: " + plexObject.toString() + ", contentType=" + contentType + ", viewGroup=" + viewGroup)

    ' *** Component Description *** '
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

    ' set title, subtitle and build
    m.title = title
    m.subtitle = joinArray(subtitle, " / ")

    dbox = m.Build()
    dbox.SetFrame(m.x, m.y, m.width, m.height)
    m.components.push(dbox)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    return (pendingDraw or m.IsDisplayed())
end function
