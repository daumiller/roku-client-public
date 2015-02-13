function IndicatorClass() as object
    if m.IndicatorClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.ClassName = "Indicator"

        obj.draw = indiDraw

        m.IndicatorClass = obj
    end if

    return m.IndicatorClass
end function

function createIndicator(color as integer, height as integer, padding=0 as integer, halfHeight=true as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(IndicatorClass())

    obj.Init()

    obj.height = height + padding
    if halfHeight = true then obj.height = int(obj.height/2)
    obj.bgColor = (color and &hffffff00)
    obj.fgColor = color
    obj.halign = obj.JUSTIFY_RIGHT
    obj.valign = obj.ALIGN_BOTTOM

    return obj
end function

function indiDraw(redraw=false as boolean) as object
    if redraw = false and m.region <> invalid then return [m]

    m.InitRegion()

    if m.halign = m.JUSTIFY_LEFT then
        if m.valign = m.ALIGN_TOP then
            for line = 0 to m.height
                m.region.DrawLine(0, line, m.height - line, line, m.fgColor)
            end for
        else
            for line = 0 to m.height
                m.region.DrawLine(0, line, line, line, m.fgColor)
            end for
        end if
    else
        if m.valign = m.ALIGN_TOP then
            for line = 0 to m.height
                m.region.DrawLine(m.width - (m.height - line), line, m.width, line, m.fgColor)
            end for
        else
            for line = 0 to m.height
                m.region.DrawLine(m.width - line, line, m.width, line, m.fgColor)
            end for
        end if
    end if

    return [m]
end function
