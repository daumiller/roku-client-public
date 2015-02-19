function SplashScreen() as object
    if m.SplashScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "Splash Screen"

        obj.Show = splashShow
        obj.GetComponents = splashGetComponents

        m.SplashScreen = obj
    end if

    return m.SplashScreen
end function

function createSplashScreen() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SplashScreen())

    obj.Init()

    Application().clearScreens()

    return obj
end function

sub splashGetComponents()
    m.DestroyComponents()

    if appSettings().GetGlobal("IsHD") = true then
        image = "pkg:/images/Splash_HD.png"
    else
        image = "pkg:/images/splash_SD32.png"
    end if

    background = createImage(image, 1280, 720)
    background.setFrame(0, 0, background.width, background.height)
    background.fade = true
    m.components.Push(background)

    m.fade = createBlock(Colors().Black)
    m.fade.setFrame(0, 0, 1280, 720)
    m.components.Push(m.fade)
end sub

sub splashShow()
    ApplyFunc(ComponentsScreen().Show, m)

    incr = -10
    for fade = incr to -256 step incr
        m.fade.region.Clear(m.fade.bgColor and fade)
        m.screen.DrawAll()
    end for
end sub
