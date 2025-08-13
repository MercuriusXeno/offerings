dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/entity/altar.lua")

function entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

function isOfferMatched(target, offer) return isWandMatch(target, offer) or isFlaskMatch(target, offer) end

function isWandMatch(target, offer) return isWand(target) and isWandEnhancer(offer) end

function isFlaskMatch(target, offer) return isFlask(target) and isFlaskEnhancer(offer) end

function isLinkableItem(eid)
    return not isAltar(eid) and (isWandEnhancer(eid) or isFlaskEnhancer(eid))
        and not isInventory(eid) and EntityGetParent(eid) == 0
end

function isValidTarget(eid) return isLinkableItem(eid) and (isWand(eid) or isFlask(eid)) end

function isValidOffer(target, eid) return isLinkableItem(eid) and isOfferMatched(target, eid) end

local function scanForItems()
    local thonk = dofile("mods/offerings/lib/thonk.lua")
    local altar = GetUpdatedEntityID()
    local upperAltar = getUpperAltar(altar)
    local target = target(upperAltar)
    local isUpper = altar == upperAltar
    local radius = isUpper and 13 or 38
    local x, y = EntityGetTransform(altar)
    local entities = EntityGetInRadius(x, y, radius)
    local isNewTarget = isUpper and target == nil
    local hasUpdates = false
    local lostTarget = false
    local existingLinks = linkedItems(altar)
    local seen = {}
    for _, l in ipairs(existingLinks) do seen[l] = false end
    for _, eid in ipairs(entities) do
        local isLinkableItem = isLinkableItem(eid)
        if isLinkableItem then
            if seen[eid] == false then seen[eid] = true end
            local wasLinked = isLinked(altar, eid)
            local isNowLinked = wasLinked
            local ex, ey = EntityGetTransform(eid)
            local h = ((ex - x) ^ 2 + (ey - y) ^ 2) ^ 0.5
            if wasLinked then
                if h > radius or (not isUpper and not target) or not isLinkableItem then
                    debugOut("distance of item " .. h .. " or some other factor caused breakage")
                    isNowLinked = false
                end
            else
                local isValidUpper = isNewTarget and isValidTarget(eid)
                local isValidLower = not isUpper and target ~= nil and isValidOffer(target, eid)
                isNowLinked = isLinkableItem and (isValidUpper or isValidLower) and entityIn(ex, ey, x, y, radius, 5)
            end
            if isNowLinked ~= wasLinked then
                debugOut("handle altar link ("  .. tostring(isNowLinked) .. ") firing for altar " ..
                altar .. " is upper? " .. tostring(isUpper) .. " for item " .. eid)
                handleAltarLink(altar, isUpper, eid, isNowLinked, x, y, ex, ey)
                if isNewTarget then
                    if isWand(eid) then memorizeWand(altar, eid) end
                    if isFlask(eid) then storeFlaskStats(altar, eid) end
                end
                hasUpdates = true
                lostTarget = wasLinked and isUpper
            end
        end
    end
    for eid, isSeen in pairs(seen) do
        if not isSeen then
            handleAltarLink(altar, isUpper, eid, false, x, y, 0, 0)
            lostTarget = lostTarget or isUpper
            debugOut("game thinks the item " .. eid .. " is missing and thus updating")
            hasUpdates = true
        end
    end
    if lostTarget then
        clearOriginalStats(altar)
        hasUpdates = true
    end
    -- losing the target means it fetched loose from
    -- the altar and we need to restore its original stats
    if hasUpdates then
        debugOut("game thinks the item has updates on altar " .. altar .. " and target lost is " .. tostring(lostTarget))
        updateResult(altar, lostTarget)
    end
end

scanForItems()
