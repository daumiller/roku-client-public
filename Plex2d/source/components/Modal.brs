function ModalClass() as object
    if m.ModalClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        obj.ClassName = "Modal"
        obj.Init = modalInit
        obj.Show = modalShow
        obj.Close = modalClose

        m.ModalClass = obj
    end if

    return m.ModalClass
end function

function createLoadingModal(screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ModalClass())

    obj.screen = screen

    obj.Init("Loading...")

    return obj
end function

function createModal(title as string, screen as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ModalClass())

    obj.screen = screen

    obj.Init(title)

    return obj
end function

sub modalInit(title as string)
    m.title = "Loading..."
    m.padding = 25
    m.font = FontRegistry().LARGE

    m.components = createObject("roList")
end sub

sub modalShow()
    modal = createLabel(m.title, m.font)
    modal.SetPadding(m.padding)
    modal.SetColor(Colors().Text, Colors().Modal)
    modal.halign = modal.JUSTIFY_CENTER
    modal.valign = modal.ALIGN_MIDDLE
    modal.zOrder = ZOrders().MODAL
    modal.roundedCorners = true
    m.components.push(modal)

    ' set the modal in the center of the screen.
    width = modal.GetPreferredWidth()
    height = modal.GetPreferredHeight()
    x = int(1280/2 - width/2)
    y = int(720/2 - height/2)
    modal.SetFrame(x, y, width, height)

    for each comp in m.components
        CompositorScreen().DrawComponent(comp)
    end for

    ' Draw the modal to the screen
    m.screen.screen.DrawAll()
end sub

sub modalClose()
    m.Destroy()
end sub
