function ComponentClass() as object
    if m.ComponentClass = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Properties
        obj.x = 0
        obj.y = 0
        obj.width = 0
        obj.height = 0

        obj.alphaEnable = false
        obj.bgColor = Colors().ScrBkgClr

        ' Methods
        obj.InitRegion = compInitRegion
        obj.Draw = compDraw

        m.ComponentClass = obj
    end if

    return m.ComponentClass
end function

sub compInitRegion()
    bmp = CreateObject("roBitmap", {width: m.width, height: m.height, alphaEnable: m.alphaEnable})
    bmp.Clear(m.bgColor)

    m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
end sub

sub compDraw()
    stop
end sub
