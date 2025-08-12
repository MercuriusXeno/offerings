dofile_once("mods/offerings/lib/logging.lua")

function dOut(h, s)
    h.count = h.count + 1
    local r = s or ""
    debugOut(h.count .. " " .. r)
end

function bOut(...)
    local i = 1
    local n = select("#", ...)
    local r = ""
    while i < n do
        local p = select(i, ...)
        local v = select(i + 1, ...)
        local s = type(v) == "string" and v or tostring(v)
        r = r .. p .. " " .. s .. "\n"
        i = i + 2
    end
    debugOut(r)
end

local helper = { count = 0, about = bOut }
local function hdOut(s) dOut(helper, s) end
helper.step = hdOut

return helper
