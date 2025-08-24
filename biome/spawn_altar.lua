RegisterSpawnFunction(0xff0a17a0, "SpawnOfferingAltar")

function SpawnOfferingAltar(x, y)
  EntityLoad("mods/offerings/entity/altar.xml", x, y - 5)
end