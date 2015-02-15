function TextureManager() as object
    if m.TextureManager = invalid then
        obj = {}

        obj.TManager = CreateObject("roTextureManager")
        obj.TManager.SetMessagePort(Application().port)

        obj.RequestList = {}

        ' track by screen (clear by screen)
        obj.ScreenList = {}
        obj.UsageList = {}
        obj.TrackByScreenID = tmTrackByScreenID
        obj.RemoveTextureByScreenID = tmRemoveTextureByScreenID

        obj.SendCount = 0
        obj.ReceiveCount = 0

        ' UNUSED STATES (FOR NOW)
        obj.STATE_REQUESTED   = 0
        obj.STATE_DOWNLOADING = 1
        obj.STATE_DOWNLOADED  = 2

        ' USED STATES
        obj.STATE_READY = 3
        obj.STATE_FAILED = 4
        obj.STATE_CANCELLED = 5

        obj.AddItem = tmAddItem
        obj.RemoveItem = tmRemoveItem
        obj.GetItem = tmGetItem
        obj.Reset = tmReset
        obj.CancelAll = tmCancelAll

        obj.CreateTextureRequest = tmCreateTextureRequest
        obj.RequestTexture = tmRequestTexture
        obj.CancelTexture = tmCancelTexture
        obj.ReceiveTexture = tmReceiveTexture
        obj.RemoveTexture = tmRemoveTexture

        ' Image cache (regions by sourceUrl)
        obj.cacheList = createObject("roAssociativeArray")
        obj.SetCache = tmSetCache
        obj.GetCache = tmGetCache
        obj.ClearCache = tmClearCache

        obj.Reset()
        m.TextureManager = obj
    end if

    return m.TextureManager
end function

' track texture usage by screen id and total screens
sub tmTrackByScreenID(url as string, screenIdInt as integer)
    screenID = tostr(screenIdInt)

    ' initiate the list for the URL if empty
    if m.ScreenList[screenID] = invalid then m.ScreenList[screenID] = {}

    ' set the url in use by X screen
    m.ScreenList[screenID][url] = true

    ' set the usage count by screens for the url
    m.UsageList[url] = 0
    for each id in m.ScreenList
        if m.ScreenList[id][url] = true then
            m.UsageList[url] = m.UsageList[url]+1
        end if
    end for
end sub

' remove all textures used by the screen id (exclude texture in use by multiple)
' including any cached images (regardless of the screen)
sub tmRemoveTextureByScreenId(screenIdInt as integer)
    screenID = tostr(screenIdInt)
    m.ClearCache()

    unloadCount = 0
    if m.ScreenList[screenID] <> invalid then
        for each url in m.ScreenList[screenID]
            ' other screens are using this bitmap (not probable yet)
            if m.UsageList[url] <> invalid and m.UsageList[url] > 1 then
                m.UsageList[url] = m.UsageList[url] - 1
            else
                unloadCount = unloadCount + 1
                m.TManager.UnloadBitmap(url)
            end if
        end for
        ' consider this screen empty
        m.ScreenList[screenID].clear()
    end if

    Debug("Texture Manager: cleared " + tostr(unloadCount) + " textures from screenID:" + screenID)
end sub

' remove a texture from the texture manager
sub tmRemoveTexture(url as dynamic, doLog = false as boolean)
    if url = invalid then return
    if doLog = true then Debug("unloading bitmap url from texture manager: " + tostr(url))
    m.TManager.UnloadBitmap(url)
end sub

' Adds an item to the list and increments the list count. The key is the textures id
sub tmAddItem(id as integer, value as dynamic)
    m.RequestList.AddReplace(id.toStr(), value)
    m.ListCount = m.ListCount + 1
end sub

' Removes an item from the list, decrements the count
function tmRemoveItem(id as integer) as dynamic
    key   = id.toStr()
    value = m.RequestList.LookUp(key)

    if value = invalid then return invalid

    m.RequestList.Delete(key)
    m.ListCount = m.ListCount - 1

    return value
end function

function tmGetItem(id as integer) as dynamic
    return m.RequestList[id.toStr()]
end function

' excludeFixed = do not cancel textures that do not shift. It's possible,
' we may want to cancel all textures due to a shift, so we'll need to keep
' any request not shifting.
sub tmCancelAll(excludeFixed=true as boolean)
    Debug("cancel pending textures")
    if m.ListCount <> invalid and m.ListCount > 0 then
        for each key in m.RequestList
            if excludeFixed or m.RequestList[key].component.fixed = false then
                m.CancelTexture(m.RequestList[key])
            end if
        end for
    end if
    ' TODO(rob) should we clear the RequestList and counts? The question is,
    ' do we want requests we couldn't cancel to be processed or not?
end sub

' Resets the list by emptying the manager and clearing
' out any items remaing, resets all values
sub tmReset()
    Debug("reset texture manager")
    ' cancel any pending requests
    m.CancelAll()

    m.TManager.CleanUp()
    m.RequestList.Clear()

    m.ListCount = 0
    m.SendCount = 0
    m.ReceiveCount = 0
end sub

sub tmCancelTexture(context as object)
    if context <> invalid and context.textureRequest <> invalid then
        ' increment the count before canceling.
        m.ReceiveCount = m.ReceiveCount + 1
        m.TManager.CancelRequest(context.textureRequest)
    end if
end sub

' Each texture object is sent to this function, which creates the texturerequest and sends it
' It also increments the sendcount
sub tmRequestTexture(component as object, context as object)
    if context.url = invalid then
        Warn("Ignoring texture request. URL is invalid.")
        component.SetBitmap(invalid)
        return
    end if
    component.pendingTexture = true

    if m.timerTextureManger = invalid then m.timerTextureManger = createtimer("textureManagerRequest")
    if m.SendCount = m.ReceiveCount then m.timerTextureManger.mark()

    request = m.CreateTextureRequest(context)

    if context.retriesRemaining = invalid then
        context.retriesRemaining = 1
    end if

    ' TODO(schuyler): Figure out how to ignore requests that come back after the
    ' screen is gone. Screen ID may work, but we may also want to keep some
    ' components around when they're the next screen down (e.g. dialogs, overlays, ...).
    ' Maybe components just generally need a way to know whether or not they've
    ' been discarded.

    ' Add the item into the async list
    m.AddItem(request.getID(), context)
    ' asynchronously request the texture
    m.TManager.RequestTexture(request)
    ' Increment the send count
    m.SendCount = m.SendCount + 1
    ' Return the current total sent

    ' Debug("texture request: " + tostr(m.SendCount) + "; " + context.Url)

    ' Stash some references
    context.textureRequest = request
    context.component = component
end sub

function tmCreateTextureRequest(context as object) as object
    request = CreateObject("roTextureRequest", context.url)

    ' texture requests expose the ifHttpAgent interface. We can set headers
    ' and certificates if needed. AddPlexHeaders?
    if left(context.url, 5) = "https" then
        request.SetCertificatesFile("common:/certs/ca-bundle.crt")
    end if

    if context.scaleSize = true then
        request.SetSize(context.width, context.height)
        request.SetScaleMode(context.scaleMode)
    end if

    return request
end function

' This function receives the texture and processes it, if successful it increments the receive count
function tmReceiveTexture(tmsg as object, screenID as integer) as boolean
    Debug("Received texture event")
    ' Get the returned state
    state = tmsg.GetState()

    context = m.getItem(tmsg.getID())

    ' TODO(schuyler): See above. Somehow detect and discard textures for closed screens?

    if state = m.STATE_CANCELLED then
        Debug("Cancelled Texture Request. State : " + state.toStr())
        m.RemoveItem(tmsg.getID())
        return false
    end if

    ' If return state is Ready, Failed, or Cancelled - either case, remove it from the list
    if state = m.STATE_READY or state >= m.STATE_FAILED
        ' Removed the received texture from the asynclist. But do not increment the received count
        m.RemoveItem(tmsg.getID())

        ' There SHOULD ALWAYS be one in there if used properly. This shouldn't
        ' happen anymore now that we cancel textures during cleanup (reset)
        if context = invalid then
            Warn("texture received is invalid: state " + tostr(state))
            return false
        end if

        bitmap = tmsg.GetBitmap()

        ' A state of 3 with a valid bitmap is complete
        if state = m.STATE_READY and bitmap <> invalid
            ' Increment the receive count and get rid of the texture request
            m.ReceiveCount = m.ReceiveCount + 1
            context.textureRequest = invalid

            ' Debug("texture request recv: " + tostr(m.ReceiveCount) + "; " + context.Url)

            ' track the used bitmap by screenId
            m.TrackByScreenID(tmsg.GetURI(), screenID)

            context.component.pendingTexture = false
            context.component.SetBitmap(bitmap)

            return true
        ' If a failure occurs you can try to resend it, but usually it is a more serious problem which
        ' can put you in an endless loop if you dont put a limit on it.
        else if state = m.STATE_FAILED and context.retriesRemaining > 0 then
            ' Rebuild and resend
            context.retriesRemaining = context.retriesRemaining - 1
            context.request = m.CreateTextureRequest(context)
            m.AddItem(context.request.getID(), context)
            m.TManager.RequestTexture(context.request)

            str = "Resend Texture Request. State : " + state.toStr()
            str = str + "  Bitmap: " + type(tmsg.GetBitmap()) + "  retriesRemaining: " + context.retriesRemaining.toStr()
            str = str + " URI: " + context.url
            Debug(str)

            return false
        ' This can occur with the dylnamic allocation when the textures are not removed from the queue fast enough
        ' or the resend count has expired, cancelled etc...
        else
            ' I've run into the issue with duplicate urls causing this issue. It
            ' might be due to unloading bitmaps to early or running GC (which we
            ' really need to keep for now)
            if state = m.STATE_READY then
                ' Rebuild and resend
                context.retriesRemaining = context.retriesRemaining - 1
                context.request = m.CreateTextureRequest(context)
                m.AddItem(context.request.getID(), context)
                m.TManager.RequestTexture(context.request)

                str = "texture Ready, but bitmap invalid -- Resend Texture Request. State : " + state.toStr()
                str = str + "  Bitmap: " + type(tmsg.GetBitmap()) + "  retriesRemaining: " + context.retriesRemaining.toStr()
                str = str + " URI: " + context.url
                Debug(str)

                return false
            else
                m.ReceiveCount = m.ReceiveCount + 1

                ' TODO(schuyler): Should we notify the component? Call SetBitmap(invalid)?

                str = "Handle failure by setting bitmap invalid. State: " + state.toStr() + "  Bitmap: " + type(tmsg.GetBitmap())
                str = str + " URI: " + context.url
                Debug(str)

                context.component.SetBitmap(invalid)
                return true
            end if

            str = "Unhandled Failure. State: " + state.toStr() + "  Bitmap: " + type(tmsg.GetBitmap())
            str = str + " URI: " + context.url
            Debug(str)

            return false
        end if

    end if

    ' Otherwise it is some other code such as downloading if it even exists.  Never seen it
    return false
end function

sub tmSetCache(region as object, sourceUrl as string)
    m.cacheList[sourceUrl] = region
end sub

function tmGetCache(sourceUrl as string, width as integer, height as integer) as dynamic
    cache = m.cacheList[sourceUrl]
    if type(cache) <> "roRegion" or width <> cache.GetWidth() or height <> cache.GetHeight() then
        cache = invalid
    end if
    return cache
end function

sub tmClearCache()
    m.cacheList.clear()
end sub
