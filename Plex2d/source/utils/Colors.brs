function Colors() as object
    if m.Colors = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.ScrVeryDrkOverlayClr = &h000000e0
        obj.ScrDrkOverlayClr = &h000000b0
        obj.ScrMedOverlayClr = &h00000080
        obj.ScrLhtOverlayClr = &h00000060
        obj.ScrBkgClr = &h111111FF
        obj.ScrBtnClr = &h1F1F1FFF
        obj.PlexClr = &hff8a00ff
        obj.PlexClrTran = &hff8a0000
        obj.CardBkgClr = &h272727ff
        obj.BtnBkgClr = &h272727ff

        m.Colors = obj
    end if

    return m.Colors
end function
