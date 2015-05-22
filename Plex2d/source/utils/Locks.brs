' Generic Locks. These are only virtual. You will need to check for the lock to
' ignore processing depending on the lockName.
'  * Locks().Lock("lockName")      : creates virtual lock
'  * Locks().IsLocked("lockName")  : returns true if locked
'  * Locks().Unlock("lockName")    : return true if existed & removed
function Locks() as object
    if m.Locks = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.locks = CreateObject("roAssociativeArray")
        obj.oneTimeLocks = CreateObject("roAssociativeArray")

        obj.Lock = locksLock
        obj.LockOnce = locksLockOnce
        obj.Unlock = locksUnlock
        obj.IsLocked = locksIsLocked

        m.Locks = obj
    end if

    return m.Locks
end function

sub locksLock(name as string)
    m.locks[name] = validint(m.locks[name]) + 1
    Debug("Lock " + name + ", total=" + tostr(m.locks[name]))
end sub

sub locksLockOnce(name as string)
    Debug("Locking once " + name)
    m.oneTimeLocks[name] = true
end sub

function locksUnlock(name as string, forceUnlock=false as boolean) as boolean
    oneTime = m.oneTimeLocks.Delete(name)
    normal = (validint(m.locks[name]) > 0)

    if normal then
        if forceUnlock then
            m.locks[name] = 0
        else
            m.locks[name] = m.locks[name] - 1
        end if

        if m.locks[name] <= 0 then
            m.locks.Delete(name)
        else
            normal = false
        end if
    end if

    unlocked = (normal or oneTime)
    Debug("Unlock " + name + ", total=" + tostr(validint(m.locks[name])) + ", unlocked=" + tostr(unlocked))

    return unlocked
end function

function locksIsLocked(name as string) as boolean
    return (m.oneTimeLocks.Delete(name) or m.locks.DoesExist(name))
end function

' lock helpers
sub DisableBackButton()
    Locks().Lock("BackButton")
end sub

sub EnableBackButton()
    Locks().Unlock("BackButton")
end sub
