function DialogScreenClass() as object
    if m.DialogScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.Show = dialogscreenShow
        obj.OnOverlayClose = dialogscreenOnOverlayClose
        obj.GetComponents = dialogscreenGetComponents

        obj.screenName = "Dialog Screen"

        m.DialogScreen = obj
    end if

    return m.DialogScreen
end function

function createDialogScreen(title as string, text as dynamic, item=invalid as dynamic, onBackButton=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(DialogScreenClass())

    obj.Init()

    obj.item = item
    obj.onBackButton = onBackButton
    obj.dialog = createDialog(title, text, obj)
    obj.dialog.On("close", createCallable("OnOverlayClose", obj))

    return obj
end function

sub dialogscreenShow(blocking=true as boolean)
    ApplyFunc(ComponentsScreen().Show, m)
    m.dialog.show(blocking)
end sub

sub dialogscreenOnOverlayClose(overlay as object, backButton as boolean)
    ' close the dialog screen when the dialog closes.
    Application().popScreen(m)

    ' execute the backbutton callable if applicable
    if backButton and m.onBackButton <> invalid then
        m.onBackButton.Call()
    end if
end sub

sub dialogscreenGetComponents()
    m.DestroyComponents()
    m.focusedItem = invalid
    if m.item <> invalid then
        background = createBackgroundImage(m.item, true, false)
        m.components.Push(background)
    end if
end sub
