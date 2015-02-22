function Colors() as object
    if m.Colors = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.ToHexString = colorsToHexString
        obj.GetAlpha = colorsGetAlpha

        ' Constants
        obj.Background = &h111111ff

        obj.OverlayVeryDark = &h000000e0
        obj.OverlayDark = &h000000b0
        obj.OverlayMed = &h00000080
        obj.OverlayLht = &h00000060

        obj.Empty = &h1f1f1fff
        obj.Card = &h1f1f1fff
        obj.Button = &h1f1f1fff
        obj.Indicator = &h999999ff
        obj.ButtonDark = &h171717ff
        obj.Text = &hffffffff
        obj.Subtitle = &h999999ff

        ' These are dependent on the regions background color
        obj.TextLight = &hffffffe0
        obj.TextDim = &hffffff60

        obj.Transparent = &h00000000
        obj.Black = &h000000ff
        obj.Blue = &h0033CCff
        obj.Red = &hc23529ff
        obj.Green = &h5cb85cff
        obj.Orange = &hcc7b19ff
        obj.OrangeLight = &hf9be03ff

        ' Component specific
        obj.ScrollbarBg = &hffffff10
        obj.ScrollbarFg = obj.Orange and &hffffff60
        obj.IndicatorBorder = obj.Black

        m.Colors = obj
    end if

    return m.Colors
end function

function colorsToHexString(key as string, alpha=false as boolean)
    return IntToHex(m[key], alpha)
end function

function colorsGetAlpha(color as dynamic, percent as integer) as integer
    if IsInteger(color) then
        return color and int(percent/100 * 255) - 255
    else if m[color] = invalid then
        Fatal(color + " is not found in object")
    end if
    return m[color] and int(percent/100 * 255) - 255
end function
