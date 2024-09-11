-- From https://stackoverflow.com/a/22831842
function string.starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

-- From https://stackoverflow.com/a/2421746
function string.upperFirst(str)
    return string.gsub(str, "^%l", string.upper)
end

function table.shallow_copy(t)
    local t2 = {}
    for k, v in pairs(t) do
        t2[k] = v
    end
    return t2
end
