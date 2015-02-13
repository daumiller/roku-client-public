'*
'* Manage state about what is currently playing, who is currently subscribed
'* to that information, and sending timeline information to subscribers.
'*

function NowPlayingManager()
    if m.NowPlayingManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Constants
        obj.NAVIGATION = "navigation"
        obj.FULLSCREEN_VIDEO = "fullScreenVideo"
        obj.FULLSCREEN_MUSIC = "fullScreenMusic"
        obj.FULLSCREEN_PHOTO = "fullScreenPhoto"
        obj.TIMELINE_TYPES = ["video", "music", "photo"]

        ' Members
        obj.subscribers = CreateObject("roAssociativeArray")
        obj.pollReplies = CreateObject("roAssociativeArray")
        obj.timelines = CreateObject("roAssociativeArray")
        obj.location = obj.NAVIGATION

        obj.textFieldName = invalid
        obj.textFieldContent = invalid
        obj.textFieldSecure = false

        ' Functions
        obj.UpdateCommandID = nowPlayingUpdateCommandID
        obj.AddSubscriber = nowPlayingAddSubscriber
        obj.AddPollSubscriber = nowPlayingAddPollSubscriber
        obj.RemoveSubscriber = nowPlayingRemoveSubscriber
        obj.SendTimelineToServer = nowPlayingSendTimelineToServer
        obj.SendTimelineToSubscriber = nowPlayingSendTimelineToSubscriber
        obj.SendTimelineToAll = nowPlayingSendTimelineToAll
        obj.CreateTimelineDataXml = nowPlayingCreateTimelineDataXml
        obj.UpdatePlaybackState = nowPlayingUpdatePlaybackState
        obj.TimelineDataXmlForSubscriber = nowPlayingTimelineDataXmlForSubscriber
        obj.WaitForNextTimeline = nowPlayingWaitForNextTimeline
        obj.SetControllable = nowPlayingSetControllable
        obj.SetFocusedTextField = nowPlayingSetFocusedTextField
        obj.OnTimelineResponse = nowPlayingOnTimelineResponse

        ' Initialization
        for each timelineType in obj.TIMELINE_TYPES
            obj.timelines[timelineType] = TimelineData(timelineType)
        next

        ' server timeline
        obj.pmsLastTimelineItem = invalid
        obj.pmsLastTimelineState = invalid
        obj.pmsTimelineTimer = createTimer("pmsTimeline")
        obj.pmsTimelineTimer.SetDuration(15000, true)

        ' Singleton
        m.NowPlayingManager = obj
    end if

    return m.NowPlayingManager
end function

function TimelineData(timelineType as string) as object
    obj = CreateObject("roAssociativeArray")

    obj.type = timelineType
    obj.state = "stopped"
    obj.item = invalid
    obj.playQueue = invalid

    obj.controllable = CreateObject("roAssociativeArray")
    obj.controllableStr = invalid

    obj.attrs = CreateObject("roAssociativeArray")

    obj.UpdateControllableStr = timelineDataUpdateControllableStr
    obj.SetControllable = timelineDataSetControllable
    obj.ToXmlAttributes = timelineDataToXmlAttributes

    obj.SetControllable("playPause", true)
    obj.SetControllable("stop", true)

    if timelineType = "video" then
        obj.SetControllable("seekTo", true)
        obj.SetControllable("stepBack", true)
        obj.SetControllable("stepForward", true)
    else if timelineType = "music" then
        obj.SetControllable("seekTo", true)
        obj.SetControllable("stepBack", true)
        obj.SetControllable("stepForward", true)
        obj.SetControllable("repeat", true)
        obj.SetControllable("shuffle", true)
    else if timelineType = "photo" then
        obj.SetControllable("shuffle", true)
    end if

    return obj
end function

function NowPlayingSubscriber(deviceID as string, connectionUrl as dynamic, commandID as dynamic, poll=false as boolean) as object
    obj = CreateObject("roAssociativeArray")

    obj.deviceID = deviceID
    obj.connectionUrl = connectionUrl
    obj.commandID = validint(commandID)

    if not poll then
        obj.SubscriptionTimer = createTimer("SubscriptionTimer")
        obj.SubscriptionTimer.SetDuration(90000)
    end if

    return obj
end function

sub nowPlayingUpdateCommandID(deviceID as string, commandID as dynamic)
    subscriber = m.subscribers[deviceID]
    if subscriber <> invalid then
        subscriber.commandID = validint(commandID)
    end if
end sub

function nowPlayingAddSubscriber(deviceID as string, connectionUrl as string, commandID as dynamic) as boolean
    if firstOf(deviceID, "") = "" then
        Debug("Now Playing: received subscribe without an identifier")
        return false
    end if

    subscriber = m.subscribers[deviceID]

    if subscriber = invalid then
        Debug("Now Playing: New subscriber " + deviceID + " at " + tostr(connectionUrl) + " with command id " + tostr(commandID))
        subscriber = NowPlayingSubscriber(deviceID, connectionUrl, commandID)
        m.subscribers[deviceID] = subscriber
    end if

    subscriber.SubscriptionTimer.Mark()

    m.SendTimelineToSubscriber(subscriber)

    return true
end function

sub nowPlayingAddPollSubscriber(deviceID as string, commandID as dynamic)
    if firstOf(deviceID, "") = "" then return

    subscriber = m.subscribers[deviceID]

    if subscriber = invalid then
        subscriber = NowPlayingSubscriber(deviceID, invalid, commandID, true)
        m.subscribers[deviceID] = subscriber
    end if
end sub

sub nowPlayingRemoveSubscriber(deviceID as string)
    if deviceID <> invalid then
        Debug("Now Playing: Removing subscriber " + deviceID)
        m.subscribers.Delete(deviceID)
    end if
end sub

sub nowPlayingSendTimelineToSubscriber(subscriber as object, xml=invalid as dynamic)
    if xml = invalid then
        xml = m.CreateTimelineDataXml()
    end if

    xml.AddAttribute("commandID", tostr(subscriber.commandID))

    url = subscriber.connectionUrl + "/:/timeline"

    Application().StartRequestIgnoringResponse(url, xml.GenXml(false), invalid, true)
end sub

sub nowPlayingSendTimelineToServer(item as object, state as string, time as integer, playQueue=invalid as dynamic)
    if type(item.GetServer) <> "roFunction" or item.GetServer() = invalid then return

    ' only send the timeline if it's the first timeline, item changes, playstate changes or timer pops
    itemsEqual = (item <> invalid and m.pmsLastTimelineItem <> invalid and item.Get("ratingKey") = m.pmsLastTimelineItem.Get("ratingKey"))
    if itemsEqual AND state = m.pmsLastTimelineState AND NOT m.pmsTimelineTimer.IsExpired() then return

    m.pmsTimelineTimer.Mark()
    m.pmsLastTimelineItem = item
    m.pmsLastTimelineState = state

    encoder = CreateObject("roUrlTransfer")
    query = "time=" + tostr(time)
    query = query + "&duration=" + tostr(item.Get("duration"))
    query = query + "&state=" + state
    if item.Get("guid") <> invalid then query = query + "&guid=" + encoder.Escape(item.Get("guid"))
    if item.Get("ratingKey") <> invalid then query = query + "&ratingKey=" + encoder.Escape(item.Get("ratingKey"))
    if item.Get("url") <> invalid then query = query + "&url=" + encoder.Escape(item.Get("url"))
    if item.Get("key") <> invalid then query = query + "&key=" + encoder.Escape(item.Get("key"))
    if item.container.Get("address") <> invalid then query = query + "&containerKey=" + encoder.Escape(item.container.Get("address"))

    request = createPlexRequest(item.GetServer(), "/:/timeline?" + query)
    context = request.CreateRequestContext("timelineUpdate", createCallable("OnTimelineResponse", m))
    context.playQueue = playQueue
    Application().StartRequest(request, context)
end sub

sub nowPlayingSendTimelineToAll()
    m.subscribers.Reset()
    if m.subscribers.IsNext() then
        xml = m.CreateTimelineDataXml()
    end if
    expiredSubscribers = CreateObject("roList")

    for each id in m.subscribers
        subscriber = m.subscribers[id]
        if subscriber.SubscriptionTimer <> invalid then
            if subscriber.SubscriptionTimer.IsExpired() then
                expiredSubscribers.AddTail(id)
            else
                m.SendTimelineToSubscriber(subscriber, xml)
            end if
        end if
    next

    for each id in expiredSubscribers
        m.subscribers.Delete(id)
    next
end sub

sub nowPlayingUpdatePlaybackState(timelineType as string, item as object, state as string, time as integer, playQueue=invalid as dynamic)
    timeline = m.timelines[timelineType]
    timeline.state = state
    timeline.item = item
    timeline.playQueue = playQueue
    timeline.attrs["time"] = tostr(time)

    m.SendTimelineToAll()

    ' Send the timeline data to any waiting poll requests
    for each id in m.pollReplies
        reply = m.pollReplies[id]
        xml = m.TimelineDataXmlForSubscriber(reply.deviceID)
        reply.mimetype = MimeType("xml")
        reply.simpleOK(xml)
        reply.timeoutTimer.Active = false
        reply.timeoutTimer.Listener = invalid
    next

    m.pollReplies.Clear()

    m.SendTimelineToServer(item, state, time, playQueue)
end sub

function nowPlayingCreateTimelineDataXml() as object
    mc = CreateObject("roXMLElement")
    mc.SetName("MediaContainer")
    mc.AddAttribute("location", m.location)

    if m.textFieldName <> invalid then
        mc.AddAttribute("textFieldFocused", m.textFieldName)
        mc.AddAttribute("textFieldContent", m.textFieldContent)
        if m.textFieldSecure then
            mc.AddAttribute("textFieldSecure", "1")
        end if
    end if

    for each timelineType in m.TIMELINE_TYPES
        timeline = mc.AddElement("Timeline")
        m.timelines[timelineType].ToXmlAttributes(timeline)
    next

    return mc
end function

function nowPlayingTimelineDataXmlForSubscriber(deviceID as string) as object
    commandID = 0
    subscriber = m.subscribers[firstOf(deviceID, "")]
    if subscriber <> invalid then commandID = subscriber.commandID

    xml = m.CreateTimelineDataXml()
    xml.AddAttribute("commandID", tostr(commandID))

    return xml.GenXml(false)
end function

sub nowPlayingWaitForNextTimeline(deviceID as string, reply as object)
    timeoutTimer = createTimer("timeout")
    timeoutTimer.SetDuration(30000)
    timeoutTimer.active = true
    timeoutTimer.reply = reply

    reply.source = reply.WAITING
    reply.deviceID = deviceID
    reply.timeoutTimer = timeoutTimer
    reply.OnTimerExpired = pollOnTimerExpired

    Application().AddTimer(timeoutTimer, createCallable("OnTimerExpired", reply))

    m.pollReplies[tostr(reply.id)] = reply
end sub

sub pollOnTimerExpired(timer as object)
    timer.Listener = invalid

    xml = NowPlayingManager().TimelineDataXmlForSubscriber(m.deviceID)
    m.mimetype = MimeType("xml")
    m.simpleOK(xml)
end sub

sub nowPlayingSetControllable(timelineType as string, name as string, isControllable as boolean)
    m.timelines[timelineType].SetControllable(name, isControllable)
end sub

sub timelineDataSetControllable(name as string, isControllable as boolean)
    if isControllable then
        m.controllable[name] = ""
    else
        m.controllable.Delete(name)
    end if

    m.controllableStr = invalid
end sub

sub timelineDataUpdateControllableStr()
    if m.controllableStr = invalid then
        m.controllableStr = box("")
        prependComma = false

        for each name in m.controllable
            if prependComma then
                m.controllableStr.AppendString(",", 1)
            else
                prependComma = true
            end if
            m.controllableStr.AppendString(name, len(name))
        next
    end if
end sub

sub timelineDataToXmlAttributes(elem as object)
    m.UpdateControllableStr()
    elem.AddAttribute("type", m.type)
    elem.AddAttribute("state", m.state)
    elem.AddAttribute("controllable", m.controllableStr)

    if m.item <> invalid then
        addAttributeIfValid(elem, "duration", m.item.Get("duration"))
        addAttributeIfValid(elem, "ratingKey", m.item.Get("ratingKey"))
        addAttributeIfValid(elem, "key", m.item.Get("key"))
        addAttributeIfValid(elem, "containerKey", m.item.container.address)

        server = m.item.GetServer()
        if server <> invalid then
            elem.AddAttribute("machineIdentifier", server.uuid)

            if server.activeConnection <> invalid then
                parts = server.activeConnection.address.tokenize(":")
                elem.AddAttribute("protocol", parts.RemoveHead())
                elem.AddAttribute("address", Mid(parts.RemoveHead(), 3))
                if parts.GetHead() <> invalid then
                    elem.AddAttribute("port", parts.RemoveHead())
                else if elem@protocol = "https" then
                    elem.AddAttribute("port", "443")
                else
                    elem.AddAttribute("port", "80")
                end if
            end if
        end if
    end if

    if m.playQueue <> invalid then
        elem.AddAttribute("playQueueID", tostr(m.playQueue.id))
        elem.AddAttribute("playQueueItemID", tostr(m.playQueue.selectedId))
        elem.AddAttribute("playQueueVersion", tostr(m.playQueue.version))
    end if

    for each key in m.attrs
        elem.AddAttribute(key, m.attrs[key])
    next
end sub

sub addAttributeIfValid(elem as object, name as string, value=invalid as dynamic)
    if value <> invalid then
        elem.AddAttribute(name, tostr(value))
    end if
end sub

sub nowPlayingSetFocusedTextField(name=invalid as dynamic, content=invalid as dynamic, secure=false as boolean)
    m.textFieldName = name
    m.textFieldContent = firstOf(content, "")
    m.textFieldSecure = secure
    m.SendTimelineToAll()
end sub

sub nowplayingOnTimelineResponse(request as object, response as object, context as object)
    if context.playQueue = invalid or context.playQueue.refreshOnTimeline <> true then return
    context.playQueue.refreshOnTimeline = false
    context.playQueue.Refresh(false)
end sub
