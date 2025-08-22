local altar = dofile_once("mods/offerings/lib/altarLogic.lua") ---@type offering_altar

-- STUFF WE DO EVERY EXECUTION
local thisAltar = GetUpdatedEntityID()
altar.scanForLinkableItems(thisAltar, true, altar.targetLinkFunc, altar.targetSever)
local offeringAltarOfThisAltar = altar.lowerAltarNear(thisAltar)
altar.scanForLinkableItems(offeringAltarOfThisAltar, false, altar.offerLinkFunc, altar.offerSever)
-- ... THAT'S ALL lol