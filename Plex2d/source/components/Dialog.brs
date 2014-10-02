' Dialog Screen is Special - it builds on top of an existing ComponentsScreen
function DialogClass() as object
    if m.DialogClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.ClassName = "DialogClass"

        obj.HandleButton = dialogHandleButton

        ' Methods
        obj.SetFrame = compSetFrame
        obj.Show = dialogShow
        obj.Close = dialogClose
        obj.Init = dialogInit
        obj.AddButton = dialogAddButton
        obj.CreateButton = dialogCreateButton

        m.DialogClass = obj
    end if

    return m.DialogClass
end function

function createDialog(title as string, text as string, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DialogClass())

    obj.screen = screen

    ' remeber the current focus and invalid it
    obj.fromFocusedItem = screen.focusedItem
    screen.lastFocusedItem = invalid
    screen.FocusedItem = invalid

    obj.Init(title, text)

    return obj
end function

sub dialogHandleButton(button as object)
    Debug("dialog button selected with command: " + tostr(button.command))

    if button.command = "close" then
        m.Close()
    else
        Debug("command not defined: (closing dialog now) " + tostr(button.command))
        m.Close()
    end if
end sub

sub dialogButtonOnSelected()
    m.dialog.HandleButton(m)
end sub

sub dialogInit(title as string, text as string)
    ' TODO(rob) should this be unique? I am assuming dialogs should NOT stack
    m.components = m.screen.GetManualComponents(m.ClassName)
    m.buttons = []
    m.title = title
    m.text = text

    ' TODO(rob) how do we handle dynamic width/height along with center placment?
    m.width = 500
    m.height = 225
    m.x = int(1280/2 - m.width/2)
    m.y = int(720/2 - m.height/2)

    m.spacing = 25
    m.customFonts = {
        buttonFont: FontRegistry().font16
        titleFont:  FontRegistry().font18b
        textFont:  FontRegistry().font18
    }
end sub

function dialogClose() as boolean
    for each comp in m.components
        comp.Destroy()
    end for
    m.components.clear()
    m.customFonts.clear()

    ' draw the previous focused item we came from before the dialog
    m.screen.lastFocusedItem = invalid
    m.screen.FocusedItem = m.fromFocusedItem
    m.screen.screen.DrawFocus(m.screen.focusedItem, true)
end function

sub dialogShow()
    dialogBox = createVBox(false, false, false, m.spacing)
    dialogBox.SetFrame(m.x, m.y, m.width, m.height)

    if m.title <> invalid then
        label = createLabel(m.title, m.customFonts.titleFont)
        label.SetPadding(int(m.spacing/2))
        label.halign = label.JUSTIFY_CENTER
        label.valign = label.ALIGN_MIDDLE
        label.zOrder = 100
        dialogBox.AddComponent(label)
    end if

    ' TODO(rob) how do we allow the labels height to be "auto" based
    ' on the amount of text, maybe including a "maxHeight"
    if m.text <> invalid then
        label = createLabel(m.text, m.customFonts.textFont)
        label.SetPadding(int(m.spacing/2))
        label.halign = label.JUSTIFY_CENTER
        label.valign = label.ALIGN_MIDDLE
        label.zOrder = 100
        dialogBox.AddComponent(label)
    end if

    ' Add buttons - or - add OK button if none exist
    if m.buttons.count() = 0 then
        btn = m.createButton("OK", "close")
        btn.zOrder = 100
        dialogBox.AddComponent(btn)
    else
        for each button in m.buttons
            btn = m.createButton(button.text, button.command)
            btn.zOrder = 100
            dialogBox.AddComponent(btn)
        end for
    end if

    m.components.push(dialogBox)

    ' TODO(rob) determine width/height of dialogBox, center the box,
    ' and add the background layer. We can forgo the zOrder by
    ' if we unshift instead of push the bkg.
    bkg = createBlock(Colors().ScrVeryDrkOverlayClr)
    bkg.SetFrame(m.x, m.y, m.width, m.height)
    bkg.zOrder = 99
    m.components.push(bkg)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    m.screen.screen.DrawFocus(m.screen.focusedItem, true)
end sub

sub dialogAddButton(text as string, command as dynamic) as object
    m.buttons.push({text: text, command: command})
end sub

function dialogCreateButton(text as string, command as dynamic) as object
    btn = createButton(text, m.customFonts.buttonFont, command)
    btn.SetColor(&hffffffff, &h1f1f1fff)
    btn.width = 72
    btn.height = 44
    btn.fixed = true

    ' special properties for the dialog buttons
    btn.focusNonSiblings = false
    btn.dialog = m
    btn.OnSelected = dialogButtonOnSelected

    if m.screen.focusedItem = invalid then m.screen.focusedItem = btn

    return btn
end function
