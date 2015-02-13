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

function createIndicator(color as integer, height as integer, alphaPadding=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(IndicatorClass())

    obj.Init()

    obj.height = height
    obj.width = height

    ' alpha padding only works if you are drawing directly onto another bitmap,
    ' e.g. Label().DrawIndicator(). The height (size) of the region won't change,
    ' but we will resize the non transparent part of the indicator to fit within
    ' the requested dimensions.
    if alphaPadding then
        obj.size = int(obj.height * 0.7)
    else
        obj.size = obj.height
    end if
    obj.sizeOffset = obj.height - obj.size

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
            ' alpha region
            if m.size <> invalid then
                for line = 0 to m.height
                    m.region.DrawLine(0, line, m.height - line, line, Colors().Transparent)
                end for
            end if

            for line = 0 to m.size
                m.region.DrawLine(0, line, m.size - line, line, m.fgColor)
            end for
        else
            ' alpha region
            if m.size <> invalid then
                for line = 0 to m.height
                    m.region.DrawLine(0, line, line, line, Colors().Transparent)
                end for
            end if

            for line = 0 to m.size
                m.region.DrawLine(0, line + m.sizeOffset, line, line + m.sizeOffset, m.fgColor)
            end for
        end if
    else
        if m.valign = m.ALIGN_TOP then
            ' alpha region
            if m.size <> invalid then
                for line = 0 to m.height
                    m.region.DrawLine(m.width - (m.height - line), line, m.width, line, Colors().Transparent)
                end for
            end if

            for line = 0 to m.size
                m.region.DrawLine(m.width - (m.size - line), line, m.width, line, m.fgColor)
            end for
        else
            ' alpha region
            if m.size <> invalid then
                for line = 0 to m.height
                    m.region.DrawLine(m.width - line, line, m.width, line, Colors().Transparent)
                end for
            end if

            for line = 0 to m.size
                m.region.DrawLine(m.width - line, line + m.sizeOffset, m.width, line + m.sizeOffset, m.fgColor)
            end for
        end if
    end if

    return [m]
end function
