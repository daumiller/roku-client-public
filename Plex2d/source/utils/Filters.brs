function FiltersClass() as object
    if m.FiltersClass = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.Init = filtersInit
        obj.OnSortsResponse = filtersOnSortsResponse
        obj.OnFiltersResponse = filtersOnFiltersResponse

        obj.HasSorts = filtersHasSorts
        obj.HasTypes = filtersHasTypes
        obj.HasFilters = filtersHasFilters

        obj.IsAvailable = filtersIsAvailable
        obj.GetSelectedType = filtersGetSelectedType

        obj.GetSortOptions = filtersGetSortOptions
        obj.GetTypeOptions = filtersGetTypeOptions
        obj.GetFilterOptions = filtersGetFilterOptions

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

        obj.ParsePath = filtersParsePath
        obj.BuildPath = filtersBuildPath

        ' Constants
        obj.types = CreateObject("roAssociativeArray")
        obj.types["movie"] = [
            {title: "Movie", value: "1"}
        ]

        ' TODO(rob): Check with PMS for season filters/sorts. The PMS seems to give
        ' very little back, however the show filters/sorts work.
        obj.types["show"] = [
            {title: "Show", value: "2"},
            {title: "Season", value: "3"},
            {title: "Episode", value: "4"}
        ]
        obj.types["artist"] = [
            {title: "Artist", value: "8"},
            {title: "Album", value: "9"}
            {title: "Track", value: "10"}
        ]
        obj.types["photo"] = [
            {title: "Photo", value: "13"}
        ]

        m.FiltersClass = obj
    end if

    return m.FiltersClass
end function

function createFilters(item as object) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(FiltersClass())

    obj.Init(item)

    return obj
end function

sub filtersInit(item as object)
    ' TODO(rob): do we want to parse the current item for filter/sorts
    ' in the url. e.g. the unwatched button button and hubs that use
    ' a compatible filterd/sorted endpoint.

    ' Containers for available filters and sorts
    m.filterItems = CreateObject("roList")
    m.sortItems = CreateObject("roList")

    ' Containers for current filters, type and sorts
    m.currentSort = CreateObject("roAssociativeArray")
    m.currentType = CreateObject("roAssociativeArray")
    m.currentFilters = CreateObject("roList")

    ' TODO(rob): handle multi value types - toggle between/use existing
    if m.selectedTypeIndex = invalid then m.selectedTypeIndex = 0
    m.filterTypes = firstOf(m.types[item.Get("type", "")], [])

    m.sectionPath = item.GetSectionPath()
    m.originalPath = item.GetAbsolutePath("key")
    m.server = item.GetServer()

    if m.sectionPath = invalid then return

    m.Refresh()
end sub

sub filtersRefresh()
    m.ClearSort(true)
    m.ClearFilters()

    ' Filters request
    m.filterType = m.GetSelectedType()
    if m.filterType = invalid then return

    request = createPlexRequest(m.server, m.sectionPath + "/filters?type=" + m.filterType.value)
    context = request.CreateRequestContext("filters", createCallable("OnFiltersResponse", m))
    Application().StartRequest(request, context)

    ' Sorts request
    request = createPlexRequest(m.server, m.sectionPath + "/sorts?type=" + m.filterType.value)
    context = request.CreateRequestContext("sorts", createCallable("OnSortsResponse", m))
    Application().StartRequest(request, context)
end sub

sub filtersOnFiltersResponse(request as object, response as object, context as object)
    if not response.IsSuccess() then return
    response.ParseResponse()

    m.filterItems = response.items

    m.ParsePath(m.originalPath)
end sub

sub filtersOnSortsResponse(request as object, response as object, context as object)
    if not response.IsSuccess() then return
    response.ParseResponse()

    m.sortItems = response.items

    m.ClearSort(false)
    m.ParsePath(m.originalPath)
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
    return (m.filterTypes.Count() > 1)
end function

function filtersGetTypeOptions() as object
    return m.filterTypes
end function

function filtersGetSelectedType() as dynamic
    return m.filterTypes[m.selectedTypeIndex]
end function

sub filtersParsePath(path as string)
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
            if allowed.IsMatch(arg) then
                av = arg.tokenize("=")
                ' Do we need to url escape arg strings
                if av[0] = "sort" then
                    m.SetSort(av[1], false)
                else
                    m.SetFilter(av[0], av[1])
                end if
            end if
        end for
    else
        m.ClearSort(false)
        m.ClearFilters()
    end if

    Debug("Parsed url for filters and sorts: " + path)
    Debug("Sort: " + tostr(m.currentSort, 1))
    Debug("Filters: " + tostr(m.currentFilters.Count()))
    if m.currentFilters.Count() > 0 then
        for each filter in m.currentFilters
            Debug(tostr(filter, 1))
        end for
    end if
end sub

sub filtersClearSort(clearAll=false as boolean)
    if clearAll then
        m.Delete("defaultSortKey")
        m.currentSort.Clear()
        return
    end if

    ' Do not clean the sort, just set it back to the default.
    if m.defaultSortKey = invalid then
        for each plexObject in m.sortItems
            if plexObject.Has("default") then
                 m.defaultSortKey = plexObject.Get("key")
                exit for
            end if
        end for
    end if

    m.SetSort(m.defaultSortKey, false)
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
    ' TODO(rob): how do we handle this when it's too long? Obviously
    ' the component can truncate... but that's probably ugly.
    '   if m.currentFilters.Count() > 1 then return "MULTI FILTER"

    filterStringArr = []

    for each filter in m.currentFilters
        filterStringArr.Push(filter.plexObject.Get("title"))
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

sub filtersSetType(filterType as object)
    m.currentType.Clear()
    typeOptions = m.GetTypeOptions()
    for index = 0 to typeOptions.Count() - 1
        option = typeOptions[index]
        if filterType.value = option.value then
            m.selectedTypeIndex = index
            exit for
        end if
    end for

    m.Refresh()
end sub

sub filtersSetSort(key=invalid as dynamic, toggle=true as boolean)
    if key = invalid or key <> m.currentSort.defaultKey or toggle = false then
        m.ClearSort(true)
    end if

    if key = invalid or not m.HasSorts() then return

    for each sort in m.sortItems
        if instr(1, key, sort.Get("key")) > 0 then
            defaultKey = sort.Get("key")
            descKey = sort.Get("descKey", defaultKey)

            ' Set the new sort or toggle existing
            if m.currentSort.key = invalid then
                m.currentSort.key = iif(sort.Get("defaultDirection", "desc") = "desc", descKey, defaultKey)
            else if defaultKey = m.currentSort.key then
                m.currentSort.key = descKey
            else
                m.currentSort.key = defaultKey
            end if

            m.currentSort.defaultKey = defaultKey
            m.currentSort.plexObject = sort

            exit for
        end if
    end for
end sub

sub filtersToggleFilter(key as string)
    ' Logic to toggle is part of SetFilter, but this wrapper
    ' is used to alleviate confusion.
    m.SetFilter(key, "1", true)
end sub

sub filtersSetFilter(key as string, value=invalid as dynamic, toggle=false as boolean)
    if not m.HasFilters() then return

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
                exit for
            end if
        end for
    end if

    m.currentFilters = newFilters
end sub

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
