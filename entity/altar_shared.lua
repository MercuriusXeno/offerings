dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/lib/flasks.lua")

function entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

function isLinkableItem(eid)
    return not isAltar(eid) and (isWandEnhancer(eid) or isFlaskEnhancer(eid))
        and not isInventory(eid) and EntityGetParent(eid) == 0
end

function isLinkableInRange(eid, x, y, radius)
    if not isLinkableItem(eid) then return false end
    local ex, ey = EntityGetTransform(eid)
    local h = ((ex - x) ^ 2 + (ey - y) ^ 2) ^ 0.5
    return h <= radius
end

function linkablesInRange(x, y, radius)
    local map = {}
    local entities = EntityGetInRadius(x, y, radius)
    for i = 1, #entities do
        if isLinkableInRange(entities[i], x, y, radius) then
            map[entities[i]] = entities[i]
        end
    end
    return map
end

function linkableItemsNear(altar, isUpper)
    -- different radius b/c wider lower altar
    local radius = isUpper and 13 or 38
    local x, y = EntityGetTransform(altar)
    -- get linkables based on which altar we are
    return linkablesInRange(x, y, radius)
end

function cullSeveredLinks(altar, linkables, beforeSeverFunc)
    local existingLinks = linkedItems(altar)
    for i = 1, #existingLinks do
        local existing = existingLinks[i]
        if linkables[existing] ~= linkables[existing] then
            beforeSeverFunc(altar, existing)
            sever(altar, existing)
        end
    end
end

function scanForLinkableItems(altar, isUpper, linkFunc, beforeSeverFunc)
    -- ignore altars that are far from the player.
    local x, y = EntityGetTransform(altar)
    local players = EntityGetInRadiusWithTag(x, y, 500, "player_unit")
    if #players == 0 then return end
    -- search for linkables
    local linkables = linkableItemsNear(altar, isUpper)
    debugOut("altar " .. altar .. " scanning for linkables, found " .. #linkables)
    cullSeveredLinks(altar, linkables, beforeSeverFunc)
    for i = 1, #linkables do
        local eid = linkables[i]
        linkFunc(altar, eid)
    end
end

function destroyAltarItemsUsedInTarget(target, altar)
    local function destroyPredicate(offer)
        if isWand(target) then return isWandEnhancer(offer) end
        if isFlask(target) then return isFlaskEnhancer(offer) end
        return false
    end
    local function destroyFunction(offer)
        if isFlask(offer) then RemoveMaterialInventoryMaterial(offer) end
        local x, y = EntityGetTransform(offer)
        EntityLoad("data/entities/particles/destruction.xml", x, y)
        GamePlaySound("data/audio/Desktop/projectiles.bank", "magic/common_destroy", x, y)
        EntityKill(offer)
    end
    eachEntityWhere(linkedItems(altar), destroyPredicate, destroyFunction)
end

function appendDescription(result, description_line)
    if result then
        result = result .. "\n" .. description_line
    else
        result = description_line
    end
    return result
end

function setDescription(eid, description)
    if description == "" then return end
    local comp = firstComponent(eid, "ItemComponent")
    cSet(comp, "ui_description", description)
end
