function Logger()
    obj = m.Logger

    if obj = invalid then
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
        obj.lastDateTime = invalid

        ' Methods
        obj.SetLevel = loggerSetLevel
        obj.Log = loggerLog
        obj.LogToPapertrail = loggerLogToPapertrail
        obj.EnablePapertrail = loggerEnablePapertrail
        obj.Flush = loggerFlush

        obj.reset()
        m.Logger = obj

        ' TODO(schuyler): Remove these
        obj.SetLevel(obj.LEVEL_DEBUG)
        obj.EnablePapertrail(5)
    end if

    return obj
end function

sub loggerSetLevel(level)
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

    now = CreateObject("roDateTime")
    now.ToLocalTime()

    if m.lastDateTime = invalid or m.lastDateTime.GetDayOfMonth() <> now.GetDayOfMonth() then
        m.lastDateStr = now.GetMonth().toStr() + "/" + now.GetDayOfMonth().toStr() + "/" + now.GetYear().toStr() + " "
    end if

    if m.lastDateTime = invalid or m.lastDateTime.AsSeconds() <> now.AsSeconds() then
        m.lastTimeStr = box("")

        if now.GetHours() < 10 then
            m.lastTimeStr.AppendString("0", 1)
            m.lastTimeStr.AppendString(now.GetHours().toStr(), 1)
        else
            m.lastTimeStr.AppendString(now.GetHours().toStr(), 2)
        end if

        m.lastTimeStr.AppendString(":", 1)

        if now.GetMinutes() < 10 then
            m.lastTimeStr.AppendString("0", 1)
            m.lastTimeStr.AppendString(now.GetMinutes().toStr(), 1)
        else
            m.lastTimeStr.AppendString(now.GetMinutes().toStr(), 2)
        end if

        m.lastTimeStr.AppendString(":", 1)

        if now.GetSeconds() < 10 then
            m.lastTimeStr.AppendString("0", 1)
            m.lastTimeStr.AppendString(now.GetSeconds().toStr(), 1)
        else
            m.lastTimeStr.AppendString(now.GetSeconds().toStr(), 2)
        end if

        m.lastTimeStr.AppendString(" ", 1)
    end if

    m.lastDateTime = now

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
        if m.remoteLoggingTimer.TotalSeconds() > m.remoteLoggingSeconds then
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
    ' TODO(schuyler): This should be the signed in username, or a unique ID
    label = "Plex2DTest"

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
    m.syslogHeader = "<135> PlexForRoku: [" + label + "] "

    m.remoteLoggingSeconds = minutes * 60
    m.remoteLoggingTimer = CreateObject("roTimespan")

    ' TODO(schuyler): Enable papertrail logging for PMS, potentially
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
