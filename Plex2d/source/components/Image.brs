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

        ' TODO(rob/schuyler) proper image transcoding
        width = firstOf(m.preferredWidth, m.width)
        height = firstOf(m.preferredHeight, m.height)
        if m.server <> invalid and m.server.supportsphototranscoding then
            transcodeOpts = { minSize: 1 }
            if m.transcodeOpts <> invalid then transcodeOpts.Append(m.transcodeOpts)
            m.source = m.server.transcodeImage(m.sourceOrig, tostr(width), tostr(height), "1f1f1f", transcodeOpts)
        else if instr(1, m.source, "roku.rarforge.com") > 0 then
            ' TODO(rob) remove this in production or when we start querying the PMS
            ' for now, we want the url to be unique to the size of the image
            m.source = m.source + "?width=" + tostr(width) + "&height=" + tostr(height)
        end if

        ' Request texture through the TextureManager
        context = {
            url: m.source,
            width: width,
            height: height,
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

    if type(source) = "roAssociativeArray" then
        obj.source = source.url
        obj.server = source.server
        obj.transcodeOpts = source.transcodeOpts
    else
        obj.source = source
    end if
    obj.sourceOrig = obj.source
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

sub imageSetBitmap(bmp as object, makeCopy=false as boolean)
    perfTimer().mark()

    if makeCopy then
        m.bitmap = CreateObject("roBitmap", {width: bmp.GetWidth(), height: bmp.GetHeight(), alphaEnable: false})
        m.bitmap.DrawObject(0, 0, bmp)
        msg = "makeCopy"
    else if m.region <> invalid then
        m.region.DrawObject(0, 0, bmp)
        m.bitmap = m.region.GetBitMap()
        msg = "clear and reuse region"
    else
        m.bitmap = bmp
        msg = "use original"
    end if
    perfTimer().Log("imageSetBitmap::" + msg)

    ' create a region if invalid or if a copy was requested
    if makeCopy or m.region = invalid then
        m.region = CreateObject("roRegion", m.bitmap, 0, 0, m.bitmap.GetWidth(), m.bitmap.GetHeight())
        perfTimer().Log("imageSetBitmap:: init new region")
    end if

    ' TODO(rob) we shouldn't need to scale here as the TextureManager handles
    ' scaling now. I'll verify this once we start loading real images.
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
