dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar_shared.lua")
dofile_once("mods/offerings/lib/flaskStats.lua")
dofile_once("mods/offerings/lib/wandStats.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

function isValidTarget(eid) return isWand(eid) or isFlask(eid) end

---Handles the logic of determining an object is a valid altar target
---for the upper altar and linking it if possible.
---@param upperAltar integer The altar to target items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@return boolean isNewLinkFormed whether the altar found a new link
function targetLinkFunc(upperAltar, seen)
    if targetOfAltar(upperAltar) ~= nil then return false end
    if not isValidTarget(seen.item) then return false end
    local holder = altarLinkToSeenItem(upperAltar, true, seen)
    thonk.about("holder", holder, "holder wand", seen.item)
    if isWand(seen.item) then
        storeWandStats(seen.item, holder)
        local combinedWands = mergeWandStats(upperAltar, lowerAltarNear(upperAltar))
        setWandResult(seen.item, combinedWands)
    elseif isFlask(seen.item) then
        --thonk.about("holder", holder, "holder flask", eid)
        storeFlaskStats(upperAltar, seen.item, holder)
        local combinedFlasks = mergeFlaskStats(upperAltar, lowerAltarNear(upperAltar))
        setFlaskResult(seen.item, combinedFlasks)
    end
    return true
end

---Before-sever-function for targets, restores them to their vanilla state.
---@param altar integer The target altar restoring the item
---@param eid integer The item id being restored
function restoreTargetOriginalStats(altar, eid)
    thonk.about("restoring item ", eid)
    if isWand(eid) then
        local combinedWands = mergeWandStats(altar, 0)
        setWandResult(eid, combinedWands)
    elseif isFlask(eid) then
        local combinedFlasks = mergeFlaskStats(altar, 0)
        setFlaskResult(eid, combinedFlasks)
    end
end

local altar = GetUpdatedEntityID()
scanForLinkableItems(altar, true, targetLinkFunc, restoreTargetOriginalStats)
