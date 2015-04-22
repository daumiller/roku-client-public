' shifting animation used by Components screen, Grid screen, and VBox scrollable
sub AnimateShift(shift as object, components as object, screen as object)
    totalShift = iif(abs(shift.x) > abs(shift.y), abs(shift.x), abs(shift.y))
    if Locks().IsLocked("DrawAll") or appSettings().GetGlobal("animationSupport") = false then
        fps = 1
    else
        ' calculate the desired FPS ( use totalShift if the calulation fps > total )
        minFps = 10
        maxFps = 15

        fps = iif(totalShift / maxFps < minFps, minFps, maxFps)
        if totalShift < fps then fps = totalShift

        ' just a quick hack for slower roku's
        if appSettings().GetGlobal("animationFull") = false then fps = int(fps / 1.5)
        if fps = 0 then fps = 1
    end if

    Debug("total shift=" + tostr(totalShift) + " @ " + tostr(fps) + " fps")

    xd = cint(shift.x / fps)
    yd = cint(shift.y / fps)

    xd_shifted = 0
    yd_shifted = 0
    for x=1 To fps
        xd_shifted = xd_shifted + xd
        yd_shifted = yd_shifted + yd

        ' we need to make sure we shifted total amount
        if x = fps then
            if xd_shifted <> shift.x then xd = xd + (shift.x - xd_shifted)
            if yd_shifted <> shift.y then yd = yd + (shift.y - yd_shifted)
        end if

        for each comp in components
            comp.ShiftPosition(xd, yd)
        end for

        ' draw each shift after all components are shifted
        screen.DrawAll(true)
    end for
end sub

function AnimateTest() as integer
    ti = createObject("roTimespan")
    for i = 1 to 1e5: end for
    return ti.TotalMilliseconds()
end function
