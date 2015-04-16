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

sub filterboxInit(item as object)
    ApplyFunc(HBoxClass().Init, m)

    m.item = item

    ' Try to reuse the existing filters object
    if m.screen.filterBox <> invalid then
        m.filters = m.screen.filterBox.filters
    else
        m.filters = CreateFilters(m.item)
    end if

    ' This is a sneaky way to make sure that the screen always has
    ' the filterBox object
    '
    m.screen.filterBox = m

    m.customFonts = {
        glyph: FontRegistry().GetIconFont(20)
    }

    m.colors = {
        text: Colors().Text,
        textFocus: Colors().Black,
        button: Colors().Button,
        buttonFocus: Colors().Orange,
        buttonSelected: Colors().ButtonLht
    }
end sub

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
        focusMethod: ButtonClass().FOCUS_BACKGROUND,
        focusMethodColor: m.colors.buttonFocus,
        fgColorFocus: m.colors.textFocus
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

            ' Unwatched filter button
            filter = filters.GetUnwatchedOption()
            if filter <> invalid then
                option = filterButton.AddCallableButton(createBoolButton, [ucase(filter.Get("title")), m.optionPrefs.font, "filter_unwatched", filters.IsUnwatched()])
                option.plexObject = filter
                option.bgColor = Colors().ButtonDark
                option.Append(m.optionPrefs)
            end if

            ' Clear Filters button
            if filters.GetFilters() <> invalid then
                option = filterButton.AddCallableButton(createGlyphButton, ["CLEAR FILTER", m.optionPrefs.font, Glyphs().CIR_X, m.customFonts.glyph, "filter_clear"])
                option.bgColor = Colors().ButtonDark
                option.Append(m.optionPrefs)
            end if

            ' Filter buttons
            for each filter in filters.GetFilterOptions()
                title = filter.Get("title")

                ' This will be used by all filter types
                isEnabled = filters.IsFilteredByKey(filter.Get("filter"))

                if filter.Get("filterType") = "boolean" then
                    option = filterButton.AddCallableButton(createBoolButton, [title, m.optionPrefs.font, "filter_boolean", isEnabled])
                else
                    ' TODO(rob): modify button to handle a check mark, to reflect status of isEnabled
                    option = filterButton.AddCallableButton(createDropDownButton, [title, m.optionPrefs.font, m.screen, false])
                    option.dropdownPosition = "right"
                    option.dropdownSpacing = 1
                end if

                ' Augment the options for both boolean and dropdown option
                option.plexObject = filter
                option.Append(m.optionPrefs)
            end for
        end if

        ' Types [optional]
        if filters.HasTypes() and filters.GetSelectedType() <> invalid then
            title = filters.GetSelectedType().title
            typesButton = createDropDownButton(ucase(title), m.font, m.screen, false)
            typesButton.SetPadding(0, 10, 0, 10)
            typesButton.SetDropDownPosition("down", 0)

            selectedType = filters.GetSelectedType()
            for each item in filters.GetTypeOptions()
                glyph = iif(selectedType <> invalid and selectedType.value = item.value, Glyphs().CHECK, " ")

                option = typesButton.AddCallableButton(createGlyphButton, [item.title, m.optionPrefs.font, glyph, m.customFonts.glyph, "filter_type"])
                option.metadata = item
                option.Append(m.optionPrefs)
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

    if command = "filter_clear" then
        m.filters.ClearFilters(true)
    else if command = "filter_set" then
        m.filters.SetFilter(m.metadata.filter, m.metadata.key, m.metadata.title)
    else if command = "filter_unwatched" then
        m.filters.ToggleUnwatched(plexObject.Get("filter"))
    else if m.command = "filter_type" then
        m.filters.SetType(m.metadata)
    else if command = "filter_boolean" then
        m.filters.ToggleFilter(plexObject.Get("filter"))
    else if command = "sort" then
        m.filters.SetSort(plexObject.Get("key"))
    else if command = "show_dropdown" then
        m.SetColor(filterBox.colors.text, filterBox.colors.buttonSelected)
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
                option.metadata = { filter: filterKey, key: item.Get("key"), title: item.Get("title")}
                option.Append(filterBox.optionPrefs)
                m.options.Push(option)
            end for
            screen.HandleCommand(m.command, m)
        end if
    end if
end sub
