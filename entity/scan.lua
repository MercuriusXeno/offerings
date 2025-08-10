dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar.lua")

-- component shorthand
local LC = "LuaComponent"

function entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

function isOfferMatched(target, offer) return isWandMatch(target, offer) or isFlaskMatch(target, offer) end

function isWandMatch(target, offer) return isWand(target) and isWandEnhancer(offer) end

function isFlaskMatch(target, offer) return isFlask(target) and isFlaskEnhancer(offer) end

function isValidTarget(eid) return not isAltar(eid) and not isInventory(eid) and (isWand(eid) or isFlask(eid)) end

function isValidOffer(target, eid) return not isAltar(eid) and not isInventory(eid) and isOfferMatched(target, eid) end

function isItemLinkAllowed(target, eid) return isValidTarget(eid) or isValidOffer(target, eid) end

local function scanForItems()
    local altar = GetUpdatedEntityID()
    local isUpper = isUpperAltar(altar)
    local radius = isUpper and 13 or 38
    local x, y = EntityGetTransform(altar)
    local entities = EntityGetInRadius(x, y, radius)
    local upperAltar = isUpper(altar) and altar or getUpperAltar(altar)
    local target = target(upperAltar)
    local isNewTarget = isUpper and not target
    local hasTarget = not isNewTarget
    local existingLinkedItems = linkedItems(altar)
    local hasUpdates = false
    for _, eid in ipairs(entities) do
        if isNewTarget or (hasTarget and isItemLinkAllowed(target, eid)) then            
            if isLinked(altar, eid) then
                for k, existingLink in pairs(existingLinkedItems) do
                    if existingLink == eid then existingLinkedItems[k] = nil end
                end
            end
            local ex, ey = EntityGetTransform(eid)
            if entityIn(ex, ey, x, y, radius, 5) then
                local isValidOffer = not isUpper and not isNewTarget and isOfferMatched(target, eid)
                local isLinkingItem = isNewTarget or isValidOffer

                if isNewTarget then
                    if isWand(eid) then storeWandStats(altar, eid) end
                    if isFlask(eid) then storeFlaskStats(altar, eid) end
                end

                if isLinkingItem then
                    handleAltarLink(altar, isUpper, eid, true, x, y, ex, ey)
                    hasUpdates = true
                end
            end
        end
    end

    -- existingLinkedItems we didn't find during scan are missing, unlink them.
    for _, eid in ipairs(existingLinkedItems) do
        sever(altar, eid)
        hasUpdates = true
    end

    if hasUpdates then updateResult(altar) end
end

scanForItems()
