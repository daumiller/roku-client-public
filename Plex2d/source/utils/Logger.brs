function Logger()
    if m.Logger = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.LEVEL_DEBUG = 1
        obj.LEVEL_INFO = 2
        obj.LEVEL_WARN = 3
        obj.LEVEL_ERROR = 4
        obj.LEVEL_OFF = 10
        obj.LABELS = ["", "DEBUG ", "INFO ", "WARN ", "ERROR "]

        ' Properties
        obj.level = obj.LEVEL_OFF
        obj.buffer = box("")
        obj.tempFileNum = 0
        obj.tempFiles = CreateObject("roList")
        obj.lastDateStr = ""
        obj.lastTimeStr = ""
        obj.lastTimestamp = 0
        obj.lastDate = 0

        ' Methods
        obj.SetLevel = loggerSetLevel
        obj.Log = loggerLog
        obj.LogToPapertrail = loggerLogToPapertrail
        obj.EnablePapertrail = loggerEnablePapertrail
        obj.Flush = loggerFlush
        obj.UpdateSyslogHeader = loggerUpdateSyslogHeader

        obj.reset()
        m.Logger = obj

        ' TODO(schuyler): Always enable papertrail?
        obj.SetLevel(AppSettings().GetIntPreference("log_level"))
        obj.EnablePapertrail(5)

        ' Register with the web server
        WebServer().AddHandler("/logs", ProcessLogsRequest)

        ' Listen for log level preference changes
        Application().On("change:log_level", createCallable("SetLevel", obj))
    end if

    return m.Logger
end function

sub loggerSetLevel(level as dynamic)
    if not isint(level) then level = level.toint()
    if level = m.level then return

    if m.level = m.LEVEL_OFF or level = m.LEVEL_OFF then
        ' Toggling state, clear everything
        m.buffer = box("")
        m.tempFileNum = 0

        for each file in m.tempFiles
            DeleteFile(file)
        next

        m.tempFiles.Clear()
    end if

    m.level = level
end sub

sub loggerLog(level, msg)
    if level < m.level then return

    t = Now(true)

    if m.lastDate <> t.GetDayOfMonth() then
        m.lastDateStr = t.GetMonth().toStr() + "/" + t.GetDayOfMonth().toStr() + "/" + t.GetYear().toStr() + " "
    end if

    if m.lastTimestamp <> t.AsSeconds() then
        m.lastTimeStr = box("")

        if t.GetHours() < 10 then
            m.lastTimeStr.AppendString("0", 1)
            m.lastTimeStr.AppendString(t.GetHours().toStr(), 1)
        else
            m.lastTimeStr.AppendString(t.GetHours().toStr(), 2)
        end if

        m.lastTimeStr.AppendString(":", 1)

        if t.GetMinutes() < 10 then
            m.lastTimeStr.AppendString("0", 1)
            m.lastTimeStr.AppendString(t.GetMinutes().toStr(), 1)
        else
            m.lastTimeStr.AppendString(t.GetMinutes().toStr(), 2)
        end if

        m.lastTimeStr.AppendString(":", 1)

        if t.GetSeconds() < 10 then
            m.lastTimeStr.AppendString("0", 1)
            m.lastTimeStr.AppendString(t.GetSeconds().toStr(), 1)
        else
            m.lastTimeStr.AppendString(t.GetSeconds().toStr(), 2)
        end if

        m.lastTimeStr.AppendString(" ", 1)
    end if

    levelPrefix = m.LABELS[level]

    ' Print everything to the Roku console
    print m.lastDateStr; m.lastTimeStr; levelPrefix; msg

    ' Store everything in our logs for later download
    ' It's tempting to keep debug messages in an roList, but there's no
    ' way to write to a temp file one line at a time, so we're going to
    ' end up combining into a single massive string, might as well do
    ' that now.

    m.buffer.AppendString(m.lastDateStr, Len(m.lastDateStr))
    m.buffer.AppendString(m.lastTimeStr, Len(m.lastTimeStr))
    m.buffer.AppendString(levelPrefix, Len(levelPrefix))
    m.buffer.AppendString(msg, Len(msg))
    m.buffer.AppendString(Chr(10), 1)

    ' Don't fill up memory or the tmp filesystem. Unfortunately, there
    ' doesn't ' seem to be a way to figure out how much space is
    ' available, so this is totally arbitrary.

    if m.buffer.Len() > 16384 then
        m.Flush()
    end if

    ' If enabled, log to papertrail. The timestamp is unnecessary.

    if m.remoteLoggingTimer <> invalid then
        if m.remoteLoggingTimer.IsExpired() then
            m.syslogSocket.Close()
            m.syslogSocket = invalid
            m.syslogPackets = invalid
            m.remoteLoggingTimer = invalid
        else
            m.LogToPapertrail(levelPrefix + msg)
        end if
    end if
end sub

sub loggerLogToPapertrail(msg)
    ' Just about the simplest syslog packet possible without being empty.
    ' We're using the local0 facility and logging everything as debug, so
    ' <135>. We simply skip the timestamp and hostname, the receiving
    ' timestamp will be used and is good enough to avoid writing strftime
    ' in brightscript. Then we hardcode PlexForRoku as the TAG field and
    ' include the username in the CONTENT. Finally, we make sure the whole thing
    ' isn't too long.

    bytesLeft = 1024 - Len(m.syslogHeader)
    if bytesLeft > Len(msg) then
        packet = m.syslogHeader + msg
    else
        packet = m.syslogHeader + Left(msg, bytesLeft)
    end if

    m.syslogPackets.AddTail(packet)

    ' Try to send whatever we have in the queue.
    while m.syslogSocket.isWritable() and m.syslogPackets.Count() > 0
        m.syslogSocket.sendStr(m.syslogPackets.RemoveHead())
    end while
end sub

sub loggerEnablePapertrail(minutes=20)
    ' Create the remote syslog socket
    addr = CreateObject("roSocketAddress")
    udp = CreateObject("roDatagramSocket")

    ' We're never going to wait on this message port, but we still need to
    ' set it to make the socket async.
    udp.setMessagePort(CreateObject("roMessagePort"))

    addr.setHostname("logs.papertrailapp.com")
    addr.setPort(60969)
    udp.setSendToAddress(addr)

    m.syslogSocket = udp
    m.syslogPackets = CreateObject("roList")
    m.UpdateSyslogHeader()

    m.remoteLoggingTimer = createTimer("logger")
    m.remoteLoggingTimer.SetDuration(minutes * 60 * 1000)

    ' TODO(schuyler): Enable papertrail logging for PMS, potentially
end sub

sub loggerUpdateSyslogHeader()
    label = AppSettings().GetGlobal("rokuUniqueID")
    if MyPlexAccount().title <> invalid then
        label = MyPlexAccount().title + ":" + label
    end if
    m.syslogHeader = "<135> PlexForRoku: [" + label + "] "
end sub

sub loggerFlush()
    filename = "tmp:/debug_log" + m.tempFileNum.toStr() + ".txt"
    WriteAsciiFile(filename, m.buffer)
    m.tempFiles.AddTail(filename)
    m.tempFileNum = m.tempFileNum + 1
    m.buffer = box("")

    if m.tempFiles.Count() > 10 then
        filename = m.tempFiles.RemoveHead()
        DeleteFile(filename)
    end if
end sub

function ProcessLogsRequest()
    log = Logger()
    log.flush()

    fs = CreateObject("roFilesystem")
    m.files = CreateObject("roList")
    totalLen = 0
    for each path in log.tempFiles
        stat = fs.stat(path)
        if stat <> invalid then
            m.files.AddTail({path: path, length: stat.size})
            totalLen = totalLen + stat.size
        end if
    next

    m.mimetype = "text/plain"
    m.fileLength = totalLen
    m.source = m.CONCATFILES
    m.lastmod = Now()

    ' Not handling range requests...
    m.start = 0
    m.length = m.fileLength
    m.http_code = 200

    m.genHdr()
    return true
end function

' Shortcut functions for log levels

sub Debug(msg)
    log = Logger()
    log.Log(log.LEVEL_DEBUG, msg)
end sub

sub Info(msg)
    log = Logger()
    log.Log(log.LEVEL_INFO, msg)
end sub

sub Warn(msg)
    log = Logger()
    log.Log(log.LEVEL_WARN, msg)
end sub

sub Error(msg)
    log = Logger()
    log.Log(log.LEVEL_ERROR, msg)
end sub

sub Fatal(msg)
    log = Logger()
    log.Log(log.LEVEL_ERROR, msg)
    stop
end sub
