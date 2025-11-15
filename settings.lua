dofile("data/scripts/lib/mod_settings.lua") -- see this file for documentation on some of the features.

local mod_id = "offerings" -- This should match the name of your mod's folder.
mod_settings_version = 1   -- This is a magic global that can be used to migrate settings to new mod versions. call mod_settings_get_version() before mod_settings_update() to get the old value.
mod_settings =
{
	{
		id = "altar_near_spawn",
		ui_name = "Altar Near Spawn",
		ui_description = "Spawn offerings altar in the tutorial cave to the right of spawn.",
		scope = MOD_SETTING_SCOPE_NEW_GAME,
		value_default = true,
	},
	{
		id = "altar_in_holy_mountains",
		ui_name = "Altar Every Holy Mountain",
		ui_description = "Spawn offerings altar holy mountains. Without this you won't get Holy Mountain altars.",
		scope = MOD_SETTING_SCOPE_NEW_GAME,
		value_default = true,
	},
	{
		id = "transmute_wands_when_merged",
		ui_name = "Wands Change Forms",
		ui_description = "When merging wands, change the form of the wand to the nearest similar wand.",
		scope = MOD_SETTING_SCOPE_NEW_GAME,
		value_default = true,
	},
}

function ModSettingsUpdate(init_scope)
	mod_settings_update(mod_id, mod_settings, init_scope)
end

function ModSettingsGuiCount()
	return mod_settings_gui_count(mod_id, mod_settings)
end

function ModSettingsGui(gui, in_main_menu)
	mod_settings_gui(mod_id, mod_settings, gui, in_main_menu)
end
