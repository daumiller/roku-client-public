' shifting animation used by Components screen, Grid screen, and VBox scrollable
sub AnimateShift(shift as object, components as object, screen as object)
    ' Calculate the FPS shift amount. 15 fps seems to be a workable arbitrary number.
    ' Verify the px shifting are > than the fps, otherwise it's sluggish (non Roku3)
    minFPS = 8
    maxFPS = 15

    fps = maxFPS
    if shift.x <> 0 and abs(shift.x / fps) < fps then
        fps = int(abs(shift.x / fps))
    else if shift.y <> 0 and abs(shift.y / fps) < fps then
        fps = int(abs(shift.y / fps))
    end if
    if fps = 0 then fps = 1

    ' Don't accept any calculation under the minFPS, it's too jarring
    '  note: only set to check X axis shifting
    if fps < minFps and shift.x <> invalid then
        delta = 2
        fps = int(abs(shift.x / delta))
        while fps > maxFPS
            delta = delta + 1
            fps = int(abs(shift.x / delta))
        end while
    end if

    ' TODO(rob) just a quick hack for slower roku's
    if appSettings().GetGlobal("animationFull") = false then fps = int(fps / 1.5)
    if fps = 0 then fps = 1

    if shift.x < 0 then
        xd = int((shift.x / fps) + .9)
    else if shift.x > 0 then
        xd = int(shift.x / fps)
    else
        xd = 0
    end if

    if shift.y < 0 then
        yd = int((shift.y / fps) + .9)
    else if shift.y > 0 then
        yd = int(shift.y / fps)
    else
        yd = 0
    end if

    ' total px shifted to verfy we shifted the exact amount (when shifting partially)
    xd_shifted = 0
    yd_shifted = 0

    ' TODO(rob) only animate shifts if on screen (or will be after shift)
    for x=1 To fps
        xd_shifted = xd_shifted + xd
        yd_shifted = yd_shifted + yd

        ' we need to make sure we shifted the shift_xd amount,
        ' since can't move pixel by pixel
        if x = fps then
            if xd_shifted <> shift.x then
                if xd < 0 then
                    xd = xd + (shift.x - xd_shifted)
                else
                    xd = xd + (shift.x - xd_shifted)
                end if
            end if
            if yd_shifted <> shift.y then
                if yd < 0 then
                    yd = yd + (shift.y - yd_shifted)
                else
                    yd = yd + (shift.y - yd_shifted)
                end if
            end if
        end if

        for each comp in components
            comp.ShiftPosition(xd, yd)
        end for
        ' draw each shift after all components are shifted
        screen.DrawAll()
    end for
end sub
