dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar_shared.lua")
dofile_once("mods/offerings/lib/flasks.lua")
dofile_once("mods/offerings/lib/wandStats.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

function isWandMatch(target, offer) return isWand(target) and isWandEnhancer(offer) end

function isFlaskMatch(target, offer) return isFlask(target) and isFlaskEnhancer(offer) end

function isValidOffer(target, eid) return isWandMatch(target, eid) or isFlaskMatch(target, eid) end

---Handles the logic of determining an object is a valid offering
---for the lower altar and linking it if possible.
---@param lowerAltar integer The altar to sacrifice items with
---@param eid integer an item or entity id in the altar's collision field
---@return boolean isNewLinkFormed whether the altar found a new link
local function offerLinkFunc(lowerAltar, eid)
    local upperAltar = upperAltarNear(lowerAltar)
    local target = targetOfAltar(upperAltar)
    if target == nil then return false end
    thonk.about("target", target)
    if not isValidOffer(target, eid) then return false end
    local holder = handleAltarLink(lowerAltar, false, eid, true)
    if isWand(eid) then
        if holder ~= 0 then storeWandStats(eid, holder) end
        combined = mergeWandStats(upperAltar, lowerAltar)
        setWandResult(targetOfAltar(upperAltar), combined)
        return true
    end
    if isFlask(eid) then
        if holder ~= 0 then storeFlaskStats(lowerAltar, eid, holder) end
        combined = mergeWandStats(upperAltar, lowerAltar)
        setFlaskResult(targetOfAltar(upperAltar), combined)
        return true
    end
    return false
end

local function offerSeverNoop(altar, eid)
end

local altar = GetUpdatedEntityID()
scanForLinkableItems(altar, false, offerLinkFunc, offerSeverNoop)
