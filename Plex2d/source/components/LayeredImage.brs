function LayeredImageClass() as object
    if m.LayeredImageClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.Append(AlignmentMixin())

        obj.ClassName = "LayeredImage"

        obj.alphaEnable = true

        ' Methods
        obj.SetFade = liSetFade
        obj.OnComponentRedraw = liOnComponentRedraw
        obj.HasPendingTextures = liHasPendingTextures
        obj.AddComponent = liAddComponent
        obj.PerformChildLayout = liPerformChildLayout

        m.LayeredImageClass = obj
    end if

    return m.LayeredImageClass
end function

function createLayeredImage(spacing=0 as integer, horizontal=false as boolean)
    obj = CreateObject("roAssociativeArray")
    obj.Append(LayeredImageClass())

    obj.Init()

    obj.halign = obj.JUSTIFY_CENTER
    obj.valign = obj.ALIGN_MIDDLE

    return obj
end function

sub liSetFade(enabled=true as boolean, percent=6 as float)
    m.fade = enabled
    if enabled then
        m.fadeSpeed = cint(percent/100 * 255)
        if m.fadeSpeed < 1 then
            m.fadeSpeed = 1
        else if m.fadeSpeed > 255 then
            m.fadeSpeed = 255
        end if
    end if
end sub

sub liOnComponentRedraw(component as object)
    ' We only allow the component to be redrawn if all texture requests
    ' are finished
    if m.HasPendingTextures() then
        Verbose("Ignore redraw for " + m.ToString() + ", it has pending textures.")
        return
    end if

    if m.fade = true then
        ' Set the fade "from" region
        fadeRegion = createobject("roBitmap", {width: m.region.GetWidth(), height: m.region.GetHeight(), AlphaEnable: false})
        fadeRegion.DrawObject(0, 0, m.region)

        ' Draw the layered bitmap/region
        m.Draw()

        ' Set (copy) the fade "to" region
        orig = createobject("roBitmap", {width: m.region.GetWidth(), height: m.region.GetHeight(), AlphaEnable: false})
        orig.DrawObject(0, 0, m.region)

        ' It's safe to clear the bitmaps/regions now
        for each comp in m.components
            comp.Destroy()
        end for

        for fade = -256 to -1 step m.fadeSpeed
            if abs(fade) < m.fadeSpeed or abs(fade) - abs(m.fadeSpeed) = 0 then fade = -1

            if fadeRegion <> invalid then
                m.region.DrawObject(0, 0, fadeRegion)
            end if

            m.region.DrawObject(0, 0, orig, fade)
            m.Trigger("redraw", [m])
        end for
    else
        ApplyFunc(CompositeClass().OnComponentRedraw, m, [component])
    end if
end sub

sub liHasPendingTextures() as boolean
    for each comp in m.components
        if IsFunction(comp.IsPendingTexture) and comp.IsPendingTexture() then
            return true
        end if
    end for

    return false
end sub

sub liAddComponent(child as object)
    ApplyFunc(CompositeClass().AddComponent, m, [child])
    child.needsLayout = true
    child.bgColor = Colors().Transparent
end sub

sub liPerformChildLayout(child as object)
    if m.HasPendingTextures() or type(child.region) <> "roRegion" then return
    child.needsLayout = false

    ' If we are not scaling the source image, then we'll have to reposition it.
    if child.scaleSize = false then
        dstWidth = m.region.GetWidth()
        dstHeight = m.region.GetHeight()
        srcWidth = child.region.GetWidth()
        srcHeight = child.region.GetHeight()

        xOffset = 0
        yOffset = 0

        if srcWidth <> dstWidth then
            if child.halign = child.JUSTIFY_CENTER then
                xOffset = cint(dstWidth/2 - srcWidth/2)
            else if child.halign = child.JUSTIFY_RIGHT then
                xOffset = cint(dstWidth - srcWidth)
            else
                xOffset = 0
            end if
        end if

        if srcHeight <> dstHeight then
            if child.valign = child.ALIGN_MIDDLE then
                yOffset = cint(dstHeight/2 - srcHeight/2)
            else if child.valign = child.ALIGN_BOTTOM then
                yOffset = cint(dstHeight - srcHeight)
            else
                yOffset = 0
            end if
        end if

        child.SetPosition(xOffset, yOffset)
    end if
end sub
