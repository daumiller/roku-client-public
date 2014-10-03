function ModalClass() as object
    if m.ModalClass = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.ClassName = "Modal"
        obj.Init = modalInit
        obj.Show = modalShow
        obj.Destroy = modalDestroy

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
    m.textClr = Colors().TextClr
    m.bkgClr = Colors().ScrDrkOverlayClr
    m.font = FontRegistry().GetTextFont(18, false)

    m.components = createObject("roList")
end sub

sub modalDestroy()
    for each comp in m.components
        comp.Destroy()
    end for
    m.components.clear()
    m.font = invalid
end sub

sub modalShow()
    modal = createLabel(m.title, m.font)
    modal.SetPadding(m.padding)
    modal.SetColor(m.textClr, m.bkgClr)
    modal.halign = modal.JUSTIFY_CENTER
    modal.valign = modal.ALIGN_MIDDLE
    modal.zOrder = 100
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

    ' Destroy the modal components now (one-time use)
    m.destroy()
end sub
