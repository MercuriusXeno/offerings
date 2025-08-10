dofile_once("mods/offerings/lib/logging.lua")

function dOut(h, s)
    h.count = h.count + 1
    local r = s or ""
    debugOut(h.count .. " " .. r)
end

local helper = { count = 0 }
local function hdOut(s) dOut(helper, s) end
helper.step = hdOut

return helper