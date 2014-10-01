' Mostly standard helpers borrowed from SDK examples
' TODO(schuyler): Clean up some of these functions

function tostr(any as dynamic) as string
    ret = AnyToString(any)
    if ret = invalid and any <> invalid and type(any.ToString) = "roFunction" then
        ret = any.ToString()
    end if
    if ret = invalid ret = type(any)
    if ret = invalid ret = "unknown" 'failsafe
    return ret
end function

function AnyToString(any as dynamic) as dynamic
    if any = invalid return "invalid"
    if isstr(any) return any
    if isint(any) return numtostr(any)
    if GetInterface(any, "ifBoolean") <> invalid
        if any = true return "true"
        return "false"
    endif
    if GetInterface(any, "ifFloat") <> invalid then return numtostr(any)
    if type(any) = "roTimespan" return numtostr(any.TotalMilliseconds()) + "ms"
    return invalid
end function

function isstr(obj as dynamic) as boolean
    if obj = invalid return false
    if GetInterface(obj, "ifString") = invalid return false
    return true
end function

function isint(obj as dynamic) as boolean
    if obj = invalid return false
    if GetInterface(obj, "ifInt") = invalid return false
    return true
end function

function validint(obj as dynamic) as integer
    if obj <> invalid and GetInterface(obj, "ifInt") <> invalid then
        return obj
    else
        return 0
    end if
end function

function numtostr(num as dynamic) as string
    st=CreateObject("roString")
    if GetInterface(num, "ifInt") <> invalid then
        st.SetString(Stri(num))
    else if GetInterface(num, "ifFloat") <> invalid then
        st.SetString(Str(num))
    end if
    return st.Trim()
end function

function validstr(obj as dynamic) as string
    if isnonemptystr(obj) return obj
    return ""
end function

function isnonemptystr(obj as dynamic) as boolean
    if obj = invalid return false
    if not isstr(obj) return false
    if Len(obj) = 0 return false
    return true
end function

function firstOf(first as dynamic, second as dynamic, third=invalid as dynamic, fourth=invalid as dynamic) as dynamic
    if first <> invalid then return first
    if second <> invalid then return second
    if third <> invalid then return third
    return fourth
end function

function firstOfArr(arr as object)
    if arr = invalid or arr.count() = 0 then return invalid
    for each value in arr
        if value <> invalid then return value
    end for
    return invalid
end function

function Now(local=false as boolean) as object
    if local then
        key = "now_local"
    else
        key = "now_gmt"
    end if

    obj = m[key]

    if obj = invalid then
        obj = CreateObject("roDateTime")
        if local then obj.ToLocalTime()
        m[key] = obj
    end if

    obj.Mark()

    return obj
end function

function UrlUnescape(url as string) as string
    ue = m.UrlEncoder
    if ue = invalid then
        ue = CreateObject("roUrlTransfer")
        m.UrlEncoder = ue
    end if

    return ue.unescape(url)
end function

function UrlEscape(s as string) as string
    ue = m.UrlEncoder
    if ue = invalid then
        ue = CreateObject("roUrlTransfer")
        m.UrlEncoder = ue
    end if

    return ue.Escape(s)
end function

function GetExtension(filename as string) as string
    vals = filename.tokenize(".")
    if vals.Count() > 0 then
        return vals.GetTail()
    else
        return ""
    end if
end function

' This isn't a "real" UUID, but it should at least be random and look like one.
function CreateUUID() as string
    uuid = ""
    for each numChars in [8, 4, 4, 4, 12]
        if Len(uuid) > 0 then uuid = uuid + "-"
        for i=1 to numChars
            o = Rnd(16)
            if o <= 10
                o = o + 47
            else
                o = o + 96 - 10
            end if
            uuid = uuid + Chr(o)
        end for
    next
    return uuid
end function

function CheckMinimumVersion(versionArr as object, requiredVersion as object) as boolean
    index = 0
    for each num in versionArr
        if index >= requiredVersion.count() then exit for
        if num < requiredVersion[index] then
            return false
        else if num > requiredVersion[index] then
            return true
        end if
        index = index + 1
    next
    return true
end function

function ParseVersion(version as string) as object
    Debug("Parsing version string: " + version)
    versionArr = CreateObject("roList")

    dash = instr(1, version, "-")
    if dash > 0 then
        version = left(version, dash - 1)
    end if

    if lcase(right(version, 3)) = "dev" then
        version = left(version, len(version) - 3)
    end if

    tokens = version.Tokenize(".")
    for each num in tokens
        versionArr.Push(int(val(num)))
    next

    versionStr = ""
    for each num in versionArr
        if versionStr = "" then
            versionStr = "["
        else
            versionStr = versionStr + ", "
        end if
        versionStr = versionStr + tostr(num)
    next
    versionStr = versionStr + "]"
    Debug("Parsed version as " + versionStr)

    return versionArr
end function

function ApplyFunc(func as function, this as object, args=[] as object) as dynamic
    ' We don't get real inheritance, so overridden methods lose the ability to
    ' call super. This is a bit clumsy, but it works. We obviously don't
    ' have anything like a splat operator either, so we need to handle arity
    ' manually.

    this["tempBoundFunc"] = func

    if args.Count() = 0 then
        result = this.tempBoundFunc()
    else if args.Count() = 1 then
        result = this.tempBoundFunc(args[0])
    else if args.Count() = 2 then
        result = this.tempBoundFunc(args[0], args[1])
    else if args.Count() = 3 then
        result = this.tempBoundFunc(args[0], args[1], args[2])
    else if args.Count() = 4 then
        result = this.tempBoundFunc(args[0], args[1], args[2], args[3])
    else
        Error("ApplyFunc doesn't currently support " + tostr(args.Count()) + " arguments!")
        stop
    end if

    this.Delete("tempBoundFunc")
    return result
end function

function GetFirstIPAddress() as dynamic
    device = CreateObject("roDeviceInfo")
    addrs = device.GetIPAddrs()
    addrs.Reset()
    if addrs.IsNext() then
        return addrs[addrs.Next()]
    else
        return invalid
    end if
end function

function KeyCodeToString(keyCode as integer) as string
    if keyCode = 0 then
        return "back"
    else if keyCode = 2 then
        return "up"
    else if keyCode = 3 then
        return "down"
    else if keyCode = 4 then
        return "left"
    else if keyCode = 5 then
        return "right"
    else if keyCode = 6 then
        return "ok"
    else if keyCode = 7 then
        return "replay"
    else if keyCode = 8 then
        return "rev"
    else if keyCode = 9 then
        return "fwd"
    else if keyCode = 10 then
        return "info"
    else if keyCode = 11 then
        return "play"
    else
        return ""
    end if
end function

function OppositeDirection(direction as string) as string
    if m.OppositeDirections = invalid then
        m.OppositeDirections = {
            right: "left",
            left: "right",
            up: "down",
            down: "up",
            rev: "fwd",
            fwd: "rev"
        }
    end if

    return m.OppositeDirections[direction]
end function

Function GetDurationString(seconds as dynamic, emptyHr=0 as integer, emptyMin=0 as integer, emptySec=0 as integer, includeSeconds = false) as string
   duration = ""
   datetime = CreateObject("roDateTime")

   if (type(seconds) = "roString") then
       totalSeconds% = seconds.toint()
   else if (type(seconds) = "roInteger") or (type(seconds) = "Integer") then
       totalSeconds% = seconds
   else
       return duration
   end if

   datetime.Fromseconds(totalSeconds%)

   hours = datetime.GetHours().toStr()
   minutes = datetime.GetMinutes().toStr()
   seconds = datetime.Getseconds().toStr()

   if hours <> "0" or emptyHr = 1 then
      duration = duration + hours + " hr "
   end if

   if minutes <> "0" or emptyMin = 1 then
      duration = duration + minutes + " min "
   end if

   if (includeseconds = true or duration = "") and (seconds <> "0" or emptySec = 1) then
      duration = duration + seconds + " sec"
   end if

   return duration.trim()
end Function

function convertDateToString(date as string) as string
    '  format-in: 2014-10-01
    ' format-out: "Long-month Day, Year"
    parts = date.Tokenize("-")
    if parts.count() <> 3 or date.len() <> 10 then return ""

    ' TODO(?) localize
    months = ["January","February","March","April","May","June","July","August","September","October","November","December"]

    year = parts[0]
    month = months[parts[1].toInt()-1]
    day = tostr(parts[2].toInt())

    if year <> invalid and month <> invalid and day <> invalid then
        return month + " " + day + ", " + year
    else
        return ""
    end if
end function
