---@diagnostic disable: lowercase-global, missing-global-doc
RegisterSpawnFunction(0xff0a17a0, "spawn_target_altar")
RegisterSpawnFunction(0xff6a17a9, "spawn_offer_altar")
local old_init = init
function init(x, y, w, h, ...)
  old_init(x, y, w, h, ...)
  local scene_x = x + 195
  local scene_y = y + 378
  LoadPixelScene("mods/offerings/biome/mountain/hall.png",
    "mods/offerings/biome/mountain/hall_visual.png",
    scene_x, scene_y, "", true)
end

function spawn_target_altar(x, y)
  EntityLoad("mods/offerings/entity/target_altar.xml", x, y - 5)
end

function spawn_offer_altar(x, y)
  EntityLoad("mods/offerings/entity/offer_altar.xml", x, y - 5)
end