function PinPromptClass() as object
    if m.PinPromptClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())
        obj.ClassName = "PinPromptClass"

        ' Methods
        obj.Init = pinpromptInit
        obj.GetComponents = pinpromptGetComponents
        obj.CreateButton = pinpromptCreateButton
        obj.HandleButton = pinpromptHandleButton
        obj.DelDigit = pinpromptDelDigit
        obj.AddDigit = pinpromptAddDigit
        obj.UpdateTitle = pinpromptUpdateTitle

        m.PinPromptClass = obj
    end if

    return m.PinPromptClass
end function

function createPinPrompt(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(PinPromptClass())

    obj.screen = screen
    obj.title = "Enter Pin"
    obj.showBorder = true
    obj.userSwitch = invalid

    obj.Init()

    return obj
end function

sub pinpromptInit()
    ApplyFunc(OverlayClass().Init, m)

    m.pinCode = CreateObject("roList")

    m.width = 300
    m.height = 300
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)

    m.colors = {
        background: Colors().Black,
        border: Colors().Button
        title: Colors().Text,
        titleError: Colors().Orange,
        titleBg: Colors().Button,
        text: Colors().TextDim,
        textFocus: Colors().Text,
        button: Colors().Button,
        buttonFocus: Colors().Button
    }

    m.customFonts = {
        title: FontRegistry().font18,
        pin: FontRegistry().GetTextFont(28)
        glyph: FontRegistry().GetIconFont(24)
        text: FontRegistry().font16
    }

    m.spacing = 5
    if m.showBorder then
        m.border = { spacing: m.spacing, px: 1, color: m.colors.border }
    end if
end sub

sub pinpromptGetComponents()
    title = createLabel(m.title, m.customFonts.title)
    title.halign = title.JUSTIFY_CENTER
    title.valign = title.ALIGN_MIDDLE
    title.zOrder = 100
    title.SetColor(m.colors.title, m.colors.titleBg)
    title.SetFrame(m.x, m.y, m.width, 60)
    m.compTitle = title
    m.components.push(title)

    pinBox = createVBox(true, true, true, m.spacing)
    pinBox.SetFrame(m.x + m.spacing, m.y + title.height, m.width - m.spacing*2, m.height - title.height - m.spacing)

    pinDisBox = createHBox(true, true, true, m.spacing)
    numBox1_5 = createHBox(true, true, true, m.spacing)
    numBox6_0 = createHBox(true, true, true, m.spacing)
    actionBox = createHBox(true, true, true, m.spacing)

    pinBox.AddComponent(pinDisBox)
    pinBox.AddComponent(numBox1_5)
    pinBox.AddComponent(numBox6_0)
    pinBox.AddComponent(actionBox)

    m.components.push(pinBox)

    ' PIN display placeholder
    for i = 0 to 3
        digit = createLabel("*", m.customFonts.pin)
        digit.SetColor(m.colors.text)
        digit.zOrder = 100
        digit.halign = digit.JUSTIFY_CENTER
        digit.valign = digit.ALIGN_BOTTOM
        m["compPin_" + tostr(i)] = digit
        pinDisBox.AddComponent(digit)
    end for

    ' Number Pad
    for i = 1 to 5
        buttonR1 = m.createButton(tostr(i), m.customFonts.text, "digit")
        num = iif(i = 5, 0, i + 5)
        buttonR2 = m.createButton(tostr(num), m.customFonts.text, "digit")
        numBox1_5.AddComponent(buttonR1)
        numBox6_0.AddComponent(buttonR2)

        ' wrap navigation for number pad
        if i = 5 then
            buttonR1.SetFocusSibling("right", numBox1_5.components[0])
            buttonR2.SetFocusSibling("right", numBox6_0.components[0])
            numBox1_5.components[0].SetFocusSibling("left", buttonR1)
            numBox6_0.components[0].SetFocusSibling("left", buttonR2)
        end if
    end for

    ' action box (backspace/submit)
    backspace = m.createButton(Glyphs().BACKSPACE, m.customFonts.glyph, "backspace")
    submit = m.createButton("Done", m.customFonts.text, "submit")
    actionBox.AddComponent(backspace)
    actionBox.AddComponent(submit)
    m.compSubmit = submit

    ' wrap navigation for action box
    backspace.SetFocusSibling("left", submit)
    submit.SetFocusSibling("right", backspace)

    ' PIN box background
    bkg = createBlock(m.colors.background)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = 99
    m.components.push(bkg)

    ' pin box border
    if m.border <> invalid then
        rect = computeRect(pinBox)
        rect.height = rect.height + m.border.spacing
        rect.width = rect.width + m.border.spacing*2
        rect.left = rect.left - m.border.spacing
        rect.right = rect.right + m.border.spacing - m.border.px
        rect.down = rect.down + m.border.spacing

        borderLeft = createBlock(m.border.color)
        borderLeft.SetFrame(rect.left, rect.up, m.border.px, rect.height)
        borderLeft.zOrder = 99
        m.components.push(borderLeft)

        borderRight = createBlock(m.border.color)
        borderRight.SetFrame(rect.right, rect.up, m.border.px, rect.height)
        borderRight.zOrder = 99
        m.components.push(borderRight)

        borderBottom = createBlock(m.border.color)
        borderBottom.SetFrame(rect.left, rect.down, rect.width, m.border.px)
        borderBottom.zOrder = 99
        m.components.push(borderBottom)
    end if
end sub

function pinpromptCreateButton(title as string, font as object, command as string) as object
    btn = createButton(title, font, command)
    btn.SetColor(m.colors.text, m.colors.button)
    btn.focusInside = true
    btn.fixed = false
    btn.zOrder = 100

    ' custom PIN button properties
    btn.overlay = m
    btn.screen = m.screen
    btn.OnSelected = pinpromptOnSelected
    btn.OnFocus = pinpromptOnFocus
    btn.OnBlur = pinpromptOnBlur
    btn.value = title

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

sub pinpromptOnFocus()
    m.SetColor(m.overlay.colors.textFocus, m.overlay.colors.buttonFocus)
    m.draw(true)
end sub

sub pinpromptOnBlur(toFocus as object)
    overlay = m.overlay

    ' clear the error on first movement
    if overlay.hasError = true
        overlay.hasError = false
        overlay.UpdateTitle()
    end if

    m.SetColor(overlay.colors.text, overlay.colors.button)
    m.draw(true)
end sub

sub pinpromptOnSelected()
    m.overlay.HandleButton(m)
end sub

sub pinpromptHandleButton(button as object)
    Debug("pin prompt button selected: command=" + tostr(button.command) + ", value=" + tostr(button.value))

    if button.command = "digit" then
        m.AddDigit(button.value)
    else if button.command = "submit" then
        m.result = joinArray(m.pinCode, "")
        ' verify user switch is succesful if requested, or function as a
        ' standard pin prompt and close. The later may need some updates
        ' if we ever have any use. e.g. pin length
        if m.userSwitch <> invalid then
            if m.pinCode.count() = 4 and MyPlexAccount().SwitchHomeUser(m.userSwitch.id, m.result) then
                m.Close()
            else
                m.hasError = true

                ' reset title and clear pincode
                m.UpdateTitle("Try again...")
                for i = 0 to m.pinCode.Count() - 1
                    m.DelDigit(i)
                end for

                m.screen.screen.DrawAll()
            end if
        else
            m.Close()
        end if
    else if button.command = "backspace"
        m.DelDigit(m.pinCode.Count() - 1)
    else if button.command = "close" then
        m.Close()
    else
        Debug("command not defined: " + tostr(button.command))
    end if
end sub

sub pinpromptDelDigit(digit as integer, drawAll=true as boolean)
    if digit < 0 then return
    m.pinCode.Pop()

    comp = m["compPin_" + tostr(digit)]
    comp.SetColor(m.colors.text)
    comp.Draw(true)

    if drawAll then m.screen.screen.DrawAll()
end sub

sub pinpromptAddDigit(value as string)
    count = m.pinCode.Count()

    if count < 4 then
        comp = m["compPin_" + tostr(count)]
        comp.SetColor(m.colors.textFocus)
        comp.Draw(true)
        m.pinCode.push(value)
    end if

    ' focus to submit button or redraw new digit
    if m.pinCode.Count() = 4 then
        m.screen.FocusItemManually(m.compSubmit)
    else
        m.screen.screen.DrawAll()
    end if
end sub

sub pinpromptUpdateTitle(title=invalid as dynamic)
    comp = m["compTitle"]
    comp.text = firstOf(title, m.title)

    if m.hasError then
        comp.SetColor(m.colors.titleError, m.colors.titleBg)
    else
        comp.SetColor(m.colors.title, m.colors.titleBg)
    end if

    comp.Draw(true)
end sub
