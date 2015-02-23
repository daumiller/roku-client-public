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
        obj.Replace = imageReplace

        m.ImageClass = obj
    end if

    return m.ImageClass
end function

function imageDraw() as object
    if m.bitmap <> invalid then
        ' Nothing to do, region should already be set based on bitmap
    else if m.sourceOrig = invalid then
        ' allow an empty placeholder
        m.bgColor = Colors().Transparent
        m.InitRegion()
    else if type(m.sourceOrig) = "roAssociativeArray" or left(m.source, 4) = "http" then
        ' case sensitive AA only works by setting with aa["caseSensitive"]
        transcodeOpts = createObject("roAssociativeArray")
        transcodeOpts["minSize"] = 1
'        transcodeOpts["upscale"] = 1
        if m.transcodeOpts <> invalid then transcodeOpts.Append(m.transcodeOpts)
        width = firstOf(m.preferredWidth, m.width)
        height = firstOf(m.preferredHeight, m.height)

        ' If a cache for the current source exists, lets use it for the initial region.
        if m.cache = true and IsString(m.source) then
            m.region = TextureManager().GetCache(m.source, width, height)
        end if

        if m.region = invalid then
            if m.placeholder <> invalid then
                ' Draw the placeholder for now, but don't keep a reference to the bitmap.
                m.FromLocal(m.placeholder)
            else
                ' Just do the basic region initialization until we get a real bitmap.
                m.InitRegion()
            end if
        end if

        ' images look a lot better resized from a larger source.
        if m.useLargerSource and width < 1280 and height < 720 then
            multiplier = 1.5
        else
            multiplier = 1
        end if

        m.oldSource = m.source
        if type(m.sourceOrig) = "roAssociativeArray" then
            if m.thumbAttr = invalid then
                ' Choose an attribute based on orientation
                if m.orientation = m.ORIENTATION_SQUARE then
                    m.thumbAttr = ["composite", "thumb", "art"]
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

        doRequest = true
        ' Lets verify if our oldSource is a url, and either unload it from the texture manager
        ' if the new request differs, or ignore the request if it's the same source.
        if IsString(m.oldSource) then
            if m.oldSource <> tostr(m.source) then
                TextureManager().RemoveTexture(m.oldSource, true)
            else
                doRequest = not (m.isReplacement = true)
            end if
        end if
        m.isReplacement = invalid

        ' Request texture through the TextureManager
        if doRequest then
            context = {
                url: m.source,
                width: width,
                height: height,
                ' Do not scale size within the texture manager. We need the true dimensions to
                ' use our own scaling methods (zoom-to-fill).
                ' scaleSize: m.scaleSize,
                ' scaleMode: 1
            }

            ' Use a cached image if applicable or send or create a request
            imageCache = TextureManager().GetCache(m.source, width, height)
            if imageCache <> invalid then
                m.region = imageCache
            else
                TextureManager().RequestTexture(m, context)
            end if
        else
            Debug("Ignore request for unmodified image replacement")
        end if
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

function createImage(source as dynamic, width=0 as integer, height=0 as integer, options=invalid as dynamic, scaleMode="zoom-to-fill" as string) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ImageClass())

    obj.Init()

    obj.source = source
    obj.sourceOrig = obj.source
    obj.width = width
    obj.height = height
    obj.scaleSize = true
    obj.scaleMode = scaleMode
    obj.scaleToLayout = false
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

sub imageSetBitmap(bmp=invalid as dynamic, makeCopy=false as boolean)
    perfTimer().mark()

    ' Handle TextureManager failures by clearing the bitmap
    if bmp = invalid then
        Debug("Invalid bitmap: set empty")
        bmp = CreateObject("roBitmap", {width: m.GetPreferredWidth(), height: m.GetPreferredHeight(), alphaEnable: false})
        bmp.Clear(Colors().Empty)
        if m.fade = true then m.ignoreFade = true
    end if

    if makeCopy then
        m.region = invalid
        m.bitmap = CreateObject("roBitmap", {width: bmp.GetWidth(), height: bmp.GetHeight(), alphaEnable: false})
        m.bitmap.DrawObject(0, 0, bmp)
        msg = "makeCopy"
    else if m.scaleSize = false or m.region <> invalid and (m.region.GetWidth() <> bmp.GetWidth() or m.region.GetHeight() <> bmp.GetHeight()) then
        m.region = invalid
        m.bitmap = bmp
        ' allow the bitmap to override the requested size (media flags - unknown dimensions)
        if m.scaleSize = false then
            m.preferredWidth = bmp.GetWidth()
            m.preferredHeight = bmp.GetHeight()
            msg = "use original bitmap and size"
        else
            msg = "invalidate region and resize bitmap"
        end if
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

    ' Use our own scaling methods: zoom-to-fill, scale-to-fill, etc.
    if m.scaleToLayout then
        m.ScaleRegion(m.width, m.height)
        m.bitmap = m.region.GetBitmap()
    else if m.scaleSize then
        m.ScaleRegion(firstOf(m.preferredWidth, m.width), firstOf(m.preferredHeight, m.height))
        m.bitmap = m.region.GetBitmap()
    end if

    ' Let whoever cares layout the component again.
    m.Trigger("performParentLayout", [m])

    ' Cache the region if applicable
    if m.cache = true then
        TextureManager().SetCache(m.region, m.source)
    end if

    ' Let whoever cares know that we should be redrawn.
    if m.fade = true then
        ' Ignore any fad-in if the source has already been transitioned
        if m.ignoreFade = true or (m.lastFadeSource <> invalid and m.lastFadeSource = m.source) then
            m.ignoreFade = invalid
            m.Trigger("redraw", [m])
        else
            m.lastFadeSource = m.source
            orig = createobject("roBitmap", {width: m.region.GetWidth(), height: m.region.GetHeight(), AlphaEnable: false})
            orig.DrawObject(0, 0, m.region)
            m.region.DrawObject(0, 0, orig, -256)
            incr = 20
            for fade = -256 to 0 step incr
                if abs(fade) < incr then fade = -1
                m.region.DrawObject(0, 0, orig, fade)
                m.Trigger("redraw", [m])
            end for
        end if
    else
        m.Trigger("redraw", [m])
    end if
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

        ' zoom-to-fill: scales/crops image to maintain aspect ratio and completely fill requested dimensions.
        if m.scaleMode = "zoom-to-fill" and scaleX <> scaleY then
            if scaleX <> 1 and scaleY <> 1 then
                scale = iif(scaleX > scaleY, scaleX, scaleY)
                ratioX = abs(1 - 1/scaleX)
                ratioY = abs(1 - 1/scaleY)
                ratio = iif(ratioX > ratioY, ratioX, ratioY)
            else
                scale = iif(scaleX <> 1, scaleX, scaleY)
                ratio = abs(1 - 1/scale)
            end if

            ' allow a 5% stretch to fill
            if ratio <= .05 then
                scaledRegion.DrawScaledObject(0, 0, scaleX, scaleY, m.region)
            ' move (crop) image to center
            else if scale < 1 then
                x = cint((width - m.region.GetWidth()) / 2)
                y = cint((height - m.region.GetHeight()) / 2)
                scaledRegion.DrawObject(x, y, m.region)
            ' upscale image and center
            else
                x = cint((width - m.region.GetWidth()*scale) / 2)
                y = cint((height - m.region.GetHeight()*scale) / 2)
                scaledRegion.DrawScaledObject(x, y, scale, scale, m.region)
            end if
        ' scale-to-fit: scale image to completely fill requested dimensions. Default for any image needing
        ' to be scaled having identical X/Y multipliers. [fallback scaling method]
        else
            scaledRegion.DrawScaledObject(0, 0, scaleX, scaleY, m.region)
        end if

        m.region = scaledRegion
    end if
end sub

' Method to replace and image and correctly handle memory cleanup
sub imageReplace(item as object)
    if type(item) <> "roAssociativeArray" then
        Fatal("Replace only handles plex objects")
    end if

    m.isReplacement = true
    m.bitmap = invalid
    m.sourceOrig = item
    m.Draw()
end sub
