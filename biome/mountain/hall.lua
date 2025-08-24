---@diagnostic disable: lowercase-global, missing-global-doc
dofile_once("mods/offerings/biome/spawn_altar.lua")
local old_init = init
function init(x, y, w, h, ...)
  old_init(x, y, w, h, ...)
  local scene_x = x + 195
  local scene_y = y + 378
  LoadPixelScene("mods/offerings/biome/mountain/hall.png",
    "mods/offerings/biome/mountain/hall_visual.png",
    scene_x, scene_y, "", true)
end