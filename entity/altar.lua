local altar = dofile_once("mods/offerings/lib/altar_util.lua") ---@type offering_altar

local upper_altar = GetUpdatedEntityID()
altar.do_altar_update_tick(upper_altar, true, altar.target_sever)
local offering_altar = altar.get_lower_altar_near(upper_altar)
altar.do_altar_update_tick(offering_altar, false, altar.offer_sever)