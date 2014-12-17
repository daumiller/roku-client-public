function StarsClass() as object
    if m.StarsClass = invalid then
        obj = CreateObject("roAssociativeArray")
        obj.Append(LabelClass())
        obj.ClassName = "Stars"

        obj.Init = starsInit

        m.StarsClass = obj
    end if

    return m.StarsClass
end function

function createStars(rating as integer, fontSize as integer) as object
    obj = CreateObject("roAssociativeArray")
    obj.Append(StarsClass())

    obj.rating = rating
    obj.fontSize = fontSize

    obj.Init()

    return obj
end function

sub starsInit()
    full = int(m.rating/2)
    half = m.rating mod 2
    empty = 5 - (full + half)
    stars = string(full, Glyphs().STAR_FULL) + string(half, Glyphs().STAR_HALF) + string(empty, Glyphs().STAR_EMPTY)

    ApplyFunc(LabelClass().Init, m, [stars, FontRegistry().GetIconFont(m.fontSize)])
end sub
