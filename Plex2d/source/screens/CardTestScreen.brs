function CardTestScreen() as object
    if m.CardTestScreen = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ComponentsScreen())

        obj.screenName = "CardTest"

        obj.GetComponents = cardTestGetComponents

        m.CardTestScreen = obj
    end if

    return m.CardTestScreen
end function

function createCardTestScreen() as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(CardTestScreen())

    obj.Init()

    return obj
end function

sub cardTestGetComponents()
    m.components.Clear()

    card = createCard("https://plex.tv/assets/img/pms-icon-f921d4d3a1a02c4437faa9e7fd4ba5cc.png", "Test Overlay")
    card.SetFrame(1280/2-100, 720/2-100, 200, 200)

    m.components.Push(card)
end sub
