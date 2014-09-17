function HubClass() as object
    if m.HubClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(HBoxClass())
        obj.ClassName = "Hub"

        obj.Build = hubBuild

        m.HubClass = obj
    end if

    return m.HubClass
end function

function createHub(hubObject as object, spacing=0 as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(HubClass())

    ' TODO(rob) use a real hub object
    obj.hubObject = hubObject

    obj.Init()

    obj.homogeneous = false
    obj.expand = false
    obj.fill = false
    obj.spacing = spacing

    obj.Build()

    return obj
end function

' This is completely temporary. It's just a way to build some dynamic hubs
sub hubBuild()
    items = m.hubObject.items
    htype = m.hubObject.htype

    if items = invalid or htype = invalid or items.count() = 0 then return

    ' HBOX/VBOX: 1 Hero, 4 Portrait
    if htype = 1 then
        for index = 0 to 4
            item = items[index]
            if index = 0 then
                ' col = createImage(item.poster +"?w=295&h=434", 295, 434)
                ' TODO(rob/schuyler) I don't see how to set the preferred card
                ' height. It's seems to be overriden by the parent.
                col = createCard(item.poster +"?w=295&h=434", "Card Test")
                col.SetFrame(0, 0, 295, 434)
                m.AddComponent(col)
            else
                col = createVBox(false, false, false, 10)
                for incr = 0 to 1
                    index = index+incr
                    item = items[index]
                    img = createImage(item.poster +"?w=144&h=212", 144, 212)
                    col.AddComponent(img)
                end for

                m.AddComponent(col)
            end if
        end for
    ' VBOX: 3 Art
    else if htype = 2 then
        col1 = createVBox(false, false, false, 10)
        for count = 0 to 2
            item = items[count]
            img = createImage(item.art +"?w=245&h=138", 245, 138)
            col1.AddComponent(img)
        end for
        m.AddComponent(col1)
    ' VBOX: 2 Art
    else if htype = 3 then
        col1 = createVBox(false, false, false, 10)
        for count = 0 to 1
            item = items[count]
            img = createImage(item.art +"?w=377&h=212", 377, 212)
            col1.AddComponent(img)
        end for
        m.AddComponent(col1)
    end if
end sub
