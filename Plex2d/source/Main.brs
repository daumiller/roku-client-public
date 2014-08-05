sub main(args)
    app = Application()

    settings = AppSettings()

    settings.ProcessLaunchArgs(args)

    Debug("App version: " + settings.GetGlobal("appName") + " " + settings.GetGlobal("appVersionStr"))
    Debug("Roku version: " + settings.GetGlobal("rokuVersionStr"))
    Debug("Roku model: " + settings.GetGlobal("rokuModel"))

    app.Run()
end sub
