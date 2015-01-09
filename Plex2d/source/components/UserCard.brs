function UserCardClass() as object
    if m.UserCardClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.ClassName = "UserCard"

        obj.alphaEnable = true
        obj.multiBitmap = true

        obj.Init = usercardInit
        obj.InitComponents = usercardInitComponents
        obj.PerformLayout = usercardPerformLayout

        m.UserCardClass = obj
    end if

    return m.UserCardClass
end function

function createUserCard(user as object, font as object, command=invalid as dynamic)
    obj = CreateObject("roAssociativeArray")
    obj.Append(UserCardClass())

    obj.user = user
    obj.spacing = 10

    obj.Init()

    obj.SetFocusable(command)

    return obj
end function

sub usercardInit()
    ApplyFunc(CompositeClass().Init, m)
    m.InitComponents()
end sub

sub usercardInitComponents()
    ' blur hack (could use some tuning)
    m.bkg = createImage(m.user.thumb + "?rw=5&rh=5", 8, 8)
    m.bkg.scaleToLayout = true
    m.AddComponent(m.bkg)

    ' dim background image
    m.bkgDimmer = createBlock(Colors().OverlayDark)
    m.AddComponent(m.bkgDimmer)

    ' user title
    m.title = createLabel(firstOf(m.user.title, ""), FontRegistry().font16)
    m.title.SetPadding(5, 0, 5, 0)
    m.title.SetColor(Colors().Text, &h00000070)
    m.title.halign = m.title.JUSTIFY_CENTER
    m.AddComponent(m.title)

    ' thumb image
    m.bkgThumb = createBlock(&hfffffff20)
    m.AddComponent(m.bkgThumb)
    thumb = iif(instr(1, m.user.thumb, "gravatar") > 0, m.user.thumb + "&s=125", m.user.thumb)
    m.thumb = createImage(thumb, 125, 125)
    m.AddComponent(m.thumb)

    ' check mark
    if m.user.isSelected = true then
        m.checkMark = createLabel(Glyphs().CHECK, FontRegistry().GetIconFont(16))
        m.checkMark.SetPadding(5, 10, 0, 10)
        m.checkMark.SetColor(Colors().Text)
        m.AddComponent(m.checkMark)
    end if

    ' user PIN protected
    if m.user.protected = "1" then
        m.pin = createLabel(Glyphs().LOCK, FontRegistry().GetIconFont(16))
        m.pin.SetPadding(0, 10, 5, 10)
        m.pin.SetColor(Colors().Green)
        m.AddComponent(m.pin)
    else
        m.pin = createLabel(Glyphs().UNLOCK, FontRegistry().GetIconFont(16))
        m.pin.SetPadding(0, 10, 5, 10)
        m.pin.SetColor(Colors().TextDim)
        m.AddComponent(m.pin)
    end if

    ' user is ADMIN (crown)
    if m.user.admin = "1" then
        m.crown = createLabel(Glyphs().CROWN, FontRegistry().GetIconFont(16))
        m.crown.SetPadding(0, 10, 5, 10)
        m.crown.SetColor(Colors().OrangeLight)
        m.AddComponent(m.crown)
    end if
end sub

sub usercardPerformLayout()
    m.needsLayout = false

    ' background image and dimmer
    m.bkg.SetFrame(0, 0, m.width, m.height)
    m.bkgDimmer.SetFrame(0, 0, m.width, m.height)

    ' user thumb and dimmer
    border = int((m.thumb.height * .03) + .5)
    xOffset = int((m.width - m.thumb.width) / 2)
    yOffset = int((m.height - m.thumb.height) / 2) - (m.title.GetPreferredHeight() / 2)
    m.thumb.SetFrame(xOffset, yOffset, m.thumb.width, m.thumb.height)
    m.bkgThumb.SetFrame(xOffset - border, yOffset - border, m.thumb.width + (border * 2), m.thumb.height + (border * 2))

    ' user title
    m.title.SetFrame(0, m.height - m.title.GetPreferredHeight(), m.width, m.title.GetPreferredHeight())

    ' selected user / check mark
    if m.checkMark <> invalid then
        m.checkMark.SetFrame(0 + m.width - m.checkMark.GetPreferredWidth(), 0, m.checkMark.GetPreferredWidth(), m.checkMark.GetPreferredHeight())
    end if

    ' Pin (image)
    if m.pin <> invalid then
        m.pin.SetFrame(0, m.height - m.pin.GetPreferredHeight() - m.title.GetPreferredHeight(), m.width, m.pin.GetPreferredHeight())
    end if

    ' Admin (image)
    if m.crown <> invalid then
        m.crown.SetFrame(m.width - m.crown.GetPreferredWidth(), m.height - m.crown.GetPreferredHeight() - m.title.GetPreferredHeight(), m.width, m.crown.GetPreferredHeight())
    end if
end sub
