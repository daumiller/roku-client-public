function SettingsButtonClass() as object
    if m.SettingsButtonClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(BoolButtonClass())
        obj.ClassName = "SettingsButton"

        obj.OnSelected = settingsbuttonOnSelected

        m.SettingsButtonClass = obj
    end if

    return m.SettingsButtonClass
end function

function createSettingsButton(text as string, font as object, command as dynamic, value as string, prefType as string, storage=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(SettingsButtonClass())

    obj.command = command

    obj.Init(text, font, false)

    obj.prefType = prefType
    obj.value = value
    obj.storage = storage

    return obj
end function

sub settingsbuttonOnSelected(screen as object)
    prefKey = m.command

    if m.prefType = "bool" then
        prefValue = iif(m.isSelected, "0", "1")
    else if m.prefType = "enum" then
        prefValue = m.value

        m.selected = false
        ' uncheck any selected component and redraw
        for each comp in m.parent.components
            if comp.isSelected = true then
                comp.isSelected = false
                comp.Draw(true)
            end if
        end for
    else
        FATAL("invalid prefType: " + tostr(m.prefType))
    end if

    if m.storage <> invalid then
        Debug("Set local preference:" + prefKey + "=" + prefValue + " (type: " + m.prefType + ")")
        m.storage[prefKey] = prefValue
        m.overlay.Trigger("selected", [m.overlay, prefKey, prefValue])
    else
        Debug("Set preference:" + prefKey + "=" + prefValue + " (type: " + m.prefType + ")")
        AppSettings().SetPreference(prefKey, prefValue)
    end if

    ApplyFunc(BoolButtonClass().OnSelected, m, [screen])
end sub
