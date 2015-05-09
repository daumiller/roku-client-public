function JumpVBoxClass() as object
    if m.JumpVBoxClass = invalid then
        obj = createObject("roAssociativeArray")
        obj.Append(VBoxClass())
        obj.ClassName = "JumpVBox"

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

    alpha = ["#","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z"]
    for each ch in alpha
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
    last = invalid
    for index = 0 to components.Count() - 1
        comp = components[index]
        if comp.text <> invalid then
            ch = ucase(left(comp.text, 1))

            ' Group non-alpha characters and empty strings together.
            ' Characters encoded as 2+ bytes are just treated as normal chars
            c = asc(ch)
            if ((c >= 0 and c <= 64) or (c >= 91 and c <= 96) or (c >= 123 and c <= 126)) then
                ch = "#"
            end if

            if list[ch] = invalid then
                list[ch] = CreateObject("roAssociativeArray")
                list[ch].components = CreateObject("roList")
                list[ch].index = tostr(index)
                list[ch].component = comp
                total = total + 1
                last = ch
            else if last <> ch then
                ' Exclude jump list for non-alpha ordering

                ' TODO(rob): https://github.com/plexinc/plex-media-server/issues/2857
                ' Temporary exclusion to try harder to show the alpha list for
                ' studios. Studios are arranged A-Z, a-z. We could add better
                ' logic, but it's a bug in the PMS that will be fixed.
                '
                if total > 15 then
                    Debug("List not in alphabetical order, but we'll include the jump list because we have " + tostr(total) + " items")
                else
                    Debug("List not in alphabetical order. Last=" + last + ", cur=" + ch + " (" + tostr(comp.text) + ")")
                    return invalid
                end if

                ' We can exist regardless since the order is no longer alphabetic
                exit for
            end if

            ' Keep a list of matching content list components
            list[ch].components.Push(comp)
        end if
    end for

    return iif(total > 1, list, invalid)
end function
