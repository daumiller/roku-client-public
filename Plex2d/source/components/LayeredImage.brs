function LayeredImageClass() as object
    if m.LayeredImageClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.Append(AlignmentMixin())

        obj.ClassName = "LayeredImage"

        obj.copyFadeRegion = true
        obj.waitForTextures = true

        ' Methods
        obj.SetFade = liSetFade
        obj.OnComponentRedraw = liOnComponentRedraw
        obj.AddComponent = liAddComponent
        obj.PerformChildLayout = liPerformChildLayout

        ' STATIC
        obj.LAYOUT_COMBINED = 0
        obj.LAYOUT_HORIZONTAL = 1
        obj.LAYOUT_VERTICAL = 2

        m.LayeredImageClass = obj
    end if

    return m.LayeredImageClass
end function

function createLayeredImage(spacing=0 as integer)
    obj = CreateObject("roAssociativeArray")
    obj.Append(LayeredImageClass())

    obj.Init()

    obj.spacing = spacing
    obj.halign = obj.JUSTIFY_CENTER
    obj.valign = obj.ALIGN_MIDDLE
    obj.layout = obj.LAYOUT_COMBINED

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
        ' Copy the current region or use the existing fade region, to fade from
        if m.fadeRegion = invalid then
            m.fadeRegion = CopyRegion(m.region)
        end if

        ' Clear the existing region, and draw the layered bitmap/region
        m.region.Clear(Colors().Transparent)
        m.Draw()

        ' Copy the new region, to fade into
        orig = CopyRegion(m.region)

        ' It's safe to clear the bitmaps/regions now
        for each comp in m.components
            comp.Destroy()
        end for

        m.region.setAlphaEnable(true)
        for fade = -256 + m.fadeSpeed to -1 step m.fadeSpeed
            if abs(fade) < m.fadeSpeed or abs(fade) - abs(m.fadeSpeed) = 0 then exit for

            if m.fadeRegion <> invalid then
                ' If the background is transparent, then we'll need to
                ' fade out the old image, and fade in the new image.
                '
                if m.bgColor = Colors().Transparent then
                    m.region.Clear(m.bgColor)
                    m.region.DrawObject(0, 0, m.fadeRegion, (fade + 257) * -1)
                else
                    m.region.DrawObject(0, 0, m.fadeRegion)
                end if
            end if

            m.region.DrawObject(0, 0, orig, fade)
            m.Trigger("redraw", [m])
        end for
        m.region.setAlphaEnable(m.alphaEnable)

        ' Clear the region and redraw the source with no alpha bit
        m.region.Clear(m.bgColor)
        m.region.DrawObject(0, 0, orig)
        m.Trigger("redraw", [m])

        m.Delete("fadeRegion")
    else
        ApplyFunc(CompositeClass().OnComponentRedraw, m, [component])
    end if
end sub

sub liAddComponent(child as object)
    ApplyFunc(CompositeClass().AddComponent, m, [child])
    child.needsLayout = true
    child.bgColor = Colors().Transparent
end sub

sub liPerformChildLayout(child as object)
    if m.HasPendingTextures() or type(child.region) <> "roRegion" then return
    child.needsLayout = false

    ' Horizontal layout of components (media flags)
    if m.layout = m.LAYOUT_HORIZONTAL then
        xOffset = 0
        for each comp in m.components
            comp.needsLayout = false
            comp.SetPosition(xOffset, 0)
            xOffset = xOffset + m.spacing + comp.region.GetWidth()
        end for

        if m.halign = m.JUSTIFY_LEFT then return

        offset = m.region.GetWidth() - (xOffset - m.spacing)
        if offset > 0 then
            if m.halign = m.JUSTIFY_CENTER then
                offset = cint(offset / 2)
            end if

            for each comp in m.components
                comp.SetPosition(comp.x + offset, 0)
            end for
        end if
    else if m.layout = m.LAYOUT_COMBINED and child.scaleSize = false then
        ' If we are not scaling the source image, then we'll have to reposition it.
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
    else if m.layout = m.LAYOUT_VERTICAL then
        Fatal("Layout not defined: " + tostr(m.layout))
    end if
end sub
