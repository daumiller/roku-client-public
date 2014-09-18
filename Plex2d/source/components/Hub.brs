function HubClass() as object
    if m.HubClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.Append(AlignmentMixin())
        obj.ClassName = "Hub"

        obj.PerformLayout = hubPerformLayout

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
        hbox = createHBox(false, false, false, m.spacing)
        hbox.setFrame(0, 0, 295+144+144+(m.spacing*2), 434)
        for index = 0 to 4
            item = items[index]
            if index = 0 then
                card = createCard(item.poster +"?w=295&h=434", "295, 434")
                card.SetFrame(0, 0, 295, 434)
                hbox.AddComponent(card)
            else
                vb = createVBox(false, false, false, m.spacing)
                for incr = 0 to 1
                    index = index+incr
                    item = items[index]
                    card = createCard(item.poster +"?w=144&h=212", "144, 212")
                    card.setFrame(0, 0, 144, 212)
                    vb.AddComponent(card)
                end for
                hbox.AddComponent(vb)
            end if
        end for
        m.AddComponent(hbox)
        m.setFrame(0, 0, hbox.width, hbox.height)
    ' VBOX: 3 Art
    else if htype = 2 then
        vb = createVBox(false, false, false, m.spacing)
        vb.setFrame(0, 0, 245, 138*3)
        for count = 0 to 2
            item = items[count]
            card = createCard(item.art +"?w=245&h=138", "245, 138")
            card.setFrame(0, 0, 245, 138)
            vb.AddComponent(card)
        end for
        m.AddComponent(vb)
        m.setFrame(0, 0, vb.width, vb.height)
    ' VBOX: 2 Art
    else if htype = 3 then
        vb = createVBox(false, false, false, m.spacing)
        vb.setFrame(0, 0, 245, 138*2)
        for count = 0 to 1
            item = items[count]
            card = createCard(item.art +"?w=377&h=212", "377, 212")
            card.setFrame(0, 0, 377, 212)
            vb.AddComponent(card)
        end for
        m.AddComponent(vb)
        m.setFrame(0, 0, vb.width, vb.height)
    end if
end sub

sub hubPerformLayout()
    m.needsLayout = false
    numChildren = m.components.Count()

    ' Strange, but let's not even bother with the complicated stuff if we don't need to.
    if numChildren = 0 then return

    m.components.Reset()

    while m.components.IsNext()
        component = m.components.Next()
        width = component.GetPreferredWidth()
        height = component.GetPreferredHeight()

        component.SetFrame(m.x, m.y, width, height)
    end while
end sub
