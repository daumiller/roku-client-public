function MiniPlayer() as object
    if m.MiniPlayer = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(ContainerClass())

        ' Methods
        obj.Destroy = miniplayerDestroy
        obj.Init = miniplayerInit
        obj.Show = miniplayerShow
        obj.Hide = miniplayerHide
        obj.SetZ = miniplayerSetZ
        obj.OnHideTimer = miniplayerOnHideTimer
        obj.SetTitle = miniplayerSetTitle
        obj.SetSubtitle = miniplayerSetSubtitle
        obj.SetProgress = miniplayerSetProgress
        obj.SetImage = miniplayerSetImage
        obj.Draw = miniplayerDraw

        obj.Init()

        m.miniPlayer = obj
    end if

    return m.miniPlayer
end function

sub miniplayerDestroy()
    ' do not destroy the component
end sub

sub miniplayerInit()
    ApplyFunc(ContainerClass().Init, m)

    ' TODO(rob): HD/SD nightmare and lame hardcoded positioning. We
    ' probably need to refactor the header, to have the ability to
    ' know the positioning. (other screens will beneifit too).
    m.padding = 5
    m.width = 160
    m.height = 50
    m.x = 150
    m.y = 20
    m.zOrder = 999
    m.isDrawn = false
    m.selectCommand = "now_playing"

    vbMain = createVBox(false, false, false, m.padding)
    vbMain = createVBox(false, false, false, 0)
    vbMain.SetFrame(m.x + m.padding, m.y + m.padding, m.width - m.padding*2, m.height - m.padding)
    hbImgTrack = createHBox(false, false, false, 15)
    vbTrack = createVBox(false, false, false, 0)

    ' Image placeholder (transparent region)
    m.Image = createImage(invalid, 28, 28)
    m.Image.pvalign = m.Image.ALIGN_MIDDLE
    m.Image.zOrderInit = -1

    ' Title placeholder
    m.Title = createLabel("", FontRegistry().Font12)
    m.Title.width = m.width
    m.Title.zOrderInit = -1

    ' Subtitle placeholder
    m.Subtitle = createLabel("", FontRegistry().Font12)
    m.Subtitle.width = m.width
    m.Subtitle.zOrderInit = -1

    ' Progress bar placeholder
    m.Progress = createBlock(&hffffff60)
    m.Progress.width = m.width
    m.Progress.height = 1
    m.Progress.zOrderInit = -1

    vbTrack.AddComponent(m.Title)
    vbTrack.AddComponent(m.Subtitle)

    hbImgTrack.AddComponent(m.Image)
    hbImgTrack.AddComponent(vbTrack)

    vbMain.AddComponent(hbImgTrack)
    vbMain.AddComponent(m.Progress)

    m.AddComponent(vbMain)
end sub

sub miniplayerSetTitle(text as string)
    if m.Title.sprite = invalid then return

    m.Title.text = text
    m.Title.Draw(true)
end sub

sub miniplayerSetSubtitle(text as string)
    if m.Subtitle.sprite = invalid then return

    m.Subtitle.text = text
    m.Subtitle.Draw(true)
end sub

function miniplayerSetProgress(time as integer, duration as integer) as boolean
    if m.Progress.sprite = invalid or duration = 0 then return false
    percentPlayed = time / duration

    progressWidth = cint(m.Progress.width * percentPlayed)
    region = m.Progress.sprite.GetRegion()
    region.Clear(m.Progress.bgColor)
    region.DrawRect(0, 0, progressWidth, m.Progress.height, Colors().Orange)
    return true
end function

sub miniplayerSetImage(item as object)
    m.Image.bitmap = invalid
    m.Image.region = invalid
    m.Image.sourceOrig = item
    m.Image.Draw()
end sub

sub miniplayerShow()
    if m.hideTimer <> invalid then m.hideTimer.active = false
    m.SetZ(m.zOrder)
    m.SetFocusable(m.selectCommand)
    CompositorScreen().DrawAll()
end sub

sub miniplayerHide(screen as object)
    ' Handle short-lived stop events (track change)
    m.SetFocusable(invalid, false)
    m.hideTimer = createTimer("hideTimer")
    m.hideTimer.SetDuration(1000)
    m.hideTimer.screen = screen
    Application().AddTimer(m.hideTimer, createCallable("OnHideTimer", m))
end sub

sub miniPlayerSetZ(zOrder as integer)
    if m.isDrawn = false then return
    m.Image.sprite.setZ(zOrder)
    m.Title.sprite.setZ(zOrder)
    m.Subtitle.sprite.setZ(zOrder)
    m.Progress.sprite.setZ(zOrder)
end sub

sub miniplayerOnHideTimer(timer as object)
    ' hide the focus box if selected.
    if m.Equals(timer.screen.focusedItem) then
        timer.screen.screen.HideFocus(true)
    end if
    m.SetZ(-1)
    CompositorScreen().DrawAll()
end sub

function miniplayerDraw() as object
    if m.isDrawn = false then
        for each comp in m.components
            CompositorScreen().DrawComponent(comp)
        end for
        m.isDrawn = true
    end if

    return m
end function
