function CallableClass() as object
    if m.CallableClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.ClassName = "Callable"

        obj.Call = callableCall
        obj.Equals = callableEquals

        GetGlobalAA()["nextCallableId"] = 0

        m.CallableClass = obj
    end if

    return m.CallableClass
end function

function createCallable(func as dynamic, context as dynamic, id=invalid as dynamic, forcedArgs=invalid as dynamic) as object
    obj = CreateObject("roAssociativeArray")

    obj.Append(CallableClass())

    obj.func = func
    obj.context = context
    obj.forcedArgs = forcedArgs

    ' Since we can't do a reference equality check on context, if a particular
    ' callable wants to allow equality checks, it can pass an ID. If no ID is
    ' passed, try to default to the context's ID.
    if context = invalid then
        obj.id = id
    else
        obj.id = firstOf(id, context.uniqId, context.id, context.screenId)
    end if

    if obj.id = invalid then
        GetGlobalAA()["nextCallableId"] = GetGlobalAA()["nextCallableId"] + 1
        obj.id = GetGlobalAA()["nextCallableId"]
    end if

    if isstr(func) and type(context[func]) <> "roFunction" then
        Fatal(func + " not found on object")
    end if

    return obj
end function

function callableCall(args=[] as object) as dynamic
    this = firstOf(m.context, m)
    if m.forcedArgs <> invalid then args = m.forcedArgs

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
        Fatal("Callable doesn't currently support " + tostr(args.Count()) + " arguments!")
    end if

    this.Delete("tempBoundFunc")
    return result
end function

function callableEquals(other as dynamic) as boolean
    if other = invalid then return false
    if m.ClassName <> other.ClassName then return false
    return (m.id <> invalid and m.id = other.id)
end function
