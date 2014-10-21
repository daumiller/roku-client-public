function DescriptionBoxClass() as object
    if m.DescriptionBox = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        ' Default settings
        obj.spacing = 0
        obj.line1 = { font: FontRegistry().font18b, color: Colors().TextClr}
        obj.line2 = { font: FontRegistry().font18, color: &hc0c0c0c0 }

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
    contentType = tostr(item.plexObject.Get("type"))

    ' *** Component Description *** '
    compDesc = createVBox(false, false, false, m.spacing)
    compDesc.SetFrame(m.x, m.y, m.width, m.height)

    if contentType = "episode" and m.IsGrid = true then
        title = item.plexObject.GetSingleLineTitle()
    else
        title = item.plexObject.GetLongerTitle()
    end if
    label = createLabel(title, m.line1.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.line1.color)
    compDesc.AddComponent(label)

    line2 = []
    if contentType = "movie" then
        line2.push(item.plexObject.Get("year"))
    else if contentType = "show"
        unwatched = item.plexObject.GetUnwatchedCount()
        if unwatched > 0 then
            text = tostr(unwatched) + " unwatched episode"
            if unwatched > 1 then text = text + "s"
            line2.push(text)
        end if
    else if item.plexObject.has("originallyAvailableAt") then
        line2.push(item.plexObject.GetOriginallyAvailableAt())
    else
        line2.push(item.plexObject.GetAddedAt())
    end if
    line2.push(item.plexObject.GetDuration())
    if contentType = "episode" and NOT (m.IsGrid = true) then
        line2.unshift(item.plexObject.Get("title"))
    end if

    label = createLabel(joinArray(line2, " / "), m.line2.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.line2.color)
    compDesc.AddComponent(label)

    m.components.push(compDesc)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    return (pendingDraw or m.IsDisplayed())
end function
