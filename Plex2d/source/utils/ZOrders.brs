function ZOrders() as object
    if m.ZOrders = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.HEADER = 10
        obj.DESCBOX = 10
        obj.DROPDOWN = 20
        obj.OVERLAY = 30
        obj.MODAL = 100
        obj.MINIPLAYER = obj.HEADER + 1
        obj.SCROLLBAR = obj.MODAL - 1

        m.ZOrders = obj
    end if

    return m.ZOrders
end function
