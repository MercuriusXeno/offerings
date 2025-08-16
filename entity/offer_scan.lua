dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar_shared.lua")
dofile_once("mods/offerings/lib/flaskStats.lua")
dofile_once("mods/offerings/lib/wandStats.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

function isWandMatch(target, offer) return isWand(target) and isWandEnhancer(offer) end

function isFlaskMatch(target, offer) return isFlask(target) and isFlaskEnhancer(offer) end

---Test that the target can be improved by the offering
---@param target integer The linked item on the upper altar
---@param eid integer A lower altar potential linked item
---@return boolean result true if the target can consume the offering, otherwise false
function isValidOffer(target, eid) return isWandMatch(target, eid) or isFlaskMatch(target, eid) end

---Handles the logic of determining an object is a valid offering
---for the lower altar and linking it if possible.
---@param lowerAltar integer The altar to sacrifice items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@return boolean isNewLinkFormed whether the altar found a new link
local function offerLinkFunc(lowerAltar, seen)
    local upperAltar = upperAltarNear(lowerAltar)
    local target = targetOfAltar(upperAltar)
    if target == nil then return false end
    --thonk.about("target", target)
    if not isValidOffer(target.item, seen.item) then return false end
    local holder = altarLinkToSeenItem(lowerAltar, false, seen)
    if isWand(seen.item) then
        if holder ~= 0 then storeWandStats(seen.item, holder) end
        combined = mergeWandStats(upperAltar, lowerAltar)
        setWandResult(target.item, combined)
    end
    if isFlask(seen.item) then
        if holder ~= 0 then storeFlaskStats(lowerAltar, seen.item, holder) end
        combined = mergeFlaskStats(upperAltar, lowerAltar)
        setFlaskResult(target.item, combined)
    end
    return true
end

local function offerSeverNoop(lowerAltar, eid)
end

local altar = GetUpdatedEntityID()
scanForLinkableItems(altar, false, offerLinkFunc, offerSeverNoop)
