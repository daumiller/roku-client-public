function BoxClass() as object
    if m.BoxClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(ContainerClass())
        obj.Append(AlignmentMixin())

        ' TODO(schuyler): Figure out how best to generalize HBox and VBox here

        m.BoxClass = obj
    end if

    return m.BoxClass
end function
