function LayeredImageClass() as object
    if m.LayeredImageClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(CompositeClass())
        obj.ClassName = "LayeredImage"

        obj.alphaEnable = true

        ' Methods
        obj.SetFade = liSetFade
        obj.OnComponentRedraw = liOnComponentRedraw

        m.LayeredImageClass = obj
    end if

    return m.LayeredImageClass
end function

function createLayeredImage()
    obj = CreateObject("roAssociativeArray")
    obj.Append(LayeredImageClass())

    obj.Init()

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
    for each comp in m.components
        if IsFunction(comp.IsPendingTexture) and comp.IsPendingTexture() then
            Verbose("Ignore redraw for " + m.ToString() + ", it has pending textures.")
            return
        end if
    end for

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
