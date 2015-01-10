sub main(args)
    app = Application()

    settings = AppSettings()

    settings.ProcessLaunchArgs(args)

    Info("App version: " + settings.GetGlobal("appName") + " " + settings.GetGlobal("appVersionStr"))
    Info("Roku version: " + settings.GetGlobal("rokuVersionStr"))
    Info("Roku model: " + settings.GetGlobal("rokuModel"))
    Info("Animation test: " + tostr(settings.GetGlobal("animationTest")))
    Info("Animation full:" + tostr(settings.GetGlobal("animationFull")))

    app.Run()
end sub
