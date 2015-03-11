function IndicatorClass() as object
    if m.IndicatorClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.ClassName = "Indicator"

        obj.draw = indiDraw
        obj.SetDimensions = indiSetDimensions

        m.IndicatorClass = obj
    end if

    return m.IndicatorClass
end function

function createIndicator(color as integer, height as integer, alphaBorder=false as boolean) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(IndicatorClass())

    obj.Init()

    obj.alphaBorder = alphaBorder
    obj.bgColor = (color and &hffffff00)
    obj.fgColor = color
    obj.halign = obj.JUSTIFY_RIGHT
    obj.valign = obj.ALIGN_BOTTOM

    obj.SetDimensions(height, height)

    return obj
end function

sub indiSetDimensions(width as integer, height as integer)
    m.width = width
    m.height = height

    ' alpha border only works if you are drawing directly onto another bitmap,
    ' e.g. Label().DrawIndicator(). The height (size) of the region won't change,
    ' but we will resize the non transparent part of the indicator to fit within
    ' the requested dimensions.
    if m.alphaBorder then
        m.size = int(m.height * 0.7)
    else
        m.size = m.height - 1
    end if
    m.sizeOffset = m.height - m.size
end sub

function indiDraw(redraw=false as boolean) as object
    if redraw = false and m.region <> invalid then return [m]
    m.InitRegion()

    borderColor = iif(m.alphaBorder, Colors().Transparent, Colors().IndicatorBorder)

    if m.halign = m.JUSTIFY_LEFT then
        if m.valign = m.ALIGN_TOP then
            ' border - Transparent or standard IndicatorBorder
            for line = 0 to m.height
                m.region.DrawLine(0, line, m.height - line, line, borderColor)
            end for

            for line = 0 to m.size
                m.region.DrawLine(0, line, m.size - line, line, m.fgColor)
            end for
        else
            ' border - Transparent or standard IndicatorBorder
            for line = 0 to m.height
                m.region.DrawLine(0, line, line, line, borderColor)
            end for

            for line = 0 to m.size
                m.region.DrawLine(0, line + m.sizeOffset, line, line + m.sizeOffset, m.fgColor)
            end for
        end if
    else
        if m.valign = m.ALIGN_TOP then
            ' border - Transparent or standard IndicatorBorder
            for line = 0 to m.height
                m.region.DrawLine(m.width - (m.height - line), line, m.width, line, borderColor)
            end for

            for line = 0 to m.size
                m.region.DrawLine(m.width - (m.size - line), line, m.width, line, m.fgColor)
            end for
        else if m.valign = m.ALIGN_MIDDLE then
            ' no border or alpha padding for center
            for line = 0 to int(m.size/2)
                m.region.DrawLine(line, line, m.size - line, line, m.fgColor)
            end for
        else
            ' border - Transparent or standard IndicatorBorder
            for line = 0 to m.height
                m.region.DrawLine(m.width - line, line, m.width, line, borderColor)
            end for

            for line = 0 to m.size
                m.region.DrawLine(m.width - line, line + m.sizeOffset, m.width, line + m.sizeOffset, m.fgColor)
            end for
        end if
    end if

    return [m]
end function
