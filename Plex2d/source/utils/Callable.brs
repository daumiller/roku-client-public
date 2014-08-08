function CallableClass() as object
    if m.CallableClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "Callable"

        obj.Call = callableCall

        m.CallableClass = obj
    end if

    return m.CallableClass
end function

function createCallable(func as dynamic, context as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(CallableClass())

    obj.func = func
    obj.context = context

    return obj
end function

function callableCall(args=[] as object) as dynamic
    this = firstOf(m.context, m)

    if isstr(m.func) then
        methodName = m.func
    else
        methodName = "tempBoundFunc"
        this[methodName] = m.func
    end if

    if args.Count() = 0 then
        result = this[methodName]()
    else if args.Count() = 1 then
        result = this[methodName](args[0])
    else if args.Count() = 2 then
        result = this[methodName](args[0], args[1])
    else if args.Count() = 3 then
        result = this[methodName](args[0], args[1], args[2])
    else
        Error("Callable doesn't currently support " + tostr(args.Count()) + " arguments!")
        stop
    end if

    this.Delete("tempBoundFunc")
    return result
end function
