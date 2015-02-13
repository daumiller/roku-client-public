' Mostly standard helpers borrowed from SDK examples

function tostr(any as dynamic, aaDepth=0 as integer) as string
    ret = AnyToString(any)
    if ret = invalid and any <> invalid and type(any.ToString) = "roFunction" then
        ret = any.ToString()
    end if

    if ret = invalid and type(any) = "roAssociativeArray" and aaDepth > 0 then
        ret = "roAssociativeArray" + Chr(10)
        for each key in any
            ret = ret + key + ": " + tostr(any[key], aaDepth - 1) + Chr(10)
        next
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
    if GetInterface(any, "ifArray") <> invalid then
        return "[" + JoinArray(any, ", ") + "]"
    end if
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

function CheckMinimumVersion(requiredVersion as object, versionArr=invalid as dynamic) as boolean
    if versionArr = invalid then
        versionArr = AppSettings().GetGlobal("rokuVersionArr")
    end if

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
        Fatal("ApplyFunc doesn't currently support " + tostr(args.Count()) + " arguments!")
    end if

    this.Delete("tempBoundFunc")
    return result
end function

function GetFirstIPAddress() as dynamic
    addrs = AppSettings().GetGlobal("roDeviceInfo").GetIPAddrs()
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
    else if keyCode = 13 then
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

function GetDateTimeFromSeconds(seconds as dynamic) as dynamic
    if IsString(seconds) then
        sec = seconds.toint()
    else if IsNumber(seconds) then
        sec = seconds
    else
        return invalid
    end if

    datetime = CreateObject("roDateTime")
    datetime.FromSeconds(sec)

    return datetime
end function

function GetDurationString(seconds as dynamic, emptyHr=false as boolean, emptyMin=false as boolean, emptySec=false as boolean) as string
    datetime = GetDateTimeFromSeconds(seconds)
    if datetime = invalid then return ""

    duration = ""
    hours = datetime.GetHours().toStr()
    minutes = datetime.GetMinutes().toStr()
    seconds = datetime.Getseconds().toStr()

    if hours <> "0" or emptyHr = true then
        duration = duration + hours + " hr "
    end if

    if minutes <> "0" or emptyMin = true then
        duration = duration + minutes + " min "
    end if

    if duration = "" and seconds <> "0" or emptySec = true then
        duration = duration + seconds + " sec"
    end if

    return duration.trim()
end function

' return time string: always include minutes and seconds. Do not inlcude leading zero on first time part
function GetTimeString(seconds as dynamic, emptyHr=false as boolean, emptyMin=true as boolean, emptySec=true as boolean) as string
    datetime = GetDateTimeFromSeconds(seconds)
    if datetime = invalid then return ""

    duration = ""
    parts = CreateObject("roList")
    hours = datetime.GetHours().toStr()
    minutes = datetime.GetMinutes().toStr()
    seconds = datetime.Getseconds().toStr()

    if hours   <> "0" or emptyHr  = true then parts.push(hours)
    if minutes <> "0" or emptyMin = true then parts.push(minutes)
    if seconds <> "0" or emptySec = true then parts.push(seconds)

    for index = 0 to parts.Count() - 1
        if index = 0 then
            duration = parts[index]
        else
            duration = duration + ":" + right("0" + parts[index], 2)
        end if
    end for

    return duration
end function

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

function JoinArray(arr, sep, key1="", key2="") as string
    result = ""
    first = true

    for each value in arr
        if value <> invalid and (type(value) = "roassociativeArray" or tostr(value) <> "") then
            if type(value) = "roassociativeArray" then value = firstOf(value[key1], value[key2])
            if first then
                first = false
            else
                result = result + sep
            end if
            result = result + tostr(value)
        end if
    end for

    return result
end function

function iif(condition as boolean, trueValue as dynamic, falseValue as dynamic) as dynamic
    if condition = true then
        return trueValue
    else
        return falseValue
    end if
end function

Function createDigest(value as string, alg="sha256" as string) as string
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(value)
    digest = CreateObject("roEVPDigest")
    digest.Setup(alg)
    return digest.Process(ba)
end Function

function IntToBa(value as integer, alpha=false as boolean) as object
    ba = CreateObject("roByteArray")
    ba.SetResize(4, false)

    ' TODO(rob): use the bitwise operators when 6.1 firmware is live
    i% = value
    if alpha then ba[3] = i%
    i% = i% / 256 : ba[2] = i%
    i% = i% / 256 : ba[1] = i%
    i% = i% / 256 : ba[0] = i%

    ' 6.1 firmware support
    ' ba[0] = value >> 24
    ' ba[1] = value >> 16
    ' ba[2] = value >> 8
    ' if alpha then ba[3] = value

    return ba
end function

function rdRightShift(num as integer, count = 1 as integer) as integer
    mult    = 2 ^ count
    summand = 1
    total   = 0

    for i = count to 31
        if (num and summand * mult)
            total = total + summand
        end if
        summand = summand * 2
    end for

    return total
end function

function IntToHex(value as integer, alpha=false as boolean) as string
    return IntToBa(value, alpha).toHexString()
end function


function IsXmlElement(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifXMLElement") <> invalid
end function

function IsFunction(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifFunction") <> invalid
end function

function IsBoolean(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifBoolean") <> invalid
end function

function IsInteger(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifInt") <> invalid and (type(value) = "roInt" or type(value) = "roInteger" or type(value) = "Integer")
end function

function IsFloat(value as dynamic) as boolean
    return IsValid(value) and (GetInterface(value, "ifFloat") <> invalid or (type(value) = "roFloat" or type(value) = "Float"))
end function

function IsDouble(value as dynamic) as boolean
    return IsValid(value) and (GetInterface(value, "ifDouble") <> invalid or (type(value) = "roDouble" or type(value) = "roIntrinsicDouble" or type(value) = "Double"))
end function

function IsList(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifList") <> invalid
end function

function IsArray(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifArray") <> invalid
end function

function IsAssociativeArray(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifAssociativeArray") <> invalid
end function

function IsString(value as dynamic) as boolean
    return IsValid(value) and GetInterface(value, "ifString") <> invalid
end function

function IsDateTime(value as dynamic) as boolean
    return IsValid(value) and (GetInterface(value, "ifDateTime") <> invalid or type(value) = "roDateTime")
end function

function IsValid(value as dynamic) as boolean
    return type(value) <> "<uninitialized>" and value <> invalid
end function

function IsNumber(value as dynamic) as boolean
    return IsValid(value) and (IsInteger(value) or IsFloat(value) or IsDouble(value))
end function

sub HDtoSD(rect As Object)
    if AppSettings().GetGlobal("IsHD") then return
    wMultiplier = 720 / 1280
    hMultiplier = 480 / 720

    if rect.x <> invalid then
        rect.x = cint(rect.x * wMultiplier)
        rect.x = iif(rect.x < 1, 0, rect.x)
    end if
    if rect.y <> invalid then
        rect.y = cint(rect.y * hMultiplier)
        rect.y = iif(rect.y < 1, 0, rect.y)
    end if
    if rect.w <> invalid then
        rect.w = cint(rect.w * wMultiplier)
        rect.w = iif(rect.w < 1, 0, rect.w)
    end if
    if rect.h <> invalid then
        rect.h = cint(rect.h * hMultiplier)
        rect.h = iif(rect.h < 1, 0, rect.h)
   end if
end sub

function HDtoSDheight(delta as integer) as integer
    obj = { h: delta }
    HDtoSD(obj)
    return obj.h
end function

function HDtoSDwidth(delta as integer) as integer
    obj = { w: delta }
    HDtoSD(obj)
    return obj.w
end function

function GetFriendlyName() as string
    device = AppSettings().GetGlobal("roDeviceInfo")

    if CheckMinimumVersion([6, 1]) then
        return device.GetFriendlyName()
    else
        obj = CreateObject("roURLTransfer")
        obj.SetURL("http://" + GetFirstIPAddress() + ":8060/dial/dd.xml")
        xml = CreateObject("roXMLElement")
        xml.Parse(obj.GetToString())
        name = xml.device.friendlyName.GetText()
        if name <> "" then return name
    end if

    return device.GetModelDisplayName() + " - " + device.GetDeviceUniqueId()
end function

function CreateRegion(width as integer, height as integer, color as integer, alphaEnable=false as boolean) as object
    bmp = CreateObject("roBitmap", {width: width, height: height, alphaEnable: alphaEnable})
    bmp.Clear(color)
    region = CreateObject("roRegion", bmp, 0, 0, bmp.GetWidth(), bmp.GetHeight())
    return region
end function
