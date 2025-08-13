dofile_once("mods/offerings/lib/logging.lua")

function dOut(h, s)
    h.count = h.count + 1
    local r = s or ""
    debugOut(h.count .. " " .. r)
end

function bOut(...)
    local r = ""
    rOut(r, ...)
end

function rOut(r, ...)
    local i = 1
    local n = select("#", ...)
    while i < n do
        local p = select(i, ...)
        local a = select(i + 1, ...)
        if type(a) == "table" then
            local varargs = {}
            for k, v in pairs(a) do
                varargs[#varargs+1] = k
                varargs[#varargs+1] = v
            end
            rOut(r, unpack(varargs))
        else
            local s = type(a) == "string" and a or tostring(a)
            r = r .. p .. " " .. s .. "\n"
        end
        i = i + 2
    end
    debugOut(r)
end

local helper = { count = 0, about = bOut }
local function hdOut(s) dOut(helper, s) end
helper.step = hdOut

return helper
