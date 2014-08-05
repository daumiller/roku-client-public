' The webserver code is almost entirely lifted from the SDK example and
' doesn't follow all of our conventions. But we can at least wrap it and
' initialize it in a way that looks familiar.

function WebServer()
    obj = m.WebServer

    if obj = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.AddHandler = wsAddHandler
        obj.PreWait = wsPreWait
        obj.PostWait = wsPostWait

        obj.reset()
        m.WebServer = obj

        ' Initialization using globals
        globals = CreateObject("roAssociativeArray")
        globals.pkgname = "Plex"
        globals.maxRequestLength = 4000
        globals.idletime = 60
        globals.wwwroot = "tmp:/"
        globals.index_name = "index.html"
        globals.serverName = "Plex"
        AddGlobals(globals)
        MimeType()
        HttpTitle()

        obj.server = InitServer({msgPort: Application().port, port: 8324})
    end if

    return obj
end function

sub wsAddHandler(prefix, handler)
    ClassReply().AddHandler(prefix, handler)
end sub

sub wsPreWait()
    m.server.prewait()
end sub

sub wsPostWait()
    m.server.postwait()
end sub
