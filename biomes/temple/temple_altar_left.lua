---@diagnostic disable: lowercase-global, missing-global-doc
RegisterSpawnFunction(0xff0a17a0, "spawn_target_altar")
RegisterSpawnFunction(0xff6a17a9, "spawn_offer_altar")
-- we stitch the sprite directly into the temple altar png so this shouldn't even change init.
-- local old_init = init
-- function init(x, y, w, h, ...)
--   old_init(x, y, w, h, ...)
--   -- local scene_x = x + 314
--   -- local scene_y = y + 346
--   -- LoadPixelScene("mods/offerings/biomes/temple/altar_left.png",
--   --   "mods/offerings/biomes/temple/altar_left_visual.png",
--   --   scene_x, scene_y, "", true)
-- end

function spawn_target_altar(x, y)
  EntityLoad("mods/offerings/entities/target_altar.xml", x + 1, y - 6)
end

function spawn_offer_altar(x, y)
  EntityLoad("mods/offerings/entities/offer_altar.xml", x + 1, y - 6)
end