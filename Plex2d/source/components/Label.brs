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
        obj.SetBorder = labelSetBorder
        obj.DrawIndicator = labelDrawIndicator
        obj.SetIndicator = labelSetIndicator
        obj.SetText = labelSetText

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

        if m.borderSize <> invalid then
            paddingSize = paddingSize + m.border.left + m.border.right
        end if

        if m.roundedCorners = true then
            paddingSize = 16
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

        if m.borderSize <> invalid then
            paddingSize = paddingSize + m.border.top + m.border.bottom
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
            xOffset = m.GetContentArea().x + iif(m.roundedCorners = true, 8, 0)
        else
            xOffset = m.GetXOffsetAlignment(m.font.GetOneLineWidth(line, 1280))
        end if

        m.region.DrawText(line, xOffset, yOffset, m.fgColor, m.font)
        yOffset = yOffset + lineHeight

        if m.border <> invalid then
            m.region.DrawRect(0, 0, m.width, m.border.top, m.border.color)
            m.region.DrawRect(m.width - m.border.right, 0, m.border.right, m.height, m.border.color)
            m.region.DrawRect(0, m.height - m.border.bottom, m.width, m.border.bottom, m.border.color)
            m.region.DrawRect(0, 0, m.border.left, m.height, m.border.color)
        end if
    next

    if m.useIndicator = true then
        m.DrawIndicator()
    end if

    return [m]
end function

sub labelSetColor(fgColor as integer, bgColor=invalid as dynamic, fgColorFocus=invalid as dynamic)
    ' We commonly want a transparent background, but in order for antialiasing
    ' to work well we have to set the background to be the same as the
    ' foreground apart from the alpha channel. So we allow the background to
    ' be omitted as a convenience for transparent.

    m.fgColor = fgColor
    m.fgColorFocus = fgColorFocus

    if bgColor = invalid then
        m.bgColor = (fgColor and &hffffff00)
    else
        m.bgColor = bgColor
    end if
end sub

sub labelSetBorder(color as integer, bTop as integer, bRight=invalid as dynamic, bBottom=invalid as dynamic, bLeft=invalid as dynamic)
    ' Order of parameters and default values is borrowed from CSS.
    bRight = firstOf(bRight, bTop)
    bBottom = firstOf(bBottom, bTop)
    bLeft = firstOf(bLeft, bRight)

    m.border = {
        left: bLeft,
        right: bRight,
        top: bTop,
        bottom: bBottom
        color: color
    }
end sub

function labelWrapText(includeAllLines=false as boolean) as object
    contentArea = m.GetContentArea()
    lines = []
    if includeAllLines then
        maxLines = invalid
    else
        maxLines = int(contentArea.height / m.font.GetOneLineHeight())
    end if

    ' Split the text into paragraphs (performance boost)
    paragraphs = CreateObject("roRegex", "\n", "").Split(m.text)

    ' Split long paragraphs to increase performance.
    newParagraphs = CreateObject("roList")
    charLimit = 5000
    for each paragraph in paragraphs
        if paragraph.len() <= charLimit then
            newParagraphs.Push(paragraph)
        else
            index = charLimit
            text = paragraph
            while text.len() > charLimit
                break = text.Mid(index, 1)
                if break = " " or index >= text.Len() then
                    newParagraphs.Push(text.left(index))
                    text = text.right(text.Len() - index).Trim()
                    index = charLimit
                else
                    index = index + 1
                end if
            end while

            ' Push the final text
            if text.Len() > 0 then
                newParagraphs.Push(text)
            end if
        end if
    end for
    paragraphs = newParagraphs

    for each paragraph in paragraphs
        startPos = 0

        while paragraph.len() > 0
            ' If this is the last allowed line, then just truncate the string
            if maxLines <> invalid and lines.Count() = maxLines-1 then
                lines.Push(m.TruncateText(paragraph.Mid(startPos)))
                exit while
            else
                ' Try to break on spaces. If the first whole word won't fit,
                ' then force a break mid-word.

                breakPos = startPos
                for index = startPos+1 to paragraph.len()
                    text = paragraph.Mid(index, 1)
                    if text = " " or index >= paragraph.Len() then
                        if m.font.GetOneLineWidth(paragraph.Left(index - startPos), 1280) > contentArea.width then
                            exit for
                        else
                            breakPos = index
                        end if
                    end if
                end for

                ' Exit loop if we didn't find a break point
                if breakPos = startPos then exit while

                ' If we found a word break that fits, use it.
                lines.Push(paragraph.Left(breakPos))
                paragraph = paragraph.Right(paragraph.Len() - breakPos).Trim()
                startPos = 0
            end if
        end while

        if maxLines <> invalid and lines.Count() >= maxLines then exit for
    end for

    return lines
end function

function labelGetAllLines(width=invalid as dynamic) as object
    if width <> invalid then m.width = width
    return m.WrapText(true)
end function

function labelTruncateText(fullText=invalid as dynamic) as string
    if fullText = invalid then fullText = m.text

    ' Only use the first line of text (split on newlines)
    fullText = firstOf(fullText.Tokenize(chr(10))[0], "")

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

sub labelSetIndicator(valign=invalid as dynamic, halign=invalid as dynamic)
    m.valignIndicator = valign
    m.halignIndicator = halign
end sub

sub labelDrawIndicator()
    indicator = createIndicator(Colors().Indicator, int(m.height * 0.4), true)
    indicator.bgColor = m.bgColor
    indicator.valign = firstOf(m.valignIndicator, indicator.ALIGN_BOTTOM)
    indicator.halign = firstOf(m.halignIndicator, indicator.JUSTIFY_RIGHT)
    indicator.Draw()

    if indicator.halign = indicator.JUSTIFY_RIGHT then
        xOffset = m.width - indicator.region.GetWidth()
    else
        xOffset = 0
    end if

    if indicator.valign = indicator.ALIGN_BOTTOM then
        yOffset = m.height - indicator.region.GetHeight()
    else if indicator.valign = indicator.ALIGN_MIDDLE then
        yOffset = m.height/2 - indicator.region.GetHeight()/4
    else
        yOffset = 0
    end if

    m.region.DrawObject(xOffset, yOffset, indicator.region)
end sub

sub labelSetText(text as string, redraw=false as boolean, resize=false as boolean)
    if m.text = text or m.font = invalid then return

    m.text = text

    if resize then
        m.width = 0
        if m.parent <> invalid then
            maxWidth = iif(m.parent.width > 0, m.parent.width, 1280)
        else
            maxWidth = 1280
        end if

        preferred = m.GetPreferredWidth()
        m.width = iif(preferred < maxWidth, preferred, maxWidth)

        ' Make sure the new width is actually used
        m.contentArea = invalid
        m.region = invalid
    end if

    if redraw then
        m.Draw(true)
        if m.sprite <> invalid then m.sprite.SetRegion(m.region)
    end if
end sub
