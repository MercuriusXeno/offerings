local mod_id = "offerings"

local function get_setting(id, default)
  local v = ModSettingGet(mod_id .. "." .. id)
  if v == nil then return default end
  return v
end

if get_setting("altar_in_holy_mountains", true) then
  ModLuaFileAppend("data/scripts/biomes/temple_altar_left.lua",
                   "mods/offerings/biome/temple/altar_left.lua")
end

if get_setting("altar_near_spawn", true) then
  ModLuaFileAppend("data/scripts/biomes/mountain/mountain_hall.lua",
                   "mods/offerings/biome/mountain/hall.lua")
end

-- this one is for debugging and very cheesy.
--ModLuaFileAppend("data/scripts/biomes/mountain/mountain_left_entrance.lua", "mods/offerings/biome/mountain/left.lua")