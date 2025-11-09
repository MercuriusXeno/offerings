dofile_once("data/scripts/lib/utilities.lua")
local logger = {} ---@class log_util
logger.debug_prefix = "-== OFFERINGS_DEBUG ==-   "
function logger.isDebug() return true end

function logger.log(s)
    if not logger.isDebug() then return end

    if s == "" then return end
    print(logger.debug_prefix .. s)
end

---Given a result string[] r and an ordered pair list
---of varargs inject strings in the array to do a recursive debug out
---@param r string[]
---@param ... any
local function recursiveAbout(r, d, ...)
    local i = 1
    local n = select("#", ...)
    while i < n do
        local pad = d > 0 and string.rep("  ", d) or ""
        local p = select(i, ...)
        local a = select(i + 1, ...)
        if type(a) == "table" then
            r[#r+1] = pad..p
            local varargs = {}
            for k, v in pairs(a) do
                varargs[#varargs+1] = k
                varargs[#varargs+1] = v
            end
            recursiveAbout(r, d + 1, unpack(varargs))
        else
            local s = type(a) == "string" and a or tostring(a)
            r[#r+1] = pad .. p .. " " .. s
        end
        i = i + 2
    end
end

---Given an ordered pair list of varargs,
---print the 1 (name) 2 (value) pair in sequence
---If the type is a table, recurse into the pairs
---@param ... any
function logger.log(...)
    local r = { }
    recursiveAbout(r, 0, ...)
    for _, s in ipairs(r) do logger.log(s) end
end

logger.stepNumber = 0
function logger.step(s)
    logger.stepNumber = logger.stepNumber + 1
    logger.log(logger.stepNumber .. " " .. s)
end

return logger