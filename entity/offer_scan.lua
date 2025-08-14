dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar_shared.lua")
dofile_once("mods/offerings/lib/flasks.lua")

function isWandMatch(target, offer) return isWand(target) and isWandEnhancer(offer) end

function isFlaskMatch(target, offer) return isFlask(target) and isFlaskEnhancer(offer) end

function isValidOffer(target, eid) return isWandMatch(target, eid) or isFlaskMatch(target, eid) end

function isValidTarget(eid) return isWand(eid) or isFlask(eid) end

local function offerLinkFunc(lowerAltar, eid)
    local upperAltar = upperAltarNear(lowerAltar)
    local target = target(upperAltar)
    if target == nil then return end
    if not isValidOffer(target, eid) then return end
    handleAltarLink(lowerAltar, false, eid, true)
    if isWand(eid) then
        local combined = {}
        storeWandStats(lowerAltar, eid)
        setWandResult(eid, combined)
    end
    if isFlask(eid) then
        local combined = {}
        storeFlaskStats(lowerAltar, eid)
        setFlaskResult(eid, combined)
    end
end

local function offerSeverNoop(altar, eid)
end

local altar = GetUpdatedEntityID()
scanForLinkableItems(altar, false, offerLinkFunc, offerSeverNoop)
