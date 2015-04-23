function FiltersClass() as object
    if m.FiltersClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ListenersMixin())
        obj.Append(EventsMixin())

        ' Methods
        obj.Init = filtersInit
        obj.OnResponse = filtersOnResponse
        obj.RequestComplete = filtersRequestComplete

        obj.HasSorts = filtersHasSorts
        obj.HasTypes = filtersHasTypes
        obj.HasFilters = filtersHasFilters

        obj.IsAvailable = filtersIsAvailable
        obj.GetSelectedType = filtersGetSelectedType

        obj.GetSortOptions = filtersGetSortOptions
        obj.GetTypeOptions = filtersGetTypeOptions
        obj.GetUnwatchedOption = filtersGetUnwatchedOption
        obj.GetFilterOptions = filtersGetFilterOptions
        obj.GetFilterOptionValues = filtersGetFilterOptionValues
        obj.GetFilterOptionSize = filtersGetFilterOptionSize

        obj.SetParsedSort = filtersSetParsedSort
        obj.SetParsedType = filtersSetParsedType
        obj.SetParsedFilter = filtersSetParsedFilter
        obj.SetDefaultSort = filtersSetDefaultSort

        obj.SetSort = filtersSetSort
        obj.SetType = filtersSetType
        obj.SetFilter = filtersSetFilter
        obj.SetUnwatched = filtersSetUnwatched
        obj.ToggleUnwatched = filtersToggleUnwatched
        obj.ToggleFilter = filtersToggleFilter

        obj.ClearSort = filtersClearSort
        obj.ClearFilters = filtersClearFilters
        obj.ClearUnwatched = filtersClearUnwatched
        obj.Refresh = filtersRefresh

        obj.GetSort = filtersGetSort
        obj.GetFilters = filtersGetFilters
        obj.GetUnwatched = filtersGetUnwatched
        obj.IsUnwatched = filtersIsUnwatched
        obj.IsFilteredByKey = filtersIsFilteredByKey

        obj.IsModified = filtersIsModified
        obj.SetModified = filtersSetModified

        obj.GetSortTitle = filtersGetSortTitle
        obj.GetFilterTitle = filtersGetFilterTitle
        obj.GetSortDirection = filtersGetSortDirection

        obj.ParseType = filtersParseType
        obj.ParsePath = filtersParsePath
        obj.BuildPath = filtersBuildPath

        ' Constants
        obj.types = CreateObject("roAssociativeArray")
        obj.types["movie"] = [
            {title: "Movies", key: "movie", value: "1"}
        ]

        ' TODO(rob): removing the season type for now. It doesn't have any supported
        ' filters or useful sorts. The endpoint doesn't contain leafCount/viewedLeafCount
        ' either, so we may have to wait until the PMS has proper support
        '
        obj.types["show"] = [
            {title: "Shows", key: "show", value: "2"},
            ' {title: "Seasons", key: "season", value: "3"},
            {title: "Episodes", key: "episode", value: "4"}
        ]
        obj.types["artist"] = [
            {title: "Artists", key: "artist", value: "8"},
            {title: "Albums", key: "album", value: "9"}
            ' {title: "Tracks", key: "track", value: "10"}
        ]
        obj.types["photo"] = [
            {title: "Photos", key: "photo", value: "13"}
        ]

        m.FiltersClass = obj
    end if

    return m.FiltersClass
end function

function createFilters(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(FiltersClass())

    obj.item = item
    obj.Init()

    return obj
end function

sub filtersInit()
    ' Booleans for filtered endpoints
    m.hasCustomSort = false
    m.hasCustomFilter = false

    ' Containers for available filters, sorts and types
    m.filterItems = CreateObject("roList")
    m.sortItems = CreateObject("roList")
    m.typeItems = CreateObject("roArray", 5, true)

    ' Containers for current filters, type and sorts
    m.currentSort = CreateObject("roAssociativeArray")
    m.currentFilters = CreateObject("roList")
end sub

sub filtersRefresh()
    ' Try to use the existing filters object
    if m.forceRefresh <> true and m.IsAvailable() then
        m.Trigger("refresh", [m])
        return
    end if
    m.Delete("forceRefresh")

    m.sectionPath = m.item.GetSectionPath()
    m.server = m.item.GetServer()
    m.originalPath = m.item.GetAbsolutePath("key")

    if not m.ParseType() or m.sectionPath = invalid then
        Debug("Filters are not supported for this endpoint: " + tostr(m.originalPath))
        return
    end if

    m.ClearSort()
    m.ClearFilters()

    m.requests = CreateObject("roList")
    options = ["filters", "sorts"]
    for each option in options
        request = createPlexRequest(m.server, m.sectionPath + "/" + option + "?type=" + m.GetSelectedType().value)
        context = request.CreateRequestContext(option, createCallable("OnResponse", m))
        m.requests.Push({request: request, context: context})
    end for

    for each request in m.requests
        Application().StartRequest(request.request, request.context)
    end for
end sub

sub filtersOnResponse(request as object, response as object, context as object)
    response.ParseResponse()

    if context.requestType = "sorts" then
        m.sortItems = response.items
    else if context.requestType = "filters" then
        ' Separate unwatched filter from the rest
        m.filterItems.Clear()
        m.Delete("unwatchedItem")
        for each item in response.items
            if instr(1, item.Get("key"), "unwatched") > 0 then
                m.unwatchedItem = item
            else
                m.filterItems.Push(item)
            end if
        end for
    else
        Debug("Unknown request type: " + tostr(context.requestType))
    end if

    m.RequestComplete(context)
end sub

sub filtersRequestComplete(context as object)
    context.isProcessed = true

    ' Ignore futher processing until all requests are complete
    for each request in m.requests
        if request.context.isProcessed <> true then return
    end for

    ' Parse current path for filters and sorts
    if m.ParsePath(m.originalPath) then
        ' Let whoever is listening know the requests are complete
        m.Trigger("refresh", [m])
    else
        Debug("Filters are not supported for this endpoint: " + tostr(m.originalPath))
    end if
end sub

function filtersHasFilters() as boolean
    return (m.GetUnwatchedOption() <> invalid or m.filterItems.Count() > 0)
end function

function filtersHasSorts() as boolean
    return (m.sortItems.Count() > 0)
end function

function filtersIsAvailable() as boolean
    return (m.HasFilters() or m.HasSorts())
end function

function filtersHasTypes() as boolean
    return (m.typeItems.Count() > 1)
end function

function filtersGetTypeOptions() as object
    return m.typeItems
end function

function filtersGetSelectedType(useOverride=false as boolean) as dynamic
    if m.selectedTypeIndex = invalid then return invalid

    return m.typeItems[m.selectedTypeIndex]
end function

function filtersParsePath(path as string, parseTypeOnly=false as boolean) as boolean
    ' Parse the current filter/sort from the url. There are some caveats
    ' though. How do we handle specialized sorting/filtering?
    '
    ' Update: Now that we do not support compound filters, we can simply
    ' include specialized filters and sorts. Any new filter or sort will
    ' be replaced, and we'll use the existing specialized filter/sort if
    ' it's not specifically overridden.
    '
    ' * sort=viewUpdatedAt:desc&viewOffset>=300
    ' * originallyAvailableAt>=-1y
    '
    parts = path.Tokenize("?")
    if parts.Count() = 2 then
        for each arg in parts.Peek().Tokenize("&")
            av = arg.tokenize("=")
            ' Do we need to url escape arg strings
            if parseTypeOnly or av[0] = "type" then
                if av[0] = "type" then
                    m.SetParsedType(av[1])
                end if
            else
                if av[0] = "sort" then
                    if not m.SetParsedSort(av[1]) then
                        m.hasCustomSort = true
                    end if
                else
                    if not m.SetParsedFilter(av[0], av[1]) then
                        m.hasCustomFilter = true
                    end if
                end if
            end if
        end for
    else
        m.ClearSort()
        m.ClearFilters()
    end if

    if parseTypeOnly then return true

    ' Check if the endpoint only contains a sort. We'll need to
    ' handle the user changing the sort (reset the grid title)
    if m.GetFilters() = invalid and m.GetSort() <> invalid then
        m.hasCustomSort = true
    end if

    m.SetDefaultSort()

    Debug("Parsed url for filters and sorts: " + path)
    Debug("Sort: " + tostr(m.currentSort, 1))
    Debug("Filters: " + tostr(m.currentFilters.Count()))
    if m.currentFilters.Count() > 0 then
        for each filter in m.currentFilters
            Debug(tostr(filter, 1))
        end for
    end if

    return true
end function

sub filtersClearSort()
    m.currentSort.Clear()
end sub

sub filtersSetDefaultSort()
    m.Delete("defaultSortKey")
    if not m.HasSorts() then return

    for each plexObject in m.sortItems
        if plexObject.Has("default") then
             m.defaultSortKey = plexObject.Get("key")
            exit for
        end if
    end for

    if m.GetSort() = invalid then
        m.SetParsedSort(m.defaultSortKey)
    end if
end sub

sub filtersClearFilters(trigger=false as boolean)
    m.currentFilters.Clear()

    if trigger then
        m.SetModified()
        m.Trigger("set_filter", [m])
    end if
end sub

function filtersGetSort() as dynamic
    if m.currentSort.key = invalid then return invalid

    return m.currentSort
end function

function filtersGetUnwatched() as dynamic
    return m.currentUnwatched
end function

function filtersIsUnwatched() as boolean
    return (m.currentUnwatched <> invalid)
end function

function filtersGetSortTitle() as dynamic
    if m.currentSort.plexObject = invalid then return invalid

    return "By " + m.currentSort.plexObject.Get("title")
end function

function filtersGetFilterTitle() as dynamic
    filterStringArr = []

    for each filter in m.currentFilters
        if filter.title <> invalid then
            filterStringArr.Push(filter.title)
        else if filter.plexObject <> invalid then
            filterStringArr.Push(filter.plexObject.Get("title"))
        else
            filterStringArr = ["custom"]
            exit for
        end if
    end for

    if m.IsUnwatched() then
        filterStringArr.Unshift("UNWATCHED")
    end if

    if filterStringArr.Count() > 0 then
        return ucase(JoinArray(filterStringArr, " / "))
    end if

    return invalid
end function

function filtersGetFilters() as dynamic
    if m.currentFilters.Count() = 0 then return invalid

    return m.currentFilters
end function

sub filtersSetType(value=invalid as dynamic, trigger=true as boolean)
    if value = invalid then return

    ' value can be an object or string (key|value)
    match = {key: "value"}
    if IsString(value) then
        match.value = value
        if tostr(value.toInt()) <> value then
            match.key = "key"
        end if
    else
        match.value = value.value
    end if

    curIndex = m.selectedTypeIndex
    m.Delete("selectedTypeIndex")
    m.typeItems.Clear()
    for each key in m.types
        itemTypes = m.types[key]
        for index = 0 to itemTypes.Count() - 1
            if lcase(itemTypes[index][match.key]) = lcase(match.value) then
                m.typeItems.Append(itemTypes)
                m.selectedTypeIndex = index
                exit for
            end if
        end for
    end for

    if trigger then
        ' Clear filters, sorts and unwatched status on type change
        if curIndex <> invalid and m.selectedTypeIndex <> curIndex then
            m.forceRefresh = true
            m.ClearUnwatched()
            m.ClearSort()
            m.ClearFilters()
        end if

        m.SetModified()
        m.Trigger("set_type", [m])
    end if
end sub

function filtersSetSort(key=invalid as dynamic, toggle=true as boolean, trigger=true as boolean) as boolean
    if key = invalid or key <> m.currentSort.defaultKey or toggle = false then
        m.ClearSort()
    end if

    if key = invalid or not m.HasSorts() then return true

    m.currentSort.Delete("plexObject")
    for each sort in m.sortItems
        if instr(1, key, sort.Get("key")) > 0 then
            defaultKey = sort.Get("key")
            descKey = sort.Get("descKey", defaultKey)

            ' Set the new sort or toggle existing
            if toggle = false then
                m.currentSort.key = key
            else if m.currentSort.key = invalid then
                m.currentSort.key = iif(sort.Get("defaultDirection", "desc") = "desc", descKey, defaultKey)
            else if defaultKey = m.currentSort.key then
                m.currentSort.key = descKey
            else
                m.currentSort.key = defaultKey
            end if

            m.currentSort.direction = iif(m.currentSort.key = descKey, "desc", "asc")
            m.currentSort.defaultKey = defaultKey
            m.currentSort.plexObject = sort
        end if
    end for

    ' Handle custom sorts (specialized endpoints)
    if not m.currentSort.DoesExist("plexObject") then
        m.ClearSort()
        m.currentSort.key = key
    end if

    if trigger then
        if m.hasCustomSort = true then
            m.SetModified()
        end if
        m.Trigger("set_sort", [m])
    end if

    return (m.currentSort.plexObject <> invalid)
end function

' Wrapper to always disable triggers when automatically setting a filter
function filtersSetParsedFilter(key as string, value=invalid as dynamic) as boolean
    if instr(1, key, "unwatched") > 0 then
        return m.SetUnwatched(key, true)
    end if

    return m.SetFilter(key, value, invalid, false, false)
end function

' Wrapper to always disable triggers when automatically setting a sort
function filtersSetParsedSort(key=invalid as dynamic) as boolean
    return m.SetSort(key, false, false)
end function

' Wrapper to always disable triggers when automatically setting a sort
sub filtersSetParsedType(key=invalid as dynamic)
    m.SetType(key, false)
end sub

function filtersParseType() as boolean
    ' Try parsing the type from the path
    if m.ParsePath(m.originalPath, true) then
        ' Fall back to setting the type based on the item
        if m.GetSelectedType() = invalid then
            m.SetParsedType(m.item.Get("type"))
        end if

        return (m.GetSelectedType() <> invalid)
    end if

    return false
end function

sub filtersToggleFilter(key as string)
    ' Logic to toggle is part of SetFilter, but this wrapper
    ' is used to alleviate confusion.
    m.SetFilter(key, "1", true)
end sub

sub filtersToggleUnwatched(key as string)
    m.SetUnwatched(key, (m.IsUnwatched() = false))
end sub

function filtersSetUnwatched(key as string, unwatched=true as boolean) as boolean
    if unwatched = false then
        m.Delete("currentUnwatched")
    else
        m.currentUnwatched = {key: key, value: "1", isBoolean: true}
    end if

    return true
end function

function filtersSetFilter(key as string, value=invalid as dynamic, title=invalid as dynamic, toggle=false as boolean, trigger=true as boolean) as boolean
    if not m.HasFilters() then return true

    newFilters = CreateObject("roList")

    ' Handle toggling boolean filters
    for each filter in m.currentFilters
        ' Save the current filter if trigger is disabled. At this point, we are
        ' just saving the filter, so we'll allow multiple filters to exist.
        if not trigger and filter.key <> key then
            newFilters.Push(filter)
        else if toggle and filter.isBoolean and filter.value = "1" then
            ' TODO(rob): how do we handle the boolean=false? e.g. unwatched=0
            ' would filter by "watched", but we don't have a good way to show
            ' that. For now, lets just remove the boolean filter if false.
            '
            ' On another note, after using it... I am assuming we don't want a
            ' tristate toggle (true, false, invalid) anyways. It's probably
            ' expected it's set to on, and off means we are not filtering at
            ' all.
            ' value = iif(filter.value = "1", "0", "1")
            value = invalid
            exit for
       end if
    end for

    if value <> invalid then
        filter = {key: key, value: value, title: title}
        for each plexObject in m.filterItems
            if instr(1, key, plexObject.Get("filter")) > 0 then
                filter.isBoolean = (plexObject.Get("filterType") = "boolean")
                filter.plexObject = plexObject
                exit for
            end if
        end for
        newFilters.Push(filter)

        ' Verify the filter is supported. This is more of a non-issue now that
        ' we do not allow compound filters.
        supported = (filter.plexObject <> invalid)
    else
        supported = true
    end if

    m.currentFilters = newFilters

    if trigger then
        m.SetModified()
        m.Trigger("set_filter", [m])
    end if

    return supported
end function

function filtersBuildPath() as string
    args = []

    sort = m.GetSort()
    if sort <> invalid then
        args.Push("sort=" + sort.key)
    end if

    filters = m.GetFilters()
    if filters <> invalid then
        for each filter in filters
            args.Push(filter.key + "=" + filter.value)
        end for
    end if

    itemType = m.GetSelectedType()
    if itemType <> invalid then
        args.Push("type=" + itemType.value)
    end if

    unwatched = m.GetUnwatched()
    if unwatched <> invalid then
        args.Push(unwatched.key + "=" + unwatched.value)
    end if

    uri = JoinArray(args, "&")

    path = JoinArray([m.sectionPath + "/all", uri], "?")

    Debug("Build filter path: " + path)

    return path
end function

function filtersGetSortOptions() as object
    return m.sortItems
end function

function filtersGetFilterOptions() as object
    return m.filterItems
end function

function filtersGetUnwatchedOption() as dynamic
    return m.unwatchedItem
end function

function filtersGetFilterOptionSize(plexObject as object) as integer
    if plexObject.items <> invalid then
        return plexObject.items.Count()
    end if

    request = createPlexRequest(plexObject.GetServer(), plexObject.GetItemPath())
    request.AddHeader("X-Plex-Container-Start", "0")
    request.AddHeader("X-Plex-Container-Size", "0")
    response = request.DoRequestWithTimeout(30)

    return response.container.GetFirst(["totalSize", "size"], "0").toInt()
end function

function filtersGetFilterOptionValues(plexObject as object, refresh=false as boolean) as object
    if plexObject.items = invalid then
        request = createPlexRequest(plexObject.GetServer(), plexObject.GetItemPath())
        response = request.DoRequestWithTimeout(30)
        plexObject.items = response.items
    end if

    return plexObject.items
end function

sub filtersClearUnwatched()
    m.SetUnwatched("", false)
end sub

' Helpers to differentiate if the filter/sort was set or parsed. This
' will stay true when we clear the filters.
function filtersIsModified() as boolean
    return (m.filtersIsModifed = true)
end function

sub filtersSetModified()
    m.filtersIsModifed = true
end sub

function filtersGetSortDirection(key) as dynamic
    if key = invalid or key = m.currentSort.defaultKey then
        return m.currentSort.direction
    end if

    return invalid
end function

function filtersIsFilteredByKey(key as string) as boolean
    for each filter in m.currentFilters
        if key = filter.key
            return true
        end if
    end for

    return false
end function
