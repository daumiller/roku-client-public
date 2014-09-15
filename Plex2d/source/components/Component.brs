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
        obj.fgColor = Colors().TextClr

        ' Methods
        obj.Init = function() :end function
        obj.InitRegion = compInitRegion
        obj.Draw = compDraw
        obj.GetCenterOffsets = compGetCenterOffsets
        obj.GetPreferredWidth = compGetPreferredWidth
        obj.GetPreferredHeight = compGetPreferredHeight
        obj.SetFrame = compSetFrame

        m.ComponentClass = obj
    end if

    return m.ComponentClass
end function

sub compInitRegion()
    bmp = CreateObject("roBitmap", {width: m.width, height: m.height, alphaEnable: m.alphaEnable})
    bmp.Clear(m.bgColor)

    m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
end sub

function compDraw() as object
    m.InitRegion()

    return [{x: m.x, y: m.y, region: m.region}]
end function

function compGetCenterOffsets(width as integer, height as integer) as object
    coords = { x: 0, y: 0 }
    coords.x = int(m.width / 2 - width / 2)
    coords.y = int(m.height / 2 - height / 2)
    return coords
end function

function compGetPreferredWidth() as integer
    return m.width
end function

function compGetPreferredHeight() as integer
    return m.height
end function

sub compSetFrame(x as integer, y as integer, width as integer, height as integer)
    m.x = x
    m.y = y
    m.width = width
    m.height = height
end sub
