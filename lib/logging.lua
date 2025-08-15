dofile_once("data/scripts/lib/utilities.lua")

local debug_prefix = "-== OFFERINGS_DEBUG ==-   "

function isDebug() return ModSettingGet("offerings.is_debug_mode") == "true" end

function debugOut(s)
    if isDebug() then return end

    if string_isempty(s) then return end
    GamePrint(debug_prefix .. s)
    print(debug_prefix .. s)
end
