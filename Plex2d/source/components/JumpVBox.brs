function JumpVBoxClass() as object
    if m.JumpVBoxClass = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(VBoxClass())
        obj.ClassName = "JumpVBox"
        obj.alpha = ["#","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]

        ' Methods
        obj.Init = jvboxInit

        m.JumpVBoxClass = obj
    end if

    return m.JumpVBoxClass
end function

function createJumpVBox(vbox as object, jumpList as object, font as object, width=40 as integer, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(JumpVBoxClass())

    obj.contentVBox = vbox
    obj.jumpList = jumpList
    obj.font = font
    obj.width = width
    obj.spacing = spacing

    obj.Init()

    obj.homogeneous = true
    obj.expand = true
    obj.fill = true

    ' Add a reference to the content VBox
    obj.contentVBox.jumpVBox = obj

    return obj
end function

sub jvboxInit()
    ApplyFunc(VBoxClass().Init, m)

    m.DisableNonParentExit("down")
    m.DisableNonParentExit("up")

    vboxRect = computeRect(m.contentVBox)
    m.SetFrame(vboxRect.right + 1, vboxRect.up, m.width, vboxRect.height)

    for each ch in m.alpha
        ch = ucase(ch)
        if m.jumpList[ch] <> invalid then
            comp = createButton(ch, m.font, "vbox_jump")
            comp.SetMetadata(m.jumpList[ch])
            comp.SetColor(Colors().Text, Colors().Button, Colors().Button)
            comp.SetFocusMethod(comp.FOCUS_BACKGROUND, Colors().ButtonLht)
            comp.OnFocus = jvboxItemOnFocus

            ' Add a reference to the content list components for this jumpItem
            for each component in m.jumpList[ch].components
                component.jumpItem = comp
            end for
        else
            comp = createLabel(ch, m.font)
            comp.SetColor(Colors().Subtitle, Colors().Button)
            comp.halign = comp.JUSTIFY_CENTER
        end if
        comp.width = m.width
        m.AddComponent(comp)
    end for
end sub

sub jvboxItemOnFocus()
    if not m.SpriteIsLoaded() then return

    if m.parent.focusedItem <> invalid then
        if m.Equals(m.parent.focusedItem) and m.isFocused = true then return
        m.parent.focusedItem.OnBlur()
    end if

    ApplyFunc(ButtonClass().OnFocus, m)
    m.parent.focusedItem = m
end sub

' Derive the jump list from the content list components. Hopefully the
' PMS will help with this in the future
'
function GetJumpList(components as object) as dynamic
    list = CreateObject("roAssociativeArray")

    total = 0
    lastDec = -1
    regexAlpha = CreateObject("roRegex", "[A-Z]", "i")
    for index = 0 to components.Count() - 1
        comp = components[index]
        if comp.text <> invalid then
            ch = ucase(left(comp.text, 1))

            ' Group non-alpha characters and empty strings together.
            ' Characters encoded as 2+ bytes are just treated as normal chars
            dec = asc(ch)
            if ((dec >= 0 and dec <= 64) or (dec >= 91 and dec <= 96) or (dec >= 123 and dec <= 126)) then
                ch = "#"
                dec = asc(ch)
            end if

            ' Exclude jump list for non-alpha ordering

            ' TODO(rob): remove `total < 15`
            ' Temporary exclusion to try harder to show the alpha list for
            ' studios. Studios are arranged A-Z, a-z. We could add better
            ' logic, but it's a bug in the PMS that will be fixed.
            ' GHI: https://github.com/plexinc/plex-media-server/issues/2857
            '
            if total < 15 and regexAlpha.IsMatch(ch) and dec < lastDec then
                Debug("Exclude jump list, list not in alphabetical order")
                return invalid
            end if
            lastDec = dec

            if list[ch] = invalid then
                list[ch] = CreateObject("roAssociativeArray")
                list[ch].components = CreateObject("roList")
                list[ch].index = tostr(index)
                list[ch].component = comp
                total = total + 1
            end if

            ' Keep a list of matching content list components
            list[ch].components.Push(comp)
        end if
    end for

    return iif(total > 1, list, invalid)
end function
