function DescriptionBoxClass() as object
    if m.DescriptionBox = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        ' Default settings
        obj.spacing = 0
        obj.titlePrefs = { font: FontRegistry().LARGE_BOLD, color: Colors().Text}
        obj.subtitlePrefs = { font: FontRegistry().LARGE, color: Colors().TextDim}
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
    obj = createVBox(false, false, false, 0)

    dbox = DescriptionBoxClass()

    obj.titlePrefs = dbox.titlePrefs
    obj.subtitlePrefs = dbox.subtitlePrefs

    obj.Build = dbox.Build
    obj.SetText = dboxSetText

    obj.title = title
    obj.subtitle = subtitle

    return obj.Build(false)
end function

sub dboxSetText(title as string, subtitle as string)
    if m.titleLabel = invalid or m.titleLabel.sprite = invalid then return

    m.titleLabel.text = title
    m.titleLabel.Draw(true)

    m.subtitleLabel.text = subtitle
    m.subtitleLabel.Draw(true)
    m.subtitleLabel.Redraw()
end sub

function dboxBuild(createBox as boolean)
    if createBox then
        vbox = createVBox(false, false, false, m.spacing)
    else
        vbox = m
    end if

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

    m.titleLabel = title
    m.subtitleLabel = subtitle

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
    hasMixedParents = (viewGroup <> contentType or plexObject.container.Get("mixedParents", "") = "1")

    Verbose("Show description: " + plexObject.toString() + ", contentType=" + contentType + ", viewGroup=" + viewGroup)

    ' *** Component Description *** '
    if contentType = "episode" or contentType = "season" then' and hasMixedParents then
        if hasMixedParents then
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
    else if contentType = "season" or contentType = "episode" and hasMixedParents then
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

    dbox = m.Build(true)
    dbox.SetFrame(m.x, m.y, m.width, m.height)
    m.components.push(dbox)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    return (pendingDraw or m.IsDisplayed())
end function
