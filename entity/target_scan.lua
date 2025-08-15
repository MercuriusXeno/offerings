dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar_shared.lua")
dofile_once("mods/offerings/lib/flasks.lua")
dofile_once("mods/offerings/lib/wandStats.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

function isValidTarget(eid) return isWand(eid) or isFlask(eid) end

---Handles the logic of determining an object is a valid altar target
---for the upper altar and linking it if possible.
---@param upperAltar integer The altar to target items with
---@param eid integer an item or entity id in the altar's collision field
---@return boolean isNewLinkFormed whether the altar found a new link
function targetLinkFunc(upperAltar, eid)
    local target = targetOfAltar(upperAltar)
    if target ~= nil then return false end
    if not isValidTarget(eid) then return false end
    local holder = handleAltarLink(upperAltar, true, eid, true)
    local combined = {}
    if isWand(eid) then
        --thonk.about("holder", holder, "holder wand", eid)
        storeWandStats(eid, holder)
        combined = mergeWandStats(upperAltar, lowerAltarNear(upperAltar))
        setWandResult(eid, combined)
        return true
    elseif isFlask(eid) then
        --thonk.about("holder", holder, "holder flask", eid)
        storeFlaskStats(upperAltar, eid, holder)
        combined = mergeFlaskStats(upperAltar, lowerAltarNear(upperAltar))
        setFlaskResult(eid, combined)
        return true
    end
    return false
end

---Before-sever-function for targets, restores them to their vanilla state.
---@param altar integer The target altar restoring the item
---@param eid integer The item id being restored
function restoreTargetOriginalStats(altar, eid)
    --thonk.about("restoring item ", eid)
    local combined = {}
    if isWand(eid) then
        combined = mergeWandStats(altar, 0)
        setWandResult(eid, combined)
    elseif isFlask(eid) then
        combined = mergeFlaskStats(altar, 0)
        setFlaskResult(eid, combined)
    end
end

local altar = GetUpdatedEntityID()
scanForLinkableItems(altar, true, targetLinkFunc, restoreTargetOriginalStats)
