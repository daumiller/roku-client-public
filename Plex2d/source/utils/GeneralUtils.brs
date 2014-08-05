' Mostly standard helpers borrowed from SDK examples
' TODO(schuyler): Clean up some of these functions

function tostr(any)
    ret = AnyToString(any)
    if ret = invalid ret = type(any)
    if ret = invalid ret = "unknown" 'failsafe
    return ret
end function

function AnyToString(any)
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

function isstr(obj)
    if obj = invalid return false
    if GetInterface(obj, "ifString") = invalid return false
    return true
end function

function isint(obj)
    if obj = invalid return false
    if GetInterface(obj, "ifInt") = invalid return false
    return true
end function

function validint(obj)
    if obj <> invalid and GetInterface(obj, "ifInt") <> invalid then
        return obj
    else
        return 0
    end if
end function

function numtostr(num)
    st=CreateObject("roString")
    if GetInterface(num, "ifInt") <> invalid then
        st.SetString(Stri(num))
    else if GetInterface(num, "ifFloat") <> invalid then
        st.SetString(Str(num))
    end if
    return st.Trim()
end function

function validstr(obj)
    if isnonemptystr(obj) return obj
    return ""
end function

function isnonemptystr(obj)
    if obj = invalid return false
    if not isstr(obj) return false
    if Len(obj) = 0 return false
    return true
end function

function firstOf(first, second, third=invalid, fourth=invalid)
    if first <> invalid then return first
    if second <> invalid then return second
    if third <> invalid then return third
    return fourth
end function

function Now(local=false)
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

function UrlUnescape(url)
    ue = m.UrlEncoder
    if ue = invalid then
        ue = CreateObject("roUrlTransfer")
        m.UrlEncoder = ue
    end if

    return ue.unescape(url)
end function

function UrlEscape(s)
    ue = m.UrlEncoder
    if ue = invalid then
        ue = CreateObject("roUrlTransfer")
        m.UrlEncoder = ue
    end if

    return ue.Escape(s)
end function

function GetExtension(filename)
    vals = filename.tokenize(".")
    if vals.Count() > 0 then
        return vals.GetTail()
    else
        return ""
    end if
end function

' This isn't a "real" UUID, but it should at least be random and look like one.
function CreateUUID()
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

function CheckMinimumVersion(versionArr, requiredVersion)
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
