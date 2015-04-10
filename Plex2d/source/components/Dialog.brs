function DialogClass() as object
    if m.DialogClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(OverlayClass())
        obj.ClassName = "DialogClass"

        ' Methods
        obj.Init = dialogInit
        obj.GetComponents = dialogGetComponents
        obj.AddButton = dialogAddButton
        obj.CreateButton = dialogCreateButton
        obj.HandleButton = dialogHandleButton
        obj.OnKeyRelease = dialogOnKeyRelease

        m.DialogClass = obj
    end if

    return m.DialogClass
end function

function createDialog(title as string, text as dynamic, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DialogClass())

    obj.screen = screen

    obj.Init(title, text)

    return obj
end function

sub dialogInit(title as string, text=invalid as dynamic)
    ApplyFunc(OverlayClass().Init, m)

    m.components = m.screen.GetManualComponents(m.ClassName)
    m.buttons = CreateObject("roList")
    m.title = title
    m.text = text

    m.width = 500
    m.spacing = 25
    m.maxLines = 4

    m.padding = {
        top: 10,
        right: 25,
        bottom: 10,
        left: 25,
    }

    m.buttonPrefs = {
        width: 72,
        height: 44,
        padding: 10,
        fixed: false,
    }
    m.buttonPrefs.maxWidth = m.width - m.buttonPrefs.padding*2

    m.customFonts = {
        buttonFont: FontRegistry().NORMAL
        titleFont:  FontRegistry().LARGE_BOLD
        textFont:  FontRegistry().LARGE
    }

    m.buttonsSingleLine = false
end sub

sub dialogGetComponents()
    dialogBox = createVBox(false, false, false, m.spacing)

    if m.title <> invalid then
        m.titleLabel = createLabel(m.title, m.customFonts.titleFont)
        m.titleLabel.padding = m.padding
        m.titleLabel.halign = m.titleLabel.JUSTIFY_CENTER
        m.titleLabel.valign = m.titleLabel.ALIGN_MIDDLE
        m.titleLabel.zOrder = m.zOrderOverlay
        m.titleLabel.SetColor(Colors().Text, Colors().ButtonDark)
        dialogBox.AddComponent(m.titleLabel)
    end if

    if m.text <> invalid then
        label = createLabel(m.text, m.customFonts.textFont)
        label.SetPadding(0, m.padding.right, m.padding.bottom, m.padding.left)
        label.wrap = true
        label.zOrder = m.zOrderOverlay
        label.phalign = label.JUSTIFY_CENTER

        ' Calculate the height based on the number of lines to fit (m.maxLines)
        padHeight = label.padding.bottom + label.padding.top
        oneLineHeight = m.customFonts.textFont.GetOneLineHeight()
        label.width = m.width
        label.height = oneLineHeight * m.maxLines + padHeight
        lineCount = label.WrapText().Count()

        ' Resize height based on number of lines
        label.height = oneLineHeight * lineCount + padHeight

        ' Resize width and center align if we only have one line
        if lineCount = 1 then
            label.width = m.customFonts.textFont.GetOneLineWidth(m.text, label.width)
            label.halign = label.JUSTIFY_CENTER
        end if

        dialogBox.AddComponent(label)
    end if

    if m.buttons.count() = 0 then
        dialogBox.AddComponent(m.createButton("OK", "close"))
    else
        if m.buttonsSingleLine then
            btnCont = createHBox(false, false, false, m.spacing)
        else
            btnCont = createVBox(false, false, false, m.spacing)
        end if
        btnCont.phalign = btnCont.JUSTIFY_CENTER

        ' resize button width based on longest text option
        for each button in m.buttons
            preferWidth = m.customFonts.buttonFont.GetOneLineWidth(button.text, m.width) + m.buttonPrefs.padding*2
            if preferWidth > m.buttonPrefs.width then m.buttonPrefs.width = preferWidth
        end for
        if m.buttonPrefs.width > m.buttonPrefs.maxWidth then m.buttonPrefs.width = m.buttonPrefs.maxWidth

        for each button in m.buttons
            btn = m.createButton(button.text, button.command)
            if button.bgColor <> invalid then btn.SetColor(Colors().Text, button.bgColor)
            btnCont.AddComponent(btn)
        end for
        dialogBox.AddComponent(btnCont)
    end if
    m.components.push(dialogBox)

    ' resize and position the dialog based on the available components
    width = 0
    height = 0
    for each comp in dialogBox.components
        if comp.GetPreferredWidth() > width then
            width = comp.GetPreferredWidth()
        end if
        height = height + comp.GetPreferredHeight()
    end for
    m.width = width + m.padding.left + m.padding.right
    m.height = height + m.padding.top + m.padding.bottom + (dialogBox.spacing * (dialogBox.components.count()-1))

    ' Position the dialog in the center of the screen
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)
    dialogBox.SetFrame(m.x, m.y, m.width, m.height)

    ' Add the background
    bkg = createBlock(Colors().OverlayVeryDark)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = m.zOrderOverlay - 1
    m.components.push(bkg)

    ' Reset the title width to the size of the dialog
    if m.titleLabel <> invalid then
        m.titleLabel.width = m.width
    end if
end sub

function dialogCreateButton(text as string, command=invalid as dynamic) as object
    btn = createButton(text, m.customFonts.buttonFont, command)
    btn.SetColor(Colors().Text, Colors().Button)
    btn.width = m.buttonPrefs.width
    btn.height = m.buttonPrefs.height
    btn.fixed = m.buttonPrefs.fixed
    btn.zOrder = m.zOrderOverlay
    btn.SetPadding(m.buttonPrefs.padding)
    btn.dialog = m
    btn.OnSelected = dialogButtonOnSelected

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

sub dialogAddButton(text as string, command=invalid as dynamic, bgColor=invalid as dynamic) as object
    m.buttons.push({text: text, command: command, bgColor: bgColor})
end sub

sub dialogButtonOnSelected(screen as object)
    m.dialog.HandleButton(m)
end sub

sub dialogHandleButton(button as object)
    m.result = button.command
    if m.blocking = false then
        Debug("command not defined: " + tostr(button.command) + " - closing dialog")
    end if
    m.Close()
end sub

' Common shared dialogs
function VideoResumeDialog(item as object, screen as object) as dynamic
    dialog = createDialog(item.GetLongerTitle(), invalid, screen)
    dialog.AddButton("Resume from " + item.GetViewOffset(), true)
    dialog.AddButton("Play from beginning", false)
    dialog.Show(true)
    return dialog.result
end function

sub dialogOnKeyRelease(keyCode as integer)
    ' Consider the PLAY button the same as OK
    if keyCode = m.kp_PLAY then
        keyCode = m.kp_OK
    end if
    ApplyFunc(OverlayClass().OnKeyRelease, m, [keyCode])
end sub
