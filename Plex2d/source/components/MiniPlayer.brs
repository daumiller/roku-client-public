function MiniPlayer() as object
    if m.MiniPlayer = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.ClassName = "MiniPlayer"

        ' Initial settings
        obj.initComplete = false
        obj.isEnabled = false
        obj.isDrawn = false

        ' Methods
        obj.Destroy = miniplayerDestroy
        obj.Init = miniplayerInit
        obj.Show = miniplayerShow
        obj.Hide = miniplayerHide
        obj.SetZ = miniplayerSetZ
        obj.SetTitle = miniplayerSetTitle
        obj.SetSubtitle = miniplayerSetSubtitle
        obj.SetProgress = miniplayerSetProgress
        obj.SetImage = miniplayerSetImage
        obj.Draw = miniplayerDraw

        ' Listener Methods
        obj.OnPlay = miniplayerOnPlay
        obj.OnStop = miniplayerOnStop
        obj.OnPause = miniplayerOnPause
        obj.OnResume = miniplayerOnResume
        obj.OnProgress = miniplayerOnProgress

        m.miniPlayer = obj
    end if

    if not m.miniPlayer.initComplete then
        m.miniPlayer.Init()
    end if

    return m.miniPlayer
end function

function createMiniPlayer(screen as object) as object
    obj = MiniPlayer()

    obj.isEnabled = true
    obj.screen = screen

    if obj.player.isActive() then
        obj.Show(false)
    end if

    return obj
end function

sub miniplayerDestroy(delete=false as boolean)
    if delete then
        m.DisableListeners()
        GetGlobalAA().Delete("MiniPlayer")
    else
        ' Hide the mini player instead of destroying it.
        m.isEnabled = false
        m.Hide()
    end if
end sub

sub miniplayerInit()
    if m.initComplete then return
    ApplyFunc(ContainerClass().Init, m)

    m.player = AudioPlayer()
    m.initComplete = true
    m.isDrawn = false
    m.zOrder = ZOrders().MINIPLAYER
    m.zOrderInit = -1
    m.selectCommand = "now_playing"

    ' Use the current track in the audio player, or we'll use placeholders
    item = m.player.GetCurrentItem()
    labels = {}
    if item <> invalid then
        labels.title = item.Get("title", "")
        labels.subtitle = item.Get("parentTitle", "")
    end if

    ' TODO(rob): HD/SD nightmare and lame hardcoded positioning. We
    ' probably need to refactor the header, to have the ability to
    ' know the positioning. (other screens will beneifit too).
    m.padding = 2
    m.width = 180
    m.height = 50
    m.x = 150
    m.y = 15

    vbMain = createVBox(false, false, false, m.padding)
    vbMain.SetFrame(m.x + m.padding, m.y + m.padding, m.width - m.padding*2, m.height - m.padding)
    hbImgTrack = createHBox(false, false, false, 15)
    vbTrack = createVBox(false, false, false, 0)

    ' Image placeholder (transparent region)
    m.Image = createImage(item, 28, 28)
    m.Image.pvalign = m.Image.ALIGN_MIDDLE
    m.Image.zOrderInit = m.zOrderInit

    ' Title placeholder
    m.Title = createLabel(firstOf(labels.title, ""), FontRegistry().SMALL)
    m.Title.width = m.width
    m.Title.zOrderInit = m.zOrderInit

    ' Subtitle placeholder
    m.Subtitle = createLabel(firstOf(labels.subtitle, ""), FontRegistry().SMALL)
    m.Subtitle.width = m.width
    m.Subtitle.zOrderInit = m.zOrderInit

    ' Progress bar placeholder
    m.Progress = createBlock(&hffffff60)
    m.Progress.width = m.width
    m.Progress.height = 2
    m.Progress.zOrderInit = m.ZOrderInit

    vbTrack.AddComponent(m.Title)
    vbTrack.AddComponent(m.Subtitle)

    hbImgTrack.AddComponent(m.Image)
    hbImgTrack.AddComponent(vbTrack)

    vbMain.AddComponent(hbImgTrack)
    vbMain.AddComponent(m.Progress)

    m.AddComponent(vbMain)

    ' Set up listeners for AudioPlayer and the MiniPlayer
    m.DisableListeners()
    m.AddListener(m.player, "playing", CreateCallable("OnPlay", m))
    m.AddListener(m.player, "stopped", CreateCallable("OnStop", m))
    m.AddListener(m.player, "paused", CreateCallable("OnPause", m))
    m.AddListener(m.player, "resumed", CreateCallable("OnResume", m))
    m.AddListener(m.player, "progress", CreateCallable("OnProgress", m))
    m.EnableListeners()
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

    region = m.Progress.sprite.GetRegion()
    region.Clear(m.Progress.bgColor)
    progressPercent = int(time/1000) / int(duration/1000)
    region.DrawRect(0, 0, cint(m.Progress.width * progressPercent), m.Progress.height, Colors().Orange)
    return true
end function

sub miniplayerSetImage(item as object)
    m.Image.Replace(item)
end sub

sub miniplayerShow(draw=true as boolean)
    if not m.isEnabled then return

    m.SetZ(m.zOrder)
    m.SetFocusable(m.selectCommand)
    if draw then CompositorScreen().DrawAll()
end sub

sub miniplayerHide()
    m.SetFocusable(invalid, false)
    m.SetZ(-1)

    if Application().IsActiveScreen(m.screen) and m.Equals(m.screen.focusedItem) then
        m.screen.screen.HideFocus(true)
    end if
end sub

sub miniPlayerSetZ(zOrder as integer)
    if m.isDrawn = false then return

    m.Image.sprite.setZ(zOrder)
    m.Title.sprite.setZ(zOrder)
    m.Subtitle.sprite.setZ(zOrder)
    m.Progress.sprite.setZ(zOrder)
end sub

function miniplayerDraw() as object
    if m.isDrawn = true then return []

    m.isDrawn = true
    return ApplyFunc(ContainerClass().Draw, m)
end function

sub miniplayerOnPlay(player as object, item as object)
    m.SetTitle(item.Get("grandparentTitle", ""))
    m.SetSubtitle(item.Get("title", ""))
    m.SetProgress(0, item.GetInt("duration"))
    m.SetImage(item)
    m.Show()
end sub

sub miniplayerOnStop(player as object, item as object)
    m.Hide()
end sub

sub miniplayerOnPause(player as object, item as object)
    ' anything we need here?
end sub

sub miniplayerOnResume(player as object, item as object)
    m.Show()
end sub

sub miniplayerOnProgress(player as object, item as object, time as integer)
    ' limit gratuitous screen updates as they are expensive.
    if not player.IsPlaying or not  Application().IsActiveScreen(m.screen) then return

    if m.SetProgress(time, item.GetInt("duration")) then
        m.Show()
    end if
end sub
