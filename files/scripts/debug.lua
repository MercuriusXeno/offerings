dofile_once("data/scripts/lib/utilities.lua")

local debug_prefix = "-== WAND_WORKSHOP_DEBUG ==-   "
local emit_last_key = "wand_workshop.emit_last"
local emit_cooldown_key = "wand_workshop.emit_cooldown"
local emit_particle = "data/entities/particles/poof_blue.xml"

function Debug_Cooldown()
    return tonumber(ModSettingGet(emit_cooldown_key))
end

function Is_Debug()
    return ModSettingGet("wand_workshop.is_debug_mode") == "true"
end

function Is_Emit_Debug()
    return ModSettingGet("wand_workshop.is_debug_emit_allowed") == "true"
end

---Returns the last emit frame
---@return number
function Last_Emit()
    return tonumber(GlobalsGetValue(emit_last_key, "-60")) or -Debug_Cooldown()
end

function Mark_Last_Emit()
    GlobalsSetValue(emit_last_key, tostring(GameGetFrameNum()))
end

function Log(s)
    if not Is_Debug() then return end
    local log = debug_prefix .. s
    GamePrint(log)
    print(log)
end

---Emit a particle and display a message, optionally, if the debug modes are active.
---@param x any
---@param y any
---@param optional_message any
function Debug_Particle_Emit(x, y, optional_message)
    if not Is_Debug_Emit_Allowed() then return end

    if not Is_Debug() then return end
    if optional_message ~= nil then Log(optional_message) end


    if not Is_Emit_Debug() then return end
    EntityLoad(emit_particle, x, y)
end

---Standard method for determining a debug emit can proc and resetting the cooldown
---for any given process. There should only be one thing on the debug emit stack
---or they'll fight over it. Once something is confirmed working, pull its emit.
---@return boolean
function Is_Debug_Emit_Allowed()
    local is_cooling_down = GameGetFrameNum() - Last_Emit() <= Debug_Cooldown()

    -- set the cooldown now, if we're emitting
    if not is_cooling_down then Mark_Last_Emit() end
    
    return not is_cooling_down
end
