function Colors() as object
    if m.Colors = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.ToHexString = colorsToHexString

        ' Constants
        obj.Background = &h111111ff

        obj.OverlayVeryDark = &h000000e0
        obj.OverlayDark = &h000000b0
        obj.OverlayMed = &h00000080
        obj.OverlayLht = &h00000060

        obj.Empty = &h1f1f1fff
        obj.Card = &h1f1f1fff
        obj.Button = &h1f1f1fff
        obj.Text = &hffffffff
        obj.TextLight = &hffffffe0
        obj.TextDim = &hffffff60

        obj.Transparent = &h00000000
        obj.Black = &h000000ff
        obj.Red = &hc23529ff
        obj.Green = &h5cb85cff
        obj.Orange = &hcc7b19ff
        obj.OrangeLight = &hf9be03ff

        ' Component specific
        obj.ScrollbarBg = &hffffff10
        obj.ScrollbarFg = obj.Orange and &hffffff60

        m.Colors = obj
    end if

    return m.Colors
end function

function colorsToHexString(key as string, alpha=false as boolean)
    return IntToHex(m[key], alpha)
end function
