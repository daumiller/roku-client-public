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
        obj.GetFilterOptions = filtersGetFilterOptions
        obj.GetFilterOptionValues = filtersGetFilterOptionValues

        obj.SetParsedSort = filtersSetParsedSort
        obj.SetParsedType = filtersSetParsedType
        obj.SetParsedFilter = filtersSetParsedFilter
        obj.SetDefaultSort = filtersSetDefaultSort

        obj.SetSort = filtersSetSort
        obj.SetType = filtersSetType
        obj.SetFilter = filtersSetFilter
        obj.ToggleFilter = filtersToggleFilter

        obj.ClearSort = filtersClearSort
        obj.ClearFilters = filtersClearFilters
        obj.Refresh = filtersRefresh

        obj.GetSort = filtersGetSort
        obj.GetFilters = filtersGetFilters

        obj.GetSortTitle = filtersGetSortTitle
        obj.GetFilterTitle = filtersGetFilterTitle

        obj.ParseType = filtersParseType
        obj.ParsePath = filtersParsePath
        obj.BuildPath = filtersBuildPath

        ' Constants
        obj.types = CreateObject("roAssociativeArray")
        obj.types["movie"] = [
            {title: "Movie", key: "movie", value: "1"}
        ]

        ' TODO(rob): Check with PMS for season filters/sorts. The PMS seems to give
        ' very little back, however the show filters/sorts work.
        obj.types["show"] = [
            {title: "Show", key: "show", value: "2"},
            {title: "Season", key: "season", value: "3"},
            {title: "Episode", key: "episode", value: "4"}
        ]
        obj.types["artist"] = [
            {title: "Artist", key: "artist", value: "8"},
            {title: "Album", key: "album", value: "9"}
            {title: "Track", key: "track", value: "10"}
        ]
        obj.types["photo"] = [
            {title: "Photo", key: "photo", value: "13"}
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
    ' TODO(rob): do we want to parse the current item for filter/sorts
    ' in the url. e.g. the unwatched button button and hubs that use
    ' a compatible filterd/sorted endpoint.

    ' Containers for available filters and sorts
    m.filterItems = CreateObject("roList")
    m.sortItems = CreateObject("roList")

    ' Containers for current filters, type and sorts
    m.currentSort = CreateObject("roAssociativeArray")
    m.currentFilters = CreateObject("roList")
    m.currentFilterTypes = CreateObject("roArray", 5, true)
end sub

sub filtersRefresh()
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
    if not response.IsSuccess() then return
    response.ParseResponse()
    context.complete = true

    if context.requestType = "sorts" then
        m.sortItems = response.items
    else if context.requestType = "filters" then
        m.filterItems = response.items
    else
        Debug("Unknown request type: " + tostr(context.requestType))
    end if

    m.RequestComplete()
end sub

sub filtersRequestComplete()
    ' Ignore futher processing until all requests are complete
    for each request in m.requests
        if request.context.complete <> true then
            return
        end if
    end for

    ' Parse current path for filters and sorts
    if m.ParsePath(m.originalPath) then
        ' Let whoever is listening know the requests are complete
        m.Trigger("refresh", [m])
    end if
end sub

function filtersHasFilters() as boolean
    return (m.filterItems.Count() > 0)
end function

function filtersHasSorts() as boolean
    return (m.sortItems.Count() > 0)
end function

function filtersIsAvailable() as boolean
    return (m.HasFilters() or m.HasSorts())
end function

function filtersHasTypes() as boolean
    return (m.currentFilterTypes.Count() > 1)
end function

function filtersGetTypeOptions() as object
    return m.currentFilterTypes
end function

function filtersGetSelectedType() as dynamic
    if m.selectedTypeIndex = invalid then return invalid

    return m.currentFilterTypes[m.selectedTypeIndex]
end function

function filtersParsePath(path as string, parseTypeOnly=false as boolean) as boolean
    ' Parse the current filter/sort from the url. There are some caveats
    ' though. How do we handle specialized sorting/filtering?
    '
    ' We may need to see if we are aware of the specialized sort/filter
    ' and hide the filtering options if do not support them.
    '
    ' * sort=viewUpdatedAt:desc&viewOffset>=300
    ' * originallyAvailableAt>=-1y
    '
    parts = path.Tokenize("?")
    if parts.Count() = 2 then
        args = parts.Peek().Tokenize("&")

        ' Ignore specialized filtering for now
        allowed = CreateObject("roRegex", "\w=\w", "")
        for each arg in args
            supported = allowed.IsMatch(arg)
            if supported then
                av = arg.tokenize("=")
                ' Do we need to url escape arg strings
                if parseTypeOnly or av[0] = "type" then
                    if av[0] = "type" then
                        m.SetParsedType(av[1])
                    end if
                else
                    if av[0] = "sort" then
                        supported = m.SetParsedSort(av[1])
                    else
                        supported = m.SetParsedFilter(av[0], av[1])
                    end if
                end if
            end if

            ' Return early if the endpoint isn't supported. We could be more
            ' fancy, and disallow a filtering or sorting separately if one
            ' is supported while the other is not. I'm sure there are caveats
            ' so lets keep it simple.
            '
            if not supported then return false
        end for
    else
        m.ClearSort()
        m.ClearFilters()
    end if

    if parseTypeOnly then return true

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

sub filtersClearFilters()
    m.currentFilters.Clear()
end sub

function filtersGetSort() as dynamic
    if m.currentSort.key = invalid  then return invalid

    return m.currentSort
end function

function filtersGetSortTitle() as dynamic
    if m.currentSort.plexObject = invalid then return invalid

    return m.currentSort.plexObject.Get("title")
end function

function filtersGetFilterTitle() as dynamic
    ' TODO(rob): this was initially created thinking we'd allow
    ' compound filters. This is a bit more simple, and trick now
    ' that we are not. We will have to save the filter title
    ' value, to preset the single filter selected.
    filterStringArr = []

    for each filter in m.currentFilters
        if filter.plexObject <> invalid then
            filterStringArr.Push(filter.plexObject.Get("title"))
        end if
    end for

    if filterStringArr.Count() > 0 then
        return JoinArray(filterStringArr, " / ")
    end if

    return invalid
end function

function filtersGetFilters() as dynamic
    if m.currentFilters.Count() = 0 then return invalid

    return m.currentFilters
end function

sub filtersSetType(value=invalid as dynamic, disableTriggers=false as boolean)
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

    m.currentFilterTypes.Clear()
    m.Delete("selectedTypeIndex")
    for each key in m.types
        filterTypes = m.types[key]
        for index = 0 to filterTypes.Count() - 1
            if lcase(filterTypes[index][match.key]) = lcase(match.value) then
                m.currentFilterTypes.Append(filterTypes)
                m.selectedTypeIndex = index
                exit for
            end if
        end for
    end for

    if not disableTriggers then
        m.Trigger("set_type", [m])
    end if
end sub

function filtersSetSort(key=invalid as dynamic, toggle=true as boolean, disableTriggers=false) as boolean
    if key = invalid or key <> m.currentSort.defaultKey or toggle = false then
        m.ClearSort()
    end if

    if key = invalid or not m.HasSorts() then return true

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

            m.currentSort.defaultKey = defaultKey
            m.currentSort.plexObject = sort

            if not disableTriggers then
                m.Trigger("set_sort", [m])
            end if

            return true
        end if
    end for

    return false
end function

' Wrapper to always disabled triggers when automatically setting a filter
function filtersSetParsedFilter(key as string, value=invalid as dynamic) as boolean
    return m.SetFilter(key, value, false, true)
end function

' Wrapper to always disabled triggers when automatically setting a sort
function filtersSetParsedSort(key=invalid as dynamic) as boolean
    return m.SetSort(key, false, true)
end function

' Wrapper to always disabled triggers when automatically setting a sort
sub filtersSetParsedType(key=invalid as dynamic)
    m.SetType(key, true)
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

function filtersSetFilter(key as string, value=invalid as dynamic, toggle=false as boolean, disableTriggers=false as boolean) as boolean
    if not m.HasFilters() then return true

    curfilters = m.currentFilters
    newFilters = CreateObject("roList")

    for each filter in curfilters
        if filter.key <> key then
            newFilters.Push(filter)
        else if filter.isBoolean and filter.value = "1" and toggle then
            value = invalid
            ' TODO(rob): how do we handle the boolean=false? e.g. unwatched=0
            ' would filter by "watched", but we don't have a good way to show
            ' that. For now, lets just remove the boolean filter if false.
            '
            ' On another note, after using it... I am assuming we don't want a
            ' tristate toggle (true, false, invalid) anyways. It's probably
            ' expected it's set to on, and off means we are not filtering at
            ' all.
            ' value = iif(filter.value = "1", "0", "1")
        end if
    end for

    if value <> invalid then
        for each plexObject in m.filterItems
            if instr(1, key, plexObject.Get("filter")) > 0 then
                filter = {key: key, value: value}
                filter.isBoolean = (plexObject.Get("filterType") = "boolean")
                filter.plexObject = plexObject
                newFilters.Push(filter)
                value = invalid
                exit for
            end if
        end for

        ' Handle unsupported filters. There are a few things we could do, but
        ' for now, let's just consider this as an unsupported endpoint.
        if value <> invalid then return false
    end if

    m.currentFilters = newFilters

    if not disableTriggers then
        m.Trigger("set_filter", [m])
    end if

    return true
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

    filterType = m.GetSelectedType()
    if filterType <> invalid then
        args.Push("type=" + filterType.value)
    end if

    uri = JoinArray(args, "&")

    path = JoinArray([m.sectionPath + "/all", uri], "?")

    Debug("Build filter path: " + path)

    return path
end function

function filtersGetSortOptions()
    return m.sortItems
end function

function filtersGetFilterOptions()
    return m.filterItems
end function

function filtersGetFilterOptionValues(plexObject as object, refresh=false as boolean) as object
    if plexObject.items = invalid then
        request = createPlexRequest(plexObject.GetServer(), plexObject.GetItemPath())
        response = request.DoRequestWithTimeout(30)
        plexObject.items = response.items
    end if

    return plexObject.items
end function
