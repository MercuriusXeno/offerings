dofile_once("mods/offerings/lib/altarLogic.lua")

-- STUFF WE DO EVERY EXECUTION
local thisAltar = GetUpdatedEntityID()
scanForLinkableItems(thisAltar, true, targetLinkFunc, targetSever)
local offeringAltarOfThisAltar = lowerAltarNear(thisAltar)
scanForLinkableItems(offeringAltarOfThisAltar, false, offerLinkFunc, offerSever)
-- ... THAT'S ALL lol