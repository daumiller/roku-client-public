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
        obj.OnClosed = filterboxOnClosed

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
    m.DisableNonParentExit("right")

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
        button: Colors().ButtonMed,
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

    ' Refresh our unwatched boolean
    m.isUnwatched = m.filters.IsUnwatched()

    ' Dropdown button properties
    dropdownBorder = {px: 2, color: Colors().Border}
    dropdownPosition = "right"

    ' Values the dropdown will verify and use for options
    m.optionPrefs = {
        halign: "JUSTIFY_LEFT",
        padding: {right: 50, left: 20, top: 0, bottom: 0}
        font: FontRegistry().NORMAL,
        focusMethod: ButtonClass().FOCUS_BACKGROUND,
        focusMethodColor: m.colors.buttonFocus,
        fgColorFocus: m.colors.textFocus,
        bgColor: m.colors.button
    }

    ' Values the dropdown will blindly append to options
    m.optionPrefs.fields = {
        OnSelected: m.OnSelected,
        filters: m.filters,
        dropdownBorder: dropdownBorder,
        dropdownMinWidth: 170,
        height: 50
    }

    ' Values for the multi-leve flyouts
    m.secondaryOptionPrefs = CreateObject("roAssociativeArray")
    m.secondaryOptionPrefs.Append(m.optionPrefs)
    m.secondaryOptionPrefs.padding = {right: 20, left: 20, top: 0, bottom: 0}

    if filters.IsAvailable() then
        dropdowns = CreateObject("roList")
        ' Filters
        if filters.HasFilters() then
            title = firstOf(filters.GetFilterTitle(), "ALL")
            filterButton = createDropDownButton(ucase(title), m.font, m.screen, false)
            filterButton.OnClosed = m.OnClosed
            m.AddComponent(filterButton)
            dropdowns.Push(filterButton)

            ' Unwatched filter button
            filter = filters.GetUnwatchedOption()
            if filter <> invalid then
                option = filterButton.AddCallableButton(createBoolButton, [ucase(filter.Get("title")), m.optionPrefs.font, "filter_unwatched", m.IsUnwatched])
                option.plexObject = filter
                option.Append(m.optionPrefs)
                option.bgColor = Colors().Button
            end if

            ' Clear Filters button
            if filters.GetFilters() <> invalid then
                option = filterButton.AddCallableButton(createGlyphButton, ["CLEAR FILTER", m.optionPrefs.font, Glyphs().CIR_X, m.customFonts.glyph, "filter_clear"])
                option.Append(m.optionPrefs)
                option.bgColor = Colors().Button
            end if

            ' Filter buttons
            for each filter in filters.GetFilterOptions()
                title = filter.Get("title")

                ' This will be used by all filter types
                isEnabled = filters.IsFilteredByKey(filter.Get("filter"))

                if filter.Get("filterType") = "boolean" then
                    option = filterButton.AddCallableButton(createBoolButton, [title, m.optionPrefs.font, "filter_boolean", isEnabled])
                else
                    glyph = iif(isEnabled, Glyphs().CHECK, " ")
                    option = filterButton.AddCallableButton(createGlyphDropDownButton, [title, m.optionPrefs.font, glyph, m.customFonts.glyph, m.screen])
                    option.dropdownPosition = dropdownPosition
                    option.dropdownSpacing = dropdownBorder.px
                end if

                ' Augment the options for both boolean and dropdown option
                option.plexObject = filter
                option.Append(m.optionPrefs)
            end for
        end if

        ' Types
        selectedType = filters.GetSelectedType()
        if filters.HasTypes() and selectedType <> invalid
            typesButton = createDropDownButton(ucase(selectedType.title), m.font, m.screen, false)
            m.AddComponent(typesButton)
            dropDowns.Push(typesButton)

            selectedType = filters.GetSelectedType()
            for each item in filters.GetTypeOptions()
                glyph = iif(selectedType <> invalid and selectedType.value = item.value, Glyphs().CHECK, " ")

                option = typesButton.AddCallableButton(createGlyphButton, [item.title, m.optionPrefs.font, glyph, m.customFonts.glyph, "filter_type"])
                option.metadata = item
                option.Append(m.optionPrefs)
            end for
        else if selectedType <> invalid then
            ' Add a hard coded label for spacing if there's only one type
            label = createLabel(ucase(selectedType.title), m.optionPrefs.font)
            m.AddComponent(label)
        end if

        ' Sorts
        if filters.HasSorts() then
            title = firstOf(filters.GetSortTitle(), "SORT")
            sortButton = createDropDownButton(ucase(title), m.font, m.screen, false)
            m.AddComponent(sortButton)
            dropdowns.Push(sortButton)

            ' Sort options
            for each sort in filters.GetSortOptions()
                sortDirection = filters.GetSortDirection(sort.Get("key"))

                option = sortButton.AddCallableButton(createSortButton, [sort.Get("title"), sortDirection, m.optionPrefs.font, m.customFonts.glyph, "sort"])
                option.plexObject = sort
                option.Append(m.optionPrefs)
            end for
        end if

        ' Common dropdown setttings
        for each dropDown in dropDowns
            dropdown.SetPadding(0, 10, 0, 10)
            dropdown.SetDropDownPosition("down", dropdownBorder.px)
            dropdown.SetDropDownBorder(dropdownBorder.px, dropdownBorder.color)
        end for

        width = m.GetPreferredWidth()
        m.setFrame(m.x - width, m.y, width, m.GetPreferredHeight())

        ' Draw the new/updated components
        m.screen.screen.DrawComponent(m, m.screen)
    end if

    ' Refresh available components (filterBox updated)
    m.screen.RefreshAvailableComponents()

    m.screen.screen.DrawAll()
end sub

sub filterboxOnFilterSet(subject=invalid as dynamic)
    m.screen.Refresh(m.filters.BuildPath(), false)
end sub

sub filterboxOnSelected(screen as object)
    ' We're evaluated in the context of a dropdown option, but we have
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
        m.SetSelected(screen)
    else if m.command = "filter_type" then
        m.filters.SetType(m.metadata)
    else if command = "filter_boolean" then
        m.filters.ToggleFilter(plexObject.Get("filter"))
    else if command = "sort" then
        m.filters.SetSort(plexObject.Get("key"))
    else if command = "show_dropdown" then
        ' Toggle button color and glyph
        m.SetColor(filterBox.colors.text, filterBox.colors.buttonSelected)
        m.SetGlyph(Glyphs().ARROW_RIGHT, true, true)
        m.SetColor(filterBox.colors.text, filterBox.colors.button)

        m.options = CreateObject("roList")
        size = m.filters.GetFilterOptionSize(plexObject)
        if size > 0 then
            ' Show a loading flyout based on an arbitrary size
            if size > 500 then
                option = {text: "loading..."}
                option.Append(filterBox.optionPrefs)
                m.options.Push(option)
                m.Show()

                ' Clear options, lock the screen and close the loading
                ' flyout. It will unlock once the real data is loaded.
                m.options.Clear()
                screen.screen.DrawLockOnce()
                m.overlay.Close(false, false)
            end if

            filterKey = plexObject.Get("filter")
            selectedKey = firstOf(m.filters.GetFilteredByKey(filterKey), {}).value

            for each item in m.filters.GetFilterOptionValues(plexObject)
                option = {text: item.Get("title"), command: "filter_set"}
                option.metadata = {filter: filterKey, key: item.Get("key"), title: option.text}
                option.Append(filterBox.secondaryOptionPrefs)
                option.isSelected = (selectedKey <> invalid and selectedKey = option.metadata.key)
                m.options.Push(option)
            end for
        end if

        if m.options.Count() = 0 then
            option = {text: "Empty"}
            option.Append(filterBox.optionPrefs)
            m.options.Push(option)
        end if

        m.Show()
        screen.screen.DrawUnlock()
    end if
end sub

sub filterboxOnClosed(overlay as object, backButton as boolean)
    ' We're evaluated in the context of a dropdown button. The button
    ' has a reference to the parent, which is the filterBox.
    filterBox = m.parent
    refresh = false

    ' Check for any changes (unwatched flag)
    isUnwatched = filterBox.filters.IsUnwatched()
    if isUnwatched <> filterBox.IsUnwatched then
        refresh = true
    end if
    filterBox.IsUnwatched = isUnwatched

    ' Refresh the screen if we have changes
    if refresh then
        filterBox.OnFilterSet()
    end if
end sub
