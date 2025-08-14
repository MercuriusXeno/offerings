dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar_shared.lua")
dofile_once("mods/offerings/lib/flasks.lua")

function isValidTarget(eid) return isWand(eid) or isFlask(eid) end

---Handles the logic of determining an object is a valid altar target
---for the upper altar and linking it if possible.
---@param upperAltar integer The altar to target items with
---@param eid integer an item or entity id in the altar's collision field
function targetLinkFunc(upperAltar, eid)
    local target = target(upperAltar)
    if target ~= nil then return end
    debugOut("target on upper altar is nil")
    if not isValidTarget(eid) then return end
    handleAltarLink(upperAltar, true, eid, true)
    local combined = {}
    if isWand(eid) then
        storeWandStats(upperAltar, eid)
        combined = mergeWandStats(upperAltar, lowerAltarNear(upperAltar))
        setWandResult(eid, combined)
    elseif isFlask(eid) then
        storeFlaskStats(upperAltar, eid)
        combined = mergeFlaskStats(upperAltar, lowerAltarNear(upperAltar))
        setFlaskResult(eid, combined)
    end
end

function restoreTargetOriginalStats(altar, eid)
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
