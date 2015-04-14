function FilterBoxClass() as object
    if m.FilterBoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HBoxClass())
        obj.ClassName = "FilterBox"

        ' Methods
        obj.Init = filterboxInit
        obj.Show = filterboxShow

        ' Child methods
        obj.OnSelected = filterboxOnSelected

        ' Filter listeners
        obj.OnFilterRefresh = filterboxOnFilterRefresh
        obj.OnFilterSet = filterboxOnFilterSet

        m.FilterBoxClass = obj
    end if

    return m.FilterBoxClass
end function

function createFilterBox(font as object, item as object, screen as object, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(FilterBoxClass())

    obj.font = font
    obj.screen = screen
    obj.spacing = spacing

    obj.Init(item)

    ' Box defaults
    obj.homogeneous = false
    obj.expand = false
    obj.fill = false

    return obj
end function

function filterboxInit(item)
    ApplyFunc(HBoxClass().Init, m)

    m.item = item
    m.filters = CreateFilters(m.item)

    ' This is a sneaky way to make sure that the screen always has
    ' the filterBox object
    '
    m.screen.filterBox = m

    m.colors = {
        text: Colors().Text,
        button: Colors().Button,
        highlight: Colors().ButtonLht,
        focused: Colors().Orange
    }

end function

sub filterboxShow()
    m.AddListener(m.filters, "refresh", CreateCallable("OnFilterRefresh", m))
    m.AddListener(m.filters, "set_filter", CreateCallable("OnFilterSet", m))
    m.AddListener(m.filters, "set_sort", CreateCallable("OnFilterSet", m))
    m.AddListener(m.filters, "set_type", CreateCallable("OnFilterSet", m))

    m.filters.Refresh()
end sub

sub filterboxOnFilterRefresh(filters as object)
    m.DestroyComponents()
    m.components.Clear()

    m.optionPrefs = {
        halign: "JUSTIFY_LEFT",
        height: 50,
        padding: {right: 50, left: 20, top: 0, bottom: 0}
        font: FontRegistry().NORMAL,
        focus_background: m.colors.focused
    }

    m.optionPrefs.fields = {
        OnSelected: m.OnSelected,
        filters: m.filters
    }

    if filters.IsAvailable() then
        ' Filters
        if filters.HasFilters() then
            title = firstOf(filters.GetFilterTitle(), "ALL")
            filterButton = createDropDownButton(ucase(title), m.font, m.screen, false)
            filterButton.SetPadding(0, 10, 0, 10)
            filterButton.SetDropDownPosition("down", 0)
            m.AddComponent(filterButton)

            ' Filter boolean options
            for each filter in filters.GetFilterOptions()
                if filter.Get("filterType") = "boolean" then
                    option = {text: filter.Get("title"), plexObject: filter, command: "filter_" + filter.Get("filterType")}

                    ' TODO(rob): use a better method to set the boolean value. I'm not aware
                    ' of any other boolean filters, than unwatched, which will end up having
                    ' it's own logic since it's special.
                    option.isBoolean = true
                    for each curFilter in m.filters.currentFilters
                        if curFilter.isBoolean = true and curFilter.key = filter.Get("filter") then
                            option.booleanValue = true
                        end if
                    end for

                    option.Append(m.optionPrefs)
                    filterButton.options.Push(option)
                end if
            end for

            ' Filter: non-boolean options
            for each filter in filters.GetFilterOptions()
                if filter.Get("filterType") <> "boolean" then
                    option = {text: filter.Get("title"), plexObject: filter}
                    option.isDropDown = true
                    option.dropdownSpacing = 1
                    option.dropdownPosition = "right"
                    option.Append(m.optionPrefs)
                    filterButton.options.Push(option)
                end if
            end for
        end if

        ' Types [optional]
        if filters.HasTypes() and filters.GetSelectedType() <> invalid then
            title = filters.GetSelectedType().title
            typesButton = createDropDownButton(ucase(title), m.font, m.screen, false)
            typesButton.SetPadding(0, 10, 0, 10)
            typesButton.SetDropDownPosition("down", 0)
            for each fType in filters.GetTypeOptions()
                option = {text: fType.title, metadata: fType, command: "filter_type"}
                option.Append(m.optionPrefs)
                typesButton.options.Push(option)
            end for
            m.AddComponent(typesButton)
        end if

        ' Sorts
        if filters.HasSorts() then
            title = firstOf(filters.GetSortTitle(), "SORT")
            sortButton = createDropDownButton(ucase(title), m.font, m.screen, false)
            sortButton.SetPadding(0, 10, 0, 10)
            sortButton.SetDropDownPosition("down", 0)
            m.AddComponent(sortButton)

            ' Sort options
            for each sort in filters.GetSortOptions()
                ' <Directory defaultDirection="desc" descKey="originallyAvailableAt:desc" key="originallyAvailableAt" title="First Aired"/>
                option = {text: sort.Get("title"), plexObject: sort, command: "sort"}
                option.Append(m.optionPrefs)
                sortButton.options.Push(option)
            end for
        end if

        width = m.GetPreferredWidth()
        m.setFrame(m.x - width, m.y, width, m.GetPreferredHeight())

        ' Draw the new/updated components
        m.screen.screen.DrawComponent(m, m.screen)
    end if

    ' Refresh available components (filterBox updated)
    m.screen.RefreshAvailableComponents()

    m.screen.screen.DrawAll()
end sub

sub filterboxOnFilterSet(filters as object)
    m.screen.Refresh(filters.BuildPath(), false)
end sub

sub filterboxOnSelected(screen as object)
    ' We're evaluated in the context of a dropdown button, but we have
    ' referenced the filters and the screen is passed as an argument, so
    ' hopefully that will alleviate any confusion.
    if m.command = invalid or m.filters = invalid then return

    filterBox = screen.filterBox
    plexObject = m.plexObject
    command = m.command

    if command = "filter_set" then
        m.filters.SetFilter(m.metadata.filter, m.metadata.key)
    else if m.command = "filter_type" then
        m.filters.SetType(m.metadata)
    else if command = "filter_boolean" then
        m.filters.ToggleFilter(plexObject.Get("filter"))
    else if command = "sort" then
        m.filters.SetSort(plexObject.Get("key"))
    else if command = "show_dropdown" then
        m.SetColor(filterBox.colors.text, filterBox.colors.highlight)
        m.Draw(true)
        m.SetColor(filterBox.colors.text, filterBox.colors.button)

        values = m.filters.GetFilterOptionValues(plexObject)

        if values.Count() = 0 then
            createDialog(plexObject.Get("title", "") + " filter is empty", invalid, screen).Show(true)
            return
        else
            filterKey = plexObject.Get("filter")
            m.options = CreateObject("roList")
            for each item in values
                option = {text: item.Get("title"), command: "filter_set"}
                option.metadata = { filter: filterKey, key: item.Get("key")}
                option.Append(filterBox.optionPrefs)
                m.options.Push(option)
            end for
            screen.HandleCommand(m.command, m)
        end if
    end if
end sub
