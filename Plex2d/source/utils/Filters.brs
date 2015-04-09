function FiltersClass() as object
    if m.FiltersClass = invalid then
        obj = CreateObject("roAssociativeArray")

        ' Methods
        obj.Init = filtersInit
        obj.OnFiltersResponse = filtersOnFiltersResponse
        obj.OnSortsResponse = filtersOnSortsResponse
        obj.HasFilters = filtersHasFilters
        obj.HasSorts = filtersHasSorts
        obj.HasTypes = filtersHasTypes
        obj.GetTypes = filtersGetTypes
        obj.IsAvailable = filtersIsAvailable
        obj.GetSelectedType = filtersGetSelectedType

        ' Constants
        obj.types = CreateObject("roAssociativeArray")
        obj.types["movie"] = [
            {title: "Movie", value: "1"}
        ]
        obj.types["show"] = [
            {title: "Show", value: "2"},
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
    m.filters = CreateObject("roList")
    m.sorts = CreateObject("roList")

    ' TODO(rob): handle multi value types - toggle between/use existing
    if m.selectedTypeIndex = invalid then m.selectedTypeIndex = 0
    m.sectionTypes = firstOf(m.types[item.Get("type", "")], [])

    m.sectionType = m.GetSelectedType()
    m.sectionPath = item.GetSectionPath()
    if m.sectionPath = invalid or m.sectionType = invalid then return

    m.server = item.GetServer()
    m.cacheKey = tostr(m.server.uuid) + "!" + tostr(m.sectionPath)

    ' Filters request
    request = createPlexRequest(m.server, m.sectionPath + "/filters?type=" + m.sectionType.value)
    context = request.CreateRequestContext("filters", createCallable("OnFiltersResponse", m))
    Application().StartRequest(request, context)

    ' Sorts request
    request = createPlexRequest(m.server, m.sectionPath + "/sorts?type=" + m.sectionType.value)
    context = request.CreateRequestContext("sorts", createCallable("OnSortsResponse", m))
    Application().StartRequest(request, context)
end sub

sub filtersOnFiltersResponse(request as object, response as object, context as object)
    if not response.IsSuccess() then return
    response.ParseResponse()

    m.filters = response.items
end sub

sub filtersOnSortsResponse(request as object, response as object, context as object)
    if not response.IsSuccess() then return
    response.ParseResponse()

    m.sorts = response.items
end sub

function filtersHasFilters() as boolean
    return (m.filters.Count() > 0)
end function

function filtersHasSorts() as boolean
    return (m.sorts.Count() > 0)
end function

function filtersIsAvailable() as boolean
    return (m.HasFilters() or m.HasSorts())
end function

function filtersHasTypes() as boolean
    return (m.sectionTypes.Count() > 1)
end function

function filtersGetTypes() as object
    return m.sectionTypes
end function

function filtersGetSelectedType() as dynamic
    return m.sectionTypes[m.selectedTypeIndex]
end function