---@diagnostic disable: lowercase-global, missing-global-doc
dofile_once("mods/offerings/biome/spawn_altar.lua")
local old_init = init
function init(x, y, w, h, ...)
  old_init(x, y, w, h, ...)
  local scene_x = x + 206
  local scene_y = y + 388
  LoadPixelScene("mods/offerings/biome/mountain/left.png",
    "mods/offerings/biome/mountain/left_visual.png",
    scene_x, scene_y, "", true)
end