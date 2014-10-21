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

    ' *** Component Description *** '
    compDesc = createVBox(false, false, false, m.spacing)
    compDesc.SetFrame(m.x, m.y, m.width, m.height)

    label = createLabel(item.plexObject.getlongertitle(), m.line1.font)
    label.halign = label.JUSTIFY_LEFT
    label.valign = label.ALIGN_MIDDLE
    label.SetColor(m.line1.color)
    compDesc.AddComponent(label)

    line2 = []
    if item.plexObject.Get("type") = "movie" then
        line2.push(item.plexObject.Get("year"))
    else
        line2.push(item.plexObject.GetOriginallyAvailableAt())
    end if
    if line2.peek() = "" or line2.peek() = invalid then
        line2.pop()
        line2.push(item.plexObject.GetAddedAt())
    end if
    line2.push(item.plexObject.GetDuration())
    if item.plexObject.type = "episode" then
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
