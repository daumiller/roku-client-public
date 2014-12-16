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
    else if type(m.sourceOrig) = "roAssociativeArray" or left(m.source, 4) = "http" then
        if m.placeholder <> invalid then
            ' Draw the placeholder for now, but don't keep a reference to the bitmap.
            m.FromLocal(m.placeholder)
        else
            ' Just do the basic region initialization until we get a real bitmap.
            m.InitRegion()
        end if

        transcodeOpts = { minSize: 1 }
        if m.transcodeOpts <> invalid then transcodeOpts.Append(m.transcodeOpts)
        width = firstOf(m.preferredWidth, m.width)
        height = firstOf(m.preferredHeight, m.height)

        ' images look a lot better resized from a larger source.
        if m.useLargerSource and width < 1280 and height < 720 then
            multiplier = 1.5
        else
            multiplier = 1
        end if

        if type(m.sourceOrig) = "roAssociativeArray" then
            if m.thumbAttr = invalid then
                ' Choose an attribute based on orientation
                if m.orientation = m.ORIENTATION_SQUARE then
                    m.thumbAttr = ["composite", "art", "thumb"]
                else if m.orientation = m.ORIENTATION_LANDSCAPE then
                    m.thumbAttr = ["art", "thumb"]
                end if
            end if

            if m.thumbAttr <> invalid then
                m.source = m.sourceOrig.GetImageTranscodeURL(m.thumbAttr, int(multiplier * width), int(multiplier * height), transcodeOpts)
            else
                m.source = m.sourceOrig.GetPosterTranscodeURL(int(multiplier * width), int(multiplier * height), transcodeOpts)
            end if
        else if instr(1, m.sourceOrig, "/photo/:/transcode") = 0 then
            server = PlexServerManager().GetTranscodeServer()
            if server <> invalid then
                m.source = server.GetImageTranscodeURL(m.sourceOrig, width, height, transcodeOpts)
            end if
        end if

        ' Request texture through the TextureManager
        context = {
            url: m.source,
            width: width,
            height: height,
            scaleSize: m.scaleSize,
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

function createImageScaleToParent(source as dynamic, parent as object) as object
    ' create a 1x1 image to handle creating a temporary regions
    ' for the downloaded image to replace.
    obj = createImage(source, 1, 1)
    obj.scaleSize = false
    obj.On("performParentLayout", createCallable("OnParentLayout", parent))
    return obj
end function

function createImage(source as dynamic, width=0 as integer, height=0 as integer, options=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ImageClass())

    obj.Init()

    obj.source = source
    obj.sourceOrig = obj.source
    obj.width = width
    obj.height = height
    obj.scaleSize = true
    obj.useLargerSource = false

    obj.bitmap = invalid
    obj.placeholder = invalid

    if width > 0 and height > 0 then
        obj.preferredWidth = width
        obj.preferredHeight = height
    end if

    if options <> invalid then
        obj.transcodeOpts = options
    end if

    return obj
end function

function imageFromLocal(source as string) as dynamic
    bmp = CreateObject("roBitmap", source)

    if bmp <> invalid then
        m.region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
        if m.scaleSize then
            m.ScaleRegion(firstOf(m.preferredWidth, m.width), firstOf(m.preferredHeight, m.height))
            bmp = m.region.GetBitmap()
        else
            m.preferredWidth = bmp.GetWidth()
            m.preferredHeight = bmp.GetHeight()
        end if
    else
        Error("Failed to load local image at " + source)
        m.InitRegion()
    end if

    return bmp
end function

sub imageSetBitmap(bmp as object, makeCopy=false as boolean)
    perfTimer().mark()

    if makeCopy then
        m.region = invalid
        m.bitmap = CreateObject("roBitmap", {width: bmp.GetWidth(), height: bmp.GetHeight(), alphaEnable: false})
        m.bitmap.DrawObject(0, 0, bmp)
        msg = "makeCopy"
    else if m.scaleSize = false or m.region <> invalid and (m.region.GetWidth() <> bmp.GetWidth() or m.region.GetHeight() <> bmp.GetHeight()) then
        m.region = invalid
        m.bitmap = bmp
        m.preferredWidth = bmp.GetWidth()
        m.preferredHeight = bmp.GetHeight()
        msg = "use original bitmap and size"
    else if m.region <> invalid then
        m.region.DrawObject(0, 0, bmp)
        m.bitmap = m.region.GetBitMap()
        msg = "clear and reuse region"
    else
        m.bitmap = bmp
        msg = "use original"
    end if
    perfTimer().Log("imageSetBitmap::" + msg)

    ' create a region if invalid
    if m.region = invalid then
        m.region = CreateObject("roRegion", m.bitmap, 0, 0, m.bitmap.GetWidth(), m.bitmap.GetHeight())
        perfTimer().Log("imageSetBitmap:: init new region")
    end if

    ' TODO(rob) we shouldn't need to scale here as the TextureManager handles
    ' scaling now. I'll verify this once we start loading real images.
    if m.scaleSize then
        m.ScaleRegion(firstOf(m.preferredWidth, m.width), firstOf(m.preferredHeight, m.height))
        m.bitmap = m.region.GetBitmap()
    end if

    ' Let whoever cares know that we should be redrawn.
    m.Trigger("redraw", [m])

    ' Let whoever cares layout the component again.
    m.Trigger("performParentLayout", [m])
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
