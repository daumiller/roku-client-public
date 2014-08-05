function AppManager()
    if m.AppManager = invalid then
        obj = CreateObject("roAssociativeArray")

        ' obj.productCode = "PROD1" ' Sample product when sideloaded
        obj.productCode = "plexunlock"

        ' The unlocked state of the app, one of: Plex Pass, Exempt, Purchased, or Limited
        ' Media playback is only allowed if the state is not Limited.
        settings = AppSettings()
        obj.isPlexPass = (settings.GetPreference("IsPlexPass", "0", "misc") = "1")
        obj.isPurchased = (settings.GetPreference("purchased", "0", "misc") = "1")
        obj.isAvailableForPurchase = false
        obj.isExempt = false

        obj.initializers = CreateObject("roAssociativeArray")

        ' Track anything that needs to be initialized before the app can start
        ' and an initial screen can be shown. These need to be important,
        ' generally related to whether the app is unlocked or not.
        obj.AddInitializer = managerAddInitializer
        obj.ClearInitializer = managerClearInitializer
        obj.IsInitialized = managerIsInitialized
        obj.IsPlaybackAllowed = managerIsPlaybackAllowed
        obj.ResetState = managerResetState

        ' Channel store
        obj.FetchProducts = managerFetchProducts
        obj.HandleChannelStoreEvent = managerHandleChannelStoreEvent
        obj.StartPurchase = managerStartPurchase

        ' Singleton
        m.AppManager = obj

        obj.ResetState()
        obj.FetchProducts()
    end if

    return m.AppManager
end function

sub managerAddInitializer(name)
    m.initializers[name] = true
end sub

sub managerClearInitializer(name)
    if m.initializers.Delete(name) AND m.IsInitialized() then
        Application().OnInitialized()
    end if
end sub

function managerIsInitialized()
    m.initializers.Reset()
    return m.initializers.IsEmpty()
end function

function managerIsPlaybackAllowed()
    return m.state <> "Limited"
end function

sub managerResetState()
    if m.isPlexPass then
        m.state = "Plex Pass"
    else if m.isExempt then
        m.state = "Exempt"
    else if m.isPurchased then
        m.state = "Purchased"
    else
        m.state = "Limited"
    end if

    Info("App state is now: " + m.state)
end sub

sub managerFetchProducts()
    ' On the older firmware, the roChannelStore exists, it just doesn't seem to
    ' work. So don't even bother, just say that the item isn't available for
    ' purchase on the older firmware.

    if CheckMinimumVersion(AppSettings().GetGlobal("rokuVersionArr", [0]), [5, 1]) then
        m.AddInitializer("channelstore")

        ' The docs suggest we can make two requests at the same time by using the
        ' source identity, but it doesn't actually work. So we have to get the
        ' catalog and purchases serially. Start with the purchases, so that if
        ' we get a response we can skip the catalog request.

        store = CreateObject("roChannelStore")
        store.SetMessagePort(Application().port)
        store.GetPurchases()
        m.pendingStore = store
        m.pendingRequestPurchased = true
    else
        ' Rather than force these users to have a Plex Pass, we'll exempt them.
        ' Among other things, this allows old users to continue to work, since
        ' even though they've theoretically been grandfathered we don't know it.
        m.isExempt = true
        Debug("Channel store isn't supported by firmware version")
        m.ResetState()
    end if
end sub

sub managerHandleChannelStoreEvent(msg)
    m.pendingStore = invalid
    atLeastOneProduct = false

    if msg.isRequestSucceeded() then
        if m.pendingRequestPurchased then m.isPurchased = false
        for each product in msg.GetResponse()
            atLeastOneProduct = true
            if product.code = m.productCode then
                m.isAvailableForPurchase = true
                if m.pendingRequestPurchased then
                    m.isPurchased = true
                    AppSettings().SetPreference("purchased", "1", "misc")
                end if
            end if
        next
    end if

    ' If the catalog had at least one product, but not ours, then the user is
    ' exempt. This essentially allows sideloaded channels to be exempt without
    ' having to muck with anything.

    if not m.pendingRequestPurchased and not m.isAvailableForPurchase and atLeastOneProduct then
        Info("Channel is exempt from purchase requirement")
        m.isExempt = true
    end if

    ' If this was a purchases request and we didn't find anything, then issue
    ' a catalog request now.
    if m.pendingRequestPurchased and not m.isPurchased then
        Debug("Channel does not appear to be purchased, checking catalog")
        store = CreateObject("roChannelStore")
        store.SetMessagePort(Application().port)
        store.GetCatalog()
        m.pendingStore = store
        m.pendingRequestPurchased = false
    else
        Info("IAP is available: " + tostr(m.isAvailableForPurchase))
        Info("IAP is purchased: " + tostr(m.isPurchased))
        Info("IAP is exempt: " + tostr(m.isExempt))
        m.ResetState()
    end if

    if m.pendingStore = invalid then
        m.ClearInitializer("channelstore")
    end if
end sub

sub managerStartPurchase()
    store = CreateObject("roChannelStore")
    cart = CreateObject("roList")
    order = {code: m.productCode, qty: 1}
    cart.AddTail(order)
    store.SetOrder(cart)

    if store.DoOrder() then
        Info("Product purchased!")
        AppSettings().SetPreference("purchased", "1", "misc")
        m.isPurchased = true
        m.ResetState()
    else
        Debug("Product not purchased")
    end if
end sub
