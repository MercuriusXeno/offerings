local altar = dofile_once("mods/offerings/lib/altar_util.lua") ---@type offering_altar

local thisAltar = GetUpdatedEntityID()
altar.do_altar_update_tick(thisAltar, true, altar.target_link_function, altar.target_sever)
local offeringAltarOfThisAltar = altar.get_lower_altar_near(thisAltar)
altar.do_altar_update_tick(offeringAltarOfThisAltar, false, altar.offer_link_function, altar.offer_sever)