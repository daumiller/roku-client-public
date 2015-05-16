function TextureManager() as object
    if m.TextureManager = invalid then
        obj = {}

        obj.TManager = CreateObject("roTextureManager")
        obj.TManager.SetMessagePort(Application().port)

        obj.requestList = {}

        ' track by screen (clear by screen)
        obj.screenList = {}
        obj.overlayList = {}
        obj.TrackByScreen = tmTrackByScreen
        obj.RemoveTextureByScreenID = tmRemoveTextureByScreenID
        obj.RemoveTextureByOverlayID = tmRemoveTextureByOverlayID
        obj.RemoveTextureByListID = tmRemoveTextureByListID

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
        obj.cacheDelList = createObject("roAssociativeArray")
        obj.cacheMapList = createObject("roAssociativeArray")
        obj.SetCache = tmSetCache
        obj.GetCache = tmGetCache
        obj.ClearCache = tmClearCache
        obj.DeleteCache = tmDeleteCache
        obj.UseCache = tmUseCache

        obj.Reset()
        m.TextureManager = obj
    end if

    return m.TextureManager
end function

' track texture usage by screen id and total screens
sub tmTrackByScreen(url as string, screen as object)
    screenID = tostr(screen.screenID)

    ' initiate and set the screens URL list
    if m.screenList[screenID] = invalid then m.screenList[screenID] = {}
    m.screenList[screenID][url] = true

    ' initiate and set the overlays URL list
    if screen.overlayScreen.Count() > 0 then
        overlayID = tostr(screen.overlayScreen.Peek().uniqID)
        if m.overlayList[overlayID] = invalid then m.overlayList[overlayID] = {}
        m.overlayList[overlayID][url] = true
    end if
end sub

sub tmRemoveTextureByScreenId(screenID as integer)
    removeCount = m.RemoveTextureByListID(tostr(screenID), m.screenList)
    Debug("Texture Manager: cleared " + tostr(removeCount) + " textures from screenID:" + tostr(screenID))
end sub

sub tmRemoveTextureByOverlayId(overlayID as integer)
    removeCount = m.RemoveTextureByListID(tostr(overlayID), m.overlayList)
    Debug("Texture Manager: cleared " + tostr(removeCount) + " textures from overlayID:" + tostr(overlayID))
end sub

' remove all textures used by this list id (exclude texture in use by multiple screens)
function tmRemoveTextureByListId(listId as string, list as object) as integer
    removeCount = 0
    if list[listID] <> invalid then
        for each url in list[listID]
            removeCount = removeCount + 1
            m.TManager.UnloadBitmap(url)
        end for
        ' consider this list empty
        list[listID].clear()
    end if

    ' Set the cached urls as pending delete. We'll remove the urls from
    ' the pending delete list if used by the new screen, or clear them.
    m.DeleteCache()
    if AppSettings().GetGlobal("hasFirmware6_1") then
        Debug("Texture Manager: " + tostr(m.cacheList.Count()) + " cached manually")
    endif
    return removeCount
end function

' remove a texture from the texture manager
sub tmRemoveTexture(url=invalid as dynamic, doLog=false as boolean)
    if not IsString(url) then return
    if doLog = true then Debug("unloading bitmap url from texture manager: " + tostr(url))
    m.TManager.UnloadBitmap(url)
end sub

' Adds an item to the list and increments the list count. The key is the textures id
sub tmAddItem(id as integer, value as dynamic)
    m.requestList.AddReplace(id.toStr(), value)
    m.ListCount = m.ListCount + 1
end sub

' Removes an item from the list, decrements the count
function tmRemoveItem(id as integer) as dynamic
    key   = id.toStr()
    value = m.requestList.LookUp(key)

    if value = invalid then return invalid

    m.requestList.Delete(key)
    m.ListCount = m.ListCount - 1

    return value
end function

function tmGetItem(id as integer) as dynamic
    return m.requestList[id.toStr()]
end function

' includeFixed=false: do not cancel textures that do not shift. It's possible,
' we may want to cancel all textures due to a shift, so we'll need to keep
' any request not shifting.
sub tmCancelAll(includeFixed=true as boolean)
    Verbose("Cancel pending textures")
    if m.ListCount <> invalid and m.ListCount > 0 then
        for each key in m.requestList
            if includeFixed or m.requestList[key].component.fixed = false then
                m.CancelTexture(m.requestList[key])
            end if
        end for
    end if
    ' TODO(rob) should we clear the requestList and counts? The question is,
    ' do we want requests we couldn't cancel to be processed or not?
end sub

' Resets the list by emptying the manager and clearing
' out any items remaing, resets all values
sub tmReset()
    Debug("Reset texture manager")
    ' cancel any pending requests
    m.CancelAll()

    m.TManager.CleanUp()
    m.requestList.Clear()

    m.ListCount = 0
    m.SendCount = 0
    m.ReceiveCount = 0
end sub

sub tmCancelTexture(context=invalid as dynamic)
    if context <> invalid and context.textureRequest <> invalid then
        ' increment the count before canceling.
        m.ReceiveCount = m.ReceiveCount + 1
        m.TManager.CancelRequest(context.textureRequest)
    end if
end sub

' Each texture object is sent to this function, which creates the texturerequest and sends it
' It also increments the sendcount
sub tmRequestTexture(component as object, context as object)
    ' Our logic expects to set the bitmap after a texture request. Odd things happen if we
    ' try to set the bitmap and redraw inside of our component draw loop. This is a total
    ' hack, but setting the invalid url to 127.0.0.1 will allow us to use the same logic
    ' for setting empty/invalid bitmaps
    if context.url = invalid then
        if context.url = invalid then context.url = "http://127.0.0.1"
        context.retriesRemaining = 0
    end if

    ' cancel any pending texture for this component
    if component.textureRequest <> invalid then
        m.CancelTexture(component.textureRequest)
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
    component.textureRequest = context
end sub

function tmCreateTextureRequest(context as object) as object
    request = CreateObject("roTextureRequest", context.url)

    if context.scaleSize = true then
        request.SetSize(context.width, context.height)
        request.SetScaleMode(context.scaleMode)
    end if

    return request
end function

' This function receives the texture and processes it, if successful it increments the receive count
function tmReceiveTexture(tmsg as object, screen as object) as boolean
    Verbose("Received texture event")
    ' Get the returned state
    state = tmsg.GetState()

    context = m.getItem(tmsg.getID())

    if state = m.STATE_CANCELLED then
        Debug("Cancelled Texture Request. State : " + state.toStr())
        failed = true
    else if context.component.isDestroyed = true then
        Debug("Ignore Texture Request. Component was destroyed.")
        failed = true
    else
        failed = false
    end if

    if failed then
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
            m.TrackByScreen(tmsg.GetURI(), screen)

            context.component.pendingTexture = false
            context.component.textureRequest = invalid
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

                str = "Handle failure by setting bitmap invalid. State: " + state.toStr() + "  Bitmap: " + type(tmsg.GetBitmap())
                str = str + " URI: " + context.url
                Debug(str)

                context.textureRequest = invalid
                context.component.pendingTexture = false
                context.component.textureRequest = invalid
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

sub tmSetCache(component as object) 'region as object, sourceUrl as dynamic, altUrl as dynamic)
    if not IsString(component.source) or component.region = invalid then return

    ' Cache the url and alternate url (pretranscoded url)
    sourceUrl = component.source
    altSourceUrl = component.altSourceUrl
    m.cacheList[sourceUrl] = component.region
    if altSourceUrl <> invalid then
        m.cacheList[altSourceUrl] = component.region
        m.cacheMapList[altSourceUrl] = sourceUrl
        m.cacheMapList[sourceUrl] = sourceUrl
        component.altSourceUrl = invalid
    end if

    ' Clear any pending deleted for utilized cache
    m.UseCache(sourceUrl)
end sub

function tmGetCache(sourceUrl as dynamic, width as integer, height as integer) as dynamic
    if sourceUrl = invalid then return invalid
    cache = m.cacheList[sourceUrl]

    ' Verify the cached region has the same dimensions
    if type(cache) <> "roRegion" or width <> cache.GetWidth() or height <> cache.GetHeight() then
        cache = invalid
    else
        ' Remove any pending deletes for utilized cache
        m.UseCache(sourceUrl)
    end if

    return cache
end function

' Add all cached urls to the pending delete list
sub tmDeleteCache()
    for each sourceUrl in m.cacheList
        if m.cacheList.DoesExist(sourceUrl) then
            m.cacheDelList[sourceUrl] = true
        end if
        if m.cacheMapList.DoesExist(sourceUrl) then
             m.cacheDelList[m.cacheMapList[sourceUrl]] = true
        end if
    end for
end sub

sub tmClearCache(clearAll=false as boolean)
    if clearAll then
        m.cacheList.Clear()
        m.cacheMapList.Clear()
    else if not AppSettings().GetGlobal("hasFirmware6_1") or m.cacheDelList.Count() > 0 then
        for each key in m.cacheDelList
            m.cacheList.Delete(key)
            m.cacheMapList.Delete(key)
        end for
    end if
    m.cacheDelList.Clear()
end sub

sub tmUseCache(sourceUrl as string)
    m.cacheDelList.Delete(sourceUrl)
    if m.cacheMapList[sourceUrl] <> invalid then
        m.cacheDelList.Delete(m.cacheMapList[sourceUrl])
    end if
end sub
