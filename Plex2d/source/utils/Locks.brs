' Generic Locks. These are only virtual. You will need to check for the lock to
' ignore processing depending on the lockName.
'  * Locks().Lock("lockName")      : creates virtual lock
'  * Locks().IsLocked("lockName")  : returns true if locked
'  * Locks().Unlock("lockName")    : return true if existed & removed
function Locks() as object
    if m.Locks = invalid then
        obj = CreateObject("roAssociativeArray")

        obj.locks = CreateObject("roAssociativeArray")

        obj.Lock = locksLock
        obj.Unlock = locksUnlock
        obj.IsLocked = locksIsLocked

        m.Locks = obj
    end if

    return m.Locks
end function

sub locksLock(name as string)
    Debug("Lock " + name)
    m.locks[name] = true
end sub

function locksUnlock(name as string) as boolean
    Debug("Unlock " + name)
    return m.locks.Delete(name)
end function

function locksIsLocked(name as string) as boolean
    return m.locks.DoesExist(name)
end function

' lock helpers
sub DisableBackButton()
    Locks().Lock("BackButton")
end sub

sub EnableBackButton()
    Locks().Unlock("BackButton")
end sub
