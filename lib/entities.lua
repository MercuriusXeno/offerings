--- Items and Entities Utils
dofile_once("mods/offerings/lib/components.lua")

local upperAltarTag = "offeringsUpperAltar"
local lowerAltarTag = "offeringsLowerAltar"
local altarLink = "linkedAltar"
local itemLink = "linkedItem"
local VSC = "VariableStorageComponent"
local IC = "ItemComponent"
local LC = "LuaComponent"
local SPC = "SimplePhysicsComponent"
local SPEC = "SpriteParticleEmitterComponent"
local PEC = "ParticleEmitterComponent"

function isWand(eid) return EntityHasTag(eid, "wand") end

function isWandEnhancer(eid) return isWand(eid) end

function itemNameContains(eid, s) return hasCompLike(eid, "ItemComponent", nil, "item_name", s) end

function itemNamed(eid, name) return hasCompMatch(eid, "ItemComponent", nil, "item_name", name) end

function disableSimplePhysics(eid) disableAllComps(eid, "SimplePhysicsComponent") end

function linkedItems(altar)
    local result = {}
    local holderChildren = EntityGetAllChildren(altar) or {}
    for i = 1, #holderChildren do
        local hid = #holderChildren[i]
        local eid = storedInt(hid, "eid", true)
        result[eid] = eid
    end
    return result
end

function target(altar)
    if #linkedItems(altar) > 0 then return linkedItems(altar)[1] end
    return nil
end

function isLinked(altar, item)
    return linkedItems(altar)[item] == item
end

---Create a holder entity sired by the altar, attached to the item
---it represents. This is used to attach components holding its stats.
---@param altar number
---@param item number
---@return number
function link(altar, item)
    -- create a holder for the item and add it to the altar
    local e = EntityLoad("mods/offerings/entity/holder.xml", EntityGetTransform(altar))
    storeInt(e, "eid", item)
    EntityAddChild(altar, e)
    return e
end

function linkedItemsWhere(altar, pred)
    local arr = {}
    local links = linkedItems(altar)
    for i = 1, #links do
        if pred(altar, links[i]) then arr[links[i]] = links[i] end
    end
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

function upperAltarNear(eid) return closestToEntity(eid, upperAltarTag) end

function lowerAltarNear(eid) return closestToEntity(eid, lowerAltarTag) end

function wands(altar) return linkedItemsWhere(altar, isWand) end

function sever(altar, item)
    local holders = EntityGetAllChildren(altar) or {}
    for i = 1, #holders do
        EntityKill(holders[i])
    end
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

local pickupLua = "script_item_picked_up"
local pickupFlask = {
    execute_every_n_frame = 1,
    execute_times = 0,
    limit_how_many_times_per_frame = -1,
    limit_to_every_n_frame = -1,
    remove_after_executed = true,
    script_item_picked_up = "data/scripts/items/potion_effect.lua",
    mLastExecutionFrame = -1,
    mTimesExecutedThisFrame = 0
}

local pickupWand = {
    execute_every_n_frame = 1,
    execute_times = 0,
    limit_how_many_times_per_frame = -1,
    limit_to_every_n_frame = -1,
    remove_after_executed = true,
    script_item_picked_up = "data/scripts/particles/wand_pickup.lua",
    mLastExecutionFrame = -1,
    mTimesExecutedThisFrame = 0
}

---Handle linking and unlinking items from an altar, setting and reversing various things.
function handleAltarLink(altar, isUpper, eid, isLinked)
    local x, y = EntityGetTransform(altar)
    local ex, ey = eid ~= 0 and EntityGetTransform(eid) or 0, 0
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
        toggleComps(eid, SPC, nil, not isLinked)
    end

    -- re-enables the first time pickup particles, which are fancy
    if isUpper then
        local pickup = isWand(eid) and pickupWand or pickupFlask
        if isLinked and not hasCompMatch(eid, LC, nil, pickupLua, pickup[pickupLua]) then
            EntityAddComponent2(eid, LC, pickup)
        else
            toggleFirstCompMatching(eid, LC, nil, pickupLua, pickup[pickupLua], isLinked)
        end
    end

    debugOut("linking altar " .. altar .. " to item " .. eid .. " islinked ? " .. tostring(isLinked))
    -- handle adding or removing item from the altar children
    linkOrSever(altar, eid, isLinked)

    -- enable particle emitters on linked items, these are the "new item" particles
    eachComponentSet(eid, SPEC, nil, "velocity_always_away_from_center", isLinked)

    -- enable the altar rune particle emitter if it has any children
    local function itemsLinkedAndParticleGravityZero(comp)
        return cObjGet(comp, "gravity", "y") == 0.0 and #linkedItems(altar) > 0
    end
    toggleCompsWhere(altar, PEC, nil, itemsLinkedAndParticleGravityZero)
end
