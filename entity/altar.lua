dofile_once("mods/offerings/lib/altarLogic.lua")

-- STUFF WE DO EVERY EXECUTION
local thisAltar = GetUpdatedEntityID()
scanForLinkableItems(thisAltar, true, targetLinkFunc, restoreTargetOriginalStats)
local offeringAltarOfThisAltar = lowerAltarNear(thisAltar)
scanForLinkableItems(offeringAltarOfThisAltar, false, offerLinkFunc, offerSeverNoop)
-- ... THAT'S ALL lol