function Colors() as object
    if m.Colors = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.ToHexString = colorsToHexString
        obj.GetAlpha = colorsGetAlpha

        ' Constants
        obj.Background = &h111111ff

        obj.OverlayVeryDark = obj.GetAlpha(&h000000ff, 90)
        obj.OverlayDark = obj.GetAlpha(&h000000ff, 70)
        obj.OverlayMed = obj.GetAlpha(&h000000ff, 50)
        obj.OverlayLht = obj.GetAlpha(&h000000ff, 35)

        obj.Empty = &h1f1f1fff
        obj.Card = &h1f1f1fff
        obj.Button = &h1f1f1fff
        obj.ButtonDark = &h171717ff
        obj.ButtonLht = &h555555ff
        obj.ButtonMed = &h2d2d2dff
        obj.Indicator = &h999999ff
        obj.Text = &hffffffff
        obj.Subtitle = &h999999ff

        ' These are dependent on the regions background color
        obj.TextLht = obj.GetAlpha(&hffffffff, 90)
        obj.TextMed = obj.GetAlpha(&hffffffff, 75)
        obj.TextDim = obj.GetAlpha(&hffffffff, 50)

        obj.Transparent = &h00000000
        obj.Black = &h000000ff
        obj.Blue = &h0033ccff
        obj.Red = &hc23529ff
        obj.RedAlt = &hd9534fff
        obj.Green = &h5cb85cff
        obj.Orange = &hcc7b19ff
        obj.OrangeLight = &hf9be03ff

        ' Component specific
        obj.ScrollbarBg = obj.GetAlpha(&hffffffff, 10)
        obj.ScrollbarFg = obj.GetAlpha(obj.Orange, 40)
        obj.IndicatorBorder = obj.Black
        obj.Separator = obj.Black

        m.Colors = obj
    end if

    return m.Colors
end function

function colorsToHexString(key as string, alpha=false as boolean)
    return IntToHex(m[key], alpha)
end function

function colorsGetAlpha(color as dynamic, percent as integer) as integer
    if IsString(color) then color = m[color]
    if not IsInteger(color) then
        Fatal(tostr(color) + " is not found in object")
    end if

    return color and int((percent/100 * 255) - 256)
end function
