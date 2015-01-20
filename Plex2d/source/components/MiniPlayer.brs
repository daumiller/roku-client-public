function MiniPlayer() as object
    if m.MiniPlayer = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(ContainerClass())

        obj.initComplete = false

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

        m.miniPlayer = obj
    end if

    if not m.miniPlayer.initComplete then
        m.miniPlayer.Init()
    end if

    return m.miniPlayer
end function

' wrapper to use the miniplayer singletone and set the zOrder
function createMiniPlayer() as object
    obj = MiniPlayer()

    if AudioPlayer().isActive() then
        obj.Show(false)
    end if

    return obj
end function

sub miniplayerDestroy()
    ' Hide the mini player instead of destroying it.
    m.SetZ(-1)
    m.SetFocusable(invalid, false)
end sub

sub miniplayerInit()
    if m.initComplete then return
    ApplyFunc(ContainerClass().Init, m)

    m.initComplete = true
    m.isDrawn = false
    m.zOrder = ZOrders().MINIPLAYER
    m.zOrderInit = -1
    m.selectCommand = "now_playing"

    ' Use the current track in the audio player, or we'll use placeholders
    item = AudioPlayer().GetCurTrack()
    labels = {}
    if item <> invalid then
        labels.title = item.Get("title", "")
        labels.subtitle = item.Get("parentTitle", "")
    end if

    ' TODO(rob): HD/SD nightmare and lame hardcoded positioning. We
    ' probably need to refactor the header, to have the ability to
    ' know the positioning. (other screens will beneifit too).
    m.padding = 5
    m.width = 160
    m.height = 50
    m.x = 150
    m.y = 20

    vbMain = createVBox(false, false, false, m.padding)
    vbMain.SetFrame(m.x + m.padding, m.y + m.padding, m.width - m.padding*2, m.height - m.padding)
    hbImgTrack = createHBox(false, false, false, 15)
    vbTrack = createVBox(false, false, false, 0)

    ' Image placeholder (transparent region)
    m.Image = createImage(item, 28, 28)
    m.Image.pvalign = m.Image.ALIGN_MIDDLE
    m.Image.zOrderInit = m.zOrderInit

    ' Title placeholder
    m.Title = createLabel(firstOf(labels.title, ""), FontRegistry().Font12)
    m.Title.width = m.width
    m.Title.zOrderInit = m.zOrderInit

    ' Subtitle placeholder
    m.Subtitle = createLabel(firstOf(labels.subtitle, ""), FontRegistry().Font12)
    m.Subtitle.width = m.width
    m.Subtitle.zOrderInit = m.zOrderInit

    ' Progress bar placeholder
    m.Progress = createBlock(&hffffff60)
    m.Progress.width = m.width
    m.Progress.height = 1
    m.Progress.zOrderInit = m.ZOrderInit

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

sub miniplayerShow(draw=true as boolean)
    if m.hideTimer <> invalid then m.hideTimer.active = false
    m.SetZ(m.zOrder)
    m.SetFocusable(m.selectCommand)
    if draw then CompositorScreen().DrawAll()
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
    if m.isDrawn = true then return [m]
    m.isDrawn = true
    return ApplyFunc(ContainerClass().Draw, m)
end function
