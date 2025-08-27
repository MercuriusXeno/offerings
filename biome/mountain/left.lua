---@diagnostic disable: lowercase-global, missing-global-doc
RegisterSpawnFunction(0xff0a17a0, "offering_spawn_mountain_left_target_altar")
RegisterSpawnFunction(0xff6a17a9, "offering_spawn_mountain_left_offer_altar")
local old_init = init
function init(x, y, w, h, ...)
  old_init(x, y, w, h, ...)
  local scene_x = x + 206
  local scene_y = y + 388
  LoadPixelScene("mods/offerings/biome/mountain/left.png",
    "mods/offerings/biome/mountain/left_visual.png",
    scene_x, scene_y, "", true)
end

function offering_spawn_mountain_left_target_altar(x, y)
  EntityLoad("mods/offerings/entity/target_altar.xml", x, y - 5)
end

function offering_spawn_mountain_left_offer_altar(x, y)
  EntityLoad("mods/offerings/entity/offer_altar.xml", x, y - 5)
end