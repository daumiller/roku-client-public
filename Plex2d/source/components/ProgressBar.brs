function ProgressBarClass() as object
    if m.ProgressBarClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentClass())
        obj.ClassName = "ProgressBar"

        obj.draw = pbDraw

        m.ProgressBarClass = obj
    end if

    return m.ProgressBarClass
end function

function createProgressBar(watchedPercent as dynamic, bgColor as integer, fgColor as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(ProgressBarClass())

    obj.Init()

    ' allow the watchedPercent to be an integer, decimal, float
    if watchedPercent = invalid then
        obj.percent = 0
    else if watchedPercent >= 1 then
        obj.percent = watchedPercent/100
    else
        obj.percent = watchedPercent
    end if

    obj.bgColor = bgColor
    obj.fgColor = fgColor

    return obj
end function

function pbDraw(redraw=false as boolean) as object
    ' only redraw if the current progress <> previous
    fgWidth = int(m.width * m.percent)
    if redraw = false and m.region <> invalid and m.fgWidth = fgWidth then
        return [m]
    else
        m.fgWidth = fgWidth
    end if

    m.InitRegion()

    ' draw the progress bar on the existing region
    m.region.DrawRect(0, 0, m.fgWidth, m.height, m.fgColor)

    return [m]
end function
