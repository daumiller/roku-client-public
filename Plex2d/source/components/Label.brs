function LabelClass() as object
    if m.LabelClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.ClassName = "Label"

        obj.Draw = labelDraw
        obj.GetPreferredWidth = labelGetPreferredWidth
        obj.GetPreferredHeight = labelGetPreferredHeight

        obj.WrapText = labelWrapText
        obj.TruncateText = labelTruncateText
        obj.MaxLineLength = labelMaxLineLength

        m.LabelClass = obj
    end if

    return m.LabelClass
end function

function createLabel(text as string, font as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(LabelClass())

    obj.Init()

    obj.text = text
    obj.font = font
    obj.wrap = false

    return obj
end function

function labelGetPreferredWidth() as integer
    ' If someone specifically set our width, then prefer that.
    if m.width <> 0 then
        return m.width
    else
        return m.font.GetOneLineWidth(m.text, 1280)
    end if
end function

function labelGetPreferredHeight() as integer
    ' If someone specifically set our height, then prefer that.
    if m.height <> 0 then
        return m.height
    else
        return m.font.GetOneLineHeight()
    end if
end function

function labelDraw() as object
    m.InitRegion()

    lineHeight = m.font.GetOneLineHeight()

    ' Split our text into lines according to the wrap setting.
    if m.wrap then
        lines = m.WrapText()
    else
        lines = [m.TruncateText()]
    end if

    ' Draw each line

    if m.valign = m.ALIGN_MIDDLE then
        yOffset = m.GetCenterOffsets(0, lines.Count() * lineHeight).y
    else if m.valign = m.ALIGN_BOTTOM then
        yOffset = m.height - (lines.Count() * lineHeight)
    else
        yOffset = 0
    end if

    for each line in lines
        if m.halign = m.JUSTIFY_CENTER then
            xOffset = m.GetCenterOffsets(m.font.GetOneLineWidth(line, m.width), 0).x
        else if m.halign = m.JUSTIFY_RIGHT then
            xOffset = m.width - m.font.GetOneLineWidth(line, 1280)
        else
            xOffset = 0
        end if

        m.region.DrawText(line, xOffset, yOffset, m.fgColor, m.font)
        yOffset = yOffset + lineHeight
    next

    return [{x: m.x, y: m.y, region: m.region}]
end function

function labelWrapText() as object
    lines = []
    lineNum = 0
    maxLines = int(m.height / m.font.GetOneLineHeight())

    startPos = 0

    while lines.Count() < maxLines and startPos < m.text.len()
        ' If this is the last allowed line, then just truncate the string
        if lines.Count() = maxLines-1 then
            lines.Push(m.TruncateText(m.text.Mid(startPos)))
        else
            ' Try to break on spaces. If the first whole word won't fit,
            ' then force a break mid-word.

            breakPos = startPos
            for index = startPos+1 to m.text.len()
                if m.text.mid(index, 1) = " " then
                    if m.font.GetOneLineWidth(m.text.mid(startPos, index - startPos), 1280) > m.width then
                        exit for
                    else
                        breakPos = index
                    end if
                end if
            end for

            ' If we found a word break that fits, use it.
            if breakPos <> startPos then
                lines.Push(m.text.mid(startPos, breakPos - startPos))
                startPos = breakPos + 1
            else
                breakPos = m.MaxLineLength(m.text.mid(startPos))
                lines.Push(m.text.mid(startPos, breakPos - startPos))
                startPos = breakPos
            end if
        end if
    end while

    return lines
end function

function labelTruncateText(fullText=invalid as dynamic) as string
    if fullText = invalid then fullText = m.text

    ' See if we need to truncate at all
    textWidth = m.font.GetOneLineWidth(fullText, 1280)
    if textWidth <= m.width then return fullText

    ' OK, we do need to trim the string. Start by adding an ellipsis so we can
    ' factor that width in. Then do a binary search to find the largest string
    ' that will fit.

    index = m.MaxLineLength("..." + fullText, 3)
    return left(fullText, index - 4) + "..."
end function

function labelMaxLineLength(text as string, startPos=0 as integer) as integer
    endPos = len(text)
    curPos = int((startPos + endPos) / 2)

    while curPos > startPos and curPos <= endPos
        textWidth = m.font.GetOneLineWidth(left(text, curPos), 1280)
        if textWidth <= m.width then
            startPos = curPos
        else
            endPos = curPos
        end if
        curPos = int((startPos + endPos) / 2)
    end while

    return startPos + 1
end function
