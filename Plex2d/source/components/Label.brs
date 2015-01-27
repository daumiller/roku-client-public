function LabelClass() as object
    if m.LabelClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.Append(PaddingMixin())
        obj.ClassName = "Label"

        obj.Init = labelInit
        obj.Draw = labelDraw
        obj.GetPreferredWidth = labelGetPreferredWidth
        obj.GetPreferredHeight = labelGetPreferredHeight
        obj.SetColor = labelSetColor

        obj.WrapText = labelWrapText
        obj.TruncateText = labelTruncateText
        obj.GetAllLines = labelGetAllLines
        obj.MaxLineLength = labelMaxLineLength

        m.LabelClass = obj
    end if

    return m.LabelClass
end function

function createLabel(text as string, font as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(LabelClass())

    obj.Init(text, font)

    return obj
end function

sub labelInit(text as string, font as object)
    ApplyFunc(ComponentClass().Init, m)

    m.SetColor(Colors().Text)

    m.text = text
    m.font = font
    m.wrap = false
end sub

function labelGetPreferredWidth() as integer
    ' If someone specifically set our width, then prefer that.
    if m.width <> 0 then
        return m.width
    else
        if m.padding <> invalid then
            paddingSize = m.padding.left + m.padding.right
        else
            paddingSize = 0
        end if

        return m.font.GetOneLineWidth(m.text, 1280) + paddingSize
    end if
end function

function labelGetPreferredHeight() as integer
    ' If someone specifically set our height, then prefer that.
    if m.height <> 0 then
        return m.height
    else
        if m.padding <> invalid then
            paddingSize = m.padding.top + m.padding.bottom
        else
            paddingSize = 0
        end if

        return m.font.GetOneLineHeight() + paddingSize
    end if
end function

function labelDraw(redraw=false as boolean) as object
    if redraw = false and m.region <> invalid then return [m]

    m.InitRegion()

    lineHeight = m.font.GetOneLineHeight()

    ' Split our text into lines according to the wrap setting.
    if m.wrap then
        lines = m.WrapText()
    else
        lines = [m.TruncateText()]
    end if

    ' Draw each line

    yOffset = m.GetYOffsetAlignment(lines.Count() * lineHeight)

    for each line in lines
        ' If we're left justifying, don't bother with the expensive width calculation.
        if m.halign = m.JUSTIFY_LEFT then
            xOffset = m.GetContentArea().x
        else
            xOffset = m.GetXOffsetAlignment(m.font.GetOneLineWidth(line, 1280))
        end if

        m.region.DrawText(line, xOffset, yOffset, m.fgColor, m.font)
        yOffset = yOffset + lineHeight
    next

    return [m]
end function

sub labelSetColor(fgColor as integer, bgColor=invalid as dynamic)
    ' We commonly want a transparent background, but in order for antialiasing
    ' to work well we have to set the background to be the same as the
    ' foreground apart from the alpha channel. So we allow the background to
    ' be omitted as a convenience for transparent.

    m.fgColor = fgColor

    if bgColor = invalid then
        m.bgColor = (fgColor and &hffffff00)
    else
        m.bgColor = bgColor
    end if
end sub

function labelWrapText(includeAllLines=false as boolean) as object
    contentArea = m.GetContentArea()
    lines = []
    lineNum = 0
    if includeAllLines then
        maxLines = invalid
    else
        maxLines = int(contentArea.height / m.font.GetOneLineHeight())
    end if

    startPos = 0

    while (maxLines <> invalid and lines.Count() < maxLines and startPos < m.text.len())  or (startPos < m.text.len())
        ' If this is the last allowed line, then just truncate the string
        if maxLines <> invalid and lines.Count() = maxLines-1 then
            lines.Push(m.TruncateText(m.text.Mid(startPos)))
        else
            ' Try to break on spaces. If the first whole word won't fit,
            ' then force a break mid-word.

            breakPos = startPos
            for index = startPos+1 to m.text.len()
                if m.text.mid(index, 1) = " " or index >= m.text.len() then
                    if m.font.GetOneLineWidth(m.text.mid(startPos, index - startPos), 1280) > contentArea.width then
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

function labelGetAllLines(width=invalid as dynamic) as object
    if width <> invalid then m.width = width
    return m.WrapText(true)
end function

function labelTruncateText(fullText=invalid as dynamic) as string
    if fullText = invalid then fullText = m.text

    ' See if we need to truncate at all
    textWidth = m.font.GetOneLineWidth(fullText, 1280)
    if textWidth <= m.GetContentArea().width or fullText.len() = 1 then return fullText

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
        if textWidth <= m.GetContentArea().width then
            startPos = curPos
        else
            endPos = curPos
        end if
        curPos = int((startPos + endPos) / 2)
    end while

    return startPos + 1
end function
