function ImageClass() as object
   if m.ImageClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "Image"

        obj.Draw = imageDraw
        obj.ScaleRegion = imageScaleRegion

        obj.FromUrl = imageFromUrl
        obj.FromLocal = imageFromLocal

        m.ImageClass = obj
    end if

    return m.ImageClass
end function

function imageDraw() as object
    if instr(1, type(m.source), "String") > 0 then
        if left(m.source, 4) = "http" then
            m.FromUrl()
        else
            m.FromLocal()
        end if
    ' TODO(rob) not sure if this is needed anymore.
    else if type(m.source) = "roRegion" then
        m.region = m.source
    end if

    return [m]
end function

function createImage(source as dynamic, width=0 as integer, height=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ImageClass())

    obj.Init()

    obj.source = source
    obj.width = width
    obj.height = height

    return obj
end function

' TODO(rob) how to handle urls (TextureManger)
' Previous code, we'd create a blank region for the tmanager to replace.
sub imageFromUrl()
    m.InitRegion()
end sub

sub imageFromLocal()
    bmp = CreateObject("roBitmap", m.source)
    m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
    m.ScaleRegion(m.width, m.height)
end sub

sub imageScaleRegion(width as integer, height as integer)
    scaleX = width/m.region.GetWidth()
    scaleY = height/m.region.GetHeight()

    if scaleX <> 1 or scaleY <> 1 then
        m.region.SetScaleMode(1)

        scaledBitmap = createobject("roBitmap", {width: width, height: height, AlphaEnable: false})
        scaledRegion = CreateObject("roRegion", scaledBitmap, 0, 0, scaledBitmap.GetWidth(), scaledBitmap.GetHeight())

        scaledRegion.DrawScaledObject(0, 0, scaleX, scaleY, m.region)
        m.region = scaledRegion
    end if
end sub
