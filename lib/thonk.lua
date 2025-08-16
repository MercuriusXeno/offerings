dofile_once("mods/offerings/lib/logging.lua")

---@class Thonk
---@field about fun(...) output the pairs of arguments provided, recurses into table trees.
---@field step fun(s: string) output the step index and string provided. cumulative step counter.

function dOut(h, s)
    h.count = h.count + 1
    local r = s or ""
    debugOut(h.count .. " " .. r)
end

---Given an ordered pair list of varargs,
---print the 1 (name) 2 (value) pair in sequence
---If the type is a table, recurse into the pairs
---@param ... any
function bOut(...)
    local r = { }
    rOut(r, ...)
    for _, s in ipairs(r) do debugOut(s) end
end

---Given a result string[] r and an ordered pair list
---of varargs inject strings in the array to do a recursive debug out
---@param r string[]
---@param ... any
function rOut(r, ...)
    local i = 1
    local n = select("#", ...)
    while i < n do
        local p = select(i, ...)
        local a = select(i + 1, ...)
        if type(a) == "table" then
            r[#r+1] = p .. " {"
            local varargs = {}
            for k, v in pairs(a) do
                varargs[#varargs+1] = k
                varargs[#varargs+1] = v
            end
            rOut(r, unpack(varargs))
            r[#r+1] = "}"
        else
            local s = type(a) == "string" and a or tostring(a)
            r[#r+1] = p .. " " .. s .. ""
        end
        i = i + 2
    end
end

local function noop(s) end
---@type Thonk
local helper = { count = 0, about = bOut, step = noop }
local function hdOut(s) dOut(helper, s) end
helper.step = hdOut

return helper