local altar = dofile_once("mods/offerings/lib/altar_util.lua") ---@type offering_altar

local thisAltar = GetUpdatedEntityID()
altar.scanForLinkableItems(thisAltar, true, altar.targetLinkFunc, altar.targetSever)
local offeringAltarOfThisAltar = altar.lowerAltarNear(thisAltar)
altar.scanForLinkableItems(offeringAltarOfThisAltar, false, altar.offerLinkFunc, altar.offerSever)