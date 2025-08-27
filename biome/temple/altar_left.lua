---@diagnostic disable: lowercase-global, missing-global-doc
RegisterSpawnFunction(0xff0a17a0, "offering_spawn_altar_left_target_altar")
RegisterSpawnFunction(0xff6a17a9, "offering_spawn_altar_left_offer_altar")

function offering_spawn_altar_left_target_altar(x, y)
  EntityLoad("mods/offerings/entity/target_altar.xml", x + 1, y - 6)
end

function offering_spawn_altar_left_offer_altar(x, y)
  EntityLoad("mods/offerings/entity/offer_altar.xml", x + 1, y - 6)
end