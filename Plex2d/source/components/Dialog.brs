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
    if text <> invalid then m.text = text

    ' TODO(rob) how do we handle dynamic width/height along with center placement?
    m.width = 500
    m.height = 225
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)
    m.spacing = 25

    m.buttonPrefs = {
        width: 72,
        height: 44,
        padding: 10,
        fixed: false,
    }
    m.buttonPrefs.maxWidth = m.width - m.buttonPrefs.padding*2

    m.customFonts = {
        buttonFont: FontRegistry().font16
        titleFont:  FontRegistry().font18b
        textFont:  FontRegistry().font18
    }

    m.buttonsSingleLine = false
end sub

sub dialogGetComponents()
    dialogBox = createVBox(false, false, false, m.spacing)
    dialogBox.SetFrame(m.x, m.y, m.width, m.height)

    if m.title <> invalid then
        label = createLabel(m.title, m.customFonts.titleFont)
        label.SetPadding(int(m.spacing/2))
        label.halign = label.JUSTIFY_CENTER
        label.valign = label.ALIGN_MIDDLE
        label.zOrder = ZOrders().OVERLAY
        dialogBox.AddComponent(label)
    end if

    ' TODO(rob): how do we allow the labels height to be "auto" based
    ' on the amount of text, maybe including a "maxHeight"
    if m.text <> invalid then
        label = createLabel(m.text, m.customFonts.textFont)
        label.SetPadding(int(m.spacing/2))
        label.halign = label.JUSTIFY_CENTER
        label.valign = label.ALIGN_MIDDLE
        label.zOrder = ZOrders().OVERLAY
        dialogBox.AddComponent(label)
    end if

    if m.buttons.count() = 0 then
        dialogBox.AddComponent(m.createButton("OK", "close"))
    else
        if m.buttonsSingleLine then
            btnCont = createHBox(false, false, false, 10)
        else
            btnCont = createVBox(false, false, false, 10)
        end if
        btnCont.phalign = btnCont.JUSTIFY_CENTER

        ' resize button width based on longest text option
        for each button in m.buttons
            preferWidth = m.customFonts.buttonFont.GetOneLineWidth(button.text, m.width) + m.buttonPrefs.padding*2
            if preferWidth > m.buttonPrefs.width then m.buttonPrefs.width = preferWidth
        end for
        if m.buttonPrefs.width > m.buttonPrefs.maxWidth then m.buttonPrefs.width = m.buttonPrefs.maxWidth

        for each button in m.buttons
            button = m.createButton(button.text, button.command)
            btnCont.AddComponent(button)
        end for
        dialogBox.AddComponent(btnCont)
    end if

    m.components.push(dialogBox)

    bkg = createBlock(Colors().OverlayVeryDark)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = ZOrders().OVERLAY - 1
    m.components.push(bkg)
end sub

function dialogCreateButton(text as string, command=invalid as dynamic) as object
    btn = createButton(text, m.customFonts.buttonFont, command)
    btn.SetColor(Colors().Text, Colors().Button)
    btn.width = m.buttonPrefs.width
    btn.height = m.buttonPrefs.height
    btn.fixed = m.buttonPrefs.fixed
    btn.zOrder = ZOrders().OVERLAY
    btn.SetPadding(m.buttonPrefs.padding)
    btn.focusNonSiblings = false
    btn.dialog = m
    btn.OnSelected = dialogButtonOnSelected

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function

sub dialogAddButton(text as string, command=invalid as dynamic) as object
    m.buttons.push({text: text, command: command})
end sub

sub dialogButtonOnSelected()
    m.dialog.HandleButton(m)
end sub

sub dialogHandleButton(button as object)
    m.result = button.command
    if m.blocking = false then
        Debug("command not defined: " + tostr(button.command) + " - closing dialog")
    end if
    m.Close()
end sub
