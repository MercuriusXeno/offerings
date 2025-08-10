--- Items and Entities Utils
dofile_once("mods/offerings/lib/components.lua")

local upperAltarTag = "offeringsUpperAltar"
local lowerAltarTag = "offeringsLowerAltar"
local altarLink = "linkedAltar"
local itemLink = "linkedItem"
local MIC = "MaterialInventoryComponent"
local IC = "ItemComponent"
local LC = "LuaComponent"
local SPC = "SimplePhysicsComponent"
local SPEC = "SpriteParticleEmitterComponent"
local PEC = "ParticleEmitterComponent"

local wand_pickup_script = "data/scripts/particles/wand_pickup.lua"

function isFlask(eid) return EntityHasTag(eid, "potion") or itemNamed(eid, "$item_cocktail") end

function isFlaskEnhancer(eid) return isFlask(eid) or hasAnyEnchantValue(eid) end

function isWand(eid) return EntityHasTag(eid, "wand") end

function isWandEnhancer(eid) return isWand(eid) end

function itemNameContains(eid, s) return hasCompLike(eid, "ItemComponent", nil, "item_name", s) end

function itemNamed(eid, name) return hasCompMatch(eid, "ItemComponent", nil, "item_name", name) end

function disableSimplePhysics(eid) disableAllComps(eid, "SimplePhysicsComponent") end

function linkedItems(altar) return storedIntsArray(altar, itemLink) end

function linkedAltar(eid) return storedInt(eid, altarLink, true) end

function linkedItemsWhere(altar, pred)
    local arr = {}
    for _, c in linkedItems(altar) do if pred(altar, c) then arr[#arr+1] = c end end
    return arr
end

function entityName(eid) return EntityGetName(eid) end

function isEntityNamed(eid, s) return entityName(eid) == s end

function isInventory(eid) return isEntityNamed(EntityGetParent(eid), "inventory_quick") end

function closest(tag, x, y) return EntityGetClosestWithTag(x, y, tag) end

function closestToEntity(eid, tag) return closest(tag, EntityGetTransform(eid)) end

function isUpperAltar(eid) return EntityHasTag(eid, upperAltarTag) end

function isLowerAltar(eid) return EntityHasTag(eid, lowerAltarTag) end

function isAltar(eid) return isUpperAltar(eid) or isLowerAltar(eid) end

function getUpperAltar(eid) return closestToEntity(eid, upperAltarTag) end

function getLowerAltar(eid) return closestToEntity(eid, lowerAltarTag) end

function wands(altar) return linkedItemsWhere(altar, isWand) end

function flasks(altar) return linkedItemsWhere(altar, isFlask) end

function flaskEnhancers(altar) return linkedItemsWhere(altar, isFlaskEnhancer) end

function target(altar) return #linkedItems(altar) > 0 and linkedItems(altar)[1] or nil end

function isLinked(altar, item)
    local isAltarItem = false
    for _, i in ipairs(linkedItems(altar)) do
        isAltarItem = isAltarItem or i == item
        if isAltarItem then break end
    end
    return isAltarItem and storedInt(item, altarLink, true) == altar
end

function link(altar, item)
    storeInt(altar, itemLink, item)
    storeInt(item, altarLink, altar)
end

function sever(altar, item)
    dropStoredMatch(altar, itemLink, item)
    dropStoredMatch(item, altarLink, altar)
end

function linkOrSever(altar, item, isLinking)
    if isLinking then
        link(altar, item)
    else
        sever(altar, item)
    end
end

function eachEntityWhere(eids, pred, func)
    for _, eid in ipairs(eids) do if pred(eid) then func(eid) end end
end

---Handle linking and unlinking items from an altar, setting and reversing various things.
function handleAltarLink(altar, isUpper, eid, isLinked, x, y, ex, ey)
    -- aesthetic stuff when linking the item to the altar, rotation mainly.
    if isLinked then
        local dx = isUpper and x or ex
        local dy = y - 5 -- floaty
        local upgright_rotation = isWand(eid) and -math.pi * 0.5 or 0.0
        EntitySetTransform(eid, ex, ey, upgright_rotation)
        eachComponentSet(eid, IC, nil, "spawn_pos", dx, dy)
    end

    -- make "first time pickup" fanfare when picking the item up
    eachComponentSet(eid, IC, nil, "has_been_picked_by_player", not isLinked)

    if isWand(eid) then
        -- immobilize wands
        eachComponentSet(eid, IC, nil, "play_hover_animation", not isLinked)
        eachComponentSet(eid, IC, nil, "play_spinning_animation", not isLinked)
        toggleCompsLike(eid, SPC, nil, not isLinked)
        -- make pickup fancy
        enableFirstCompLike(eid, LC, nil, "script_item_picked_up", wand_pickup_script)
    end

    -- handle adding or removing item from the altar children
    linkOrSever(altar, eid, isLinked)

    -- enable particle emitters on linked items, these are the "new item" particles
    eachComponentSet(eid, SPEC, nil, "velocity_always_away_from_center", isLinked)

    -- enable the altar rune particle emitter if it has any children
    toggleComps(altar, PEC, #linkedItems(altar) > 0)

    -- disable the altar scan algorithm if it's the upper altar and has a child
    if isUpper(altar) and #linkedItems(altar) > 0 then
        disableFirstCompLike(altar, LC, "script_source_file", "mods/offerings/entity/scan.lua")
    end
end
