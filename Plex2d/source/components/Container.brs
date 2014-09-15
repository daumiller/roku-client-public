function ContainerClass() as object
    if m.ContainerClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())

        obj.needsLayout = true

        ' Methods
        obj.Init = contInit
        obj.Draw = contDraw
        obj.AddComponent = contAddComponent
        obj.PerformLayout = contPerformLayout
        obj.SetFrame = contSetFrame

        m.ContainerClass = obj
    end if

    return m.ContainerClass
end function

sub contInit()
    ApplyFunc(ComponentClass().Init, m)

    m.components = CreateObject("roList")
end sub

function contDraw() as object
    ' When it comes to the actual drawing of children, most containers should
    ' simply have to ask their children to draw themselves. But the main work
    ' for most containers is in laying out their children, and this is a
    ' convenient place to make sure that that has happened.

    if m.needsLayout then m.PerformLayout()

    ' There are probably two reasonable ways for containers to draw themselves.
    ' They could create their own region/bitmap and ask all of their children
    ' to recursively draw themselves into that region and then return that. Or
    ' they could simply return an array of regions corresponding to their
    ' descendants. We're doing the latter so that we don't have to do extra
    ' compositing and bitmap creation.

    regions = CreateObject("roList")

    for each component in m.components
        childRegions = component.Draw()
        for each region in childRegions
            regions.Push(region)
        next
    next

    return regions
end function

sub contAddComponent(child)
    m.components.Push(child)
    m.needsLayout = true
end sub

sub contPerformLayout()
    m.needsLayout = false
end sub

sub contSetFrame(x as integer, y as integer, width as integer, height as integer)
    ApplyFunc(ComponentClass().SetFrame, m, [x, y, width, height])
    m.needsLayout = true
end sub
