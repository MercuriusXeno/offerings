local emit_cooldown_key = "wand_workshop.emit_cooldown"
local is_debug_mode_key = "wand_workshop.is_debug_mode"
local is_debug_emit_allowed_key = "wand_workshop.is_debug_emit_allowed"

-- mod-global settings happen before world initialization
ModSettingSet(emit_cooldown_key, "60")
ModSettingSet(is_debug_mode_key, "true") -- this enables logging globally
ModSettingSet(is_debug_emit_allowed_key, "false") -- this enables logging globally    