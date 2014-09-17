function ImageClass() as object
   if m.ImageClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.Append(AlignmentMixin())
        obj.ClassName = "Image"

        obj.Draw = imageDraw
        obj.ScaleRegion = imageScaleRegion

        obj.SetBitmap = imageSetBitmap
        obj.SetPlaceholder = imageSetPlaceholder
        obj.FromLocal = imageFromLocal

        m.ImageClass = obj
    end if

    return m.ImageClass
end function

function imageDraw() as object
    if m.bitmap <> invalid then
        ' Nothing to do, region should already be set based on bitmap
    else if left(m.source, 4) = "http" then
        if m.placeholder <> invalid then
            ' Draw the placeholder for now, but don't keep a reference to the bitmap.
            m.FromLocal(m.placeholder)
        else
            ' Just do the basic region initialization until we get a real bitmap.
            m.InitRegion()
        end if

        ' Request texture through the TextureManager
        context = {
            url: m.source,
            width: firstOf(m.preferredWidth, m.width),
            height: firstOf(m.preferredHeight, m.height),
            scaleSize: true,
            scaleMode: 1
        }
        TextureManager().RequestTexture(m, context)
    else
        m.bitmap = m.FromLocal(m.source)
    end if

    if m.preferredWidth <> invalid and m.preferredHeight <> invalid then
        m.offsetX = m.GetXOffsetAlignment(m.preferredWidth)
        m.offsetY = m.GetYOffsetAlignment(m.preferredHeight)
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

    obj.bitmap = invalid
    obj.placeholder = invalid

    if width > 0 and height > 0 then
        obj.preferredWidth = width
        obj.preferredHeight = height
    end if

    return obj
end function

function imageFromLocal(source as string) as dynamic
    bmp = CreateObject("roBitmap", source)

    if bmp <> invalid then
        m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
        m.ScaleRegion(firstOf(m.preferredWidth, m.width), firstOf(m.preferredHeight, m.height))
        bmp = m.region.GetBitmap()
    else
        Error("Failed to load local image at " + source)
        m.InitRegion()
    end if

    return bmp
end function

sub imageSetBitmap(bmp as object, makeCopy=true as boolean)
    if makeCopy then
        m.bitmap = CreateObject("roBitmap", {width: bmp.GetWidth(), height: bmp.GetHeight(), alphaEnable: false})
        m.bitmap.DrawObject(0, 0, bmp)
    else
        m.bitmap = bmp
    end if

    m.region = CreateObject("roRegion", m.bitmap, 0, 0, m.bitmap.GetWidth(), m.bitmap.GetHeight())
    m.ScaleRegion(firstOf(m.preferredWidth, m.width), firstOf(m.preferredHeight, m.height))
    m.bitmap = m.region.GetBitmap()

    ' Let whoever cares know that we should be redrawn.
    m.Trigger("redraw", [m])
end sub

sub imageSetPlaceholder(source as string)
    m.placeholder = source
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
