dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/lib/flasks.lua")
dofile_once("mods/offerings/lib/wandStats.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

local targetAltarWidth = 25
local offerAltarWidth = 58
local targetAltarRadius = math.ceil(targetAltarWidth / 2)
local offerAltarRadius = math.ceil(offerAltarWidth / 2)

local VSC = "VariableStorageComponent"
local IC = "ItemComponent"
local LC = "LuaComponent"
local SPC = "SimplePhysicsComponent"
local SPEC = "SpriteParticleEmitterComponent"
local PEC = "ParticleEmitterComponent"

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

---Executes a linking function and a severing function when the
---requirements for either is met, which depends on the altar calling it.
---@param altar integer the altar id running the scan
---@param isUpper boolean whether the altar is the target altar
---@param linkFunc fun(altar: integer, eid: integer): boolean the link function to use
---@param beforeSeverFunc fun(altar: integer, linkables: integer[],
---    beforeSeverFunc:fun(altar: integer, eid: integer))
function scanForLinkableItems(altar, isUpper, linkFunc, beforeSeverFunc)
    -- ignore altars that are far from the player.
    local x, y = EntityGetTransform(altar)

    -- floaty particle stuff and a light when player is near
    local isPlayerNear = #EntityGetInRadiusWithTag(x, y, 120, "player_unit") > 0
    toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, -10 }, isPlayerNear)
    toggleComps(altar, "LightComponent", nil, isPlayerNear)
    local hasAnyLink = false
    if isPlayerNear then
        -- search for linkables, including already linked items
        -- we need all items because we are culling any items that aren't in range
        -- and already linked items don't want to be *culled*, just avoid linking >1 time.
        local linkables = linkableItemsNear(altar, isUpper, true)
        local alreadyLinked = linkedItems(altar, false)
        cullSeveredLinks(altar, linkables, alreadyLinked, beforeSeverFunc)
        for _, eid in ipairs(linkables) do
            if alreadyLinked[eid] == nil then
                hasAnyLink = hasAnyLink or linkFunc(altar, eid)
            else
                hasAnyLink = true
            end
        end
    end
    -- these lights ALSO turn off if the player goes away
    toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, 0 }, hasAnyLink)
end

---Returns linkables in range in one of two flavors: sequence or map
---@param altar integer the altar we're scanning with
---@param isUpper boolean whether the altar is the upper "target" altar
---@param isSequence boolean Whether to return the results as an array or a kvp map
---@return integer[]|table array containing the linkables in range as an array or key map.
function linkableItemsNear(altar, isUpper, isSequence)
    -- different radius b/c wider lower altar
    local radius = isUpper and targetAltarRadius or offerAltarRadius
    local x, y = EntityGetTransform(altar)
    -- get linkables based on which altar we are
    return linkablesInRange(x, y, radius, isSequence)
end

---Returns linkables in range in one of two flavors: sequence or map
---@param x number The x coordinate of the altar
---@param y number The y coordinate of the altar
---@param radius number The radial reach of the altar's scanning
---@param isSequence boolean Whether to return the results as an array or a kvp map
---@return integer[]|table array containing the linkables in range as an array or key map.
function linkablesInRange(x, y, radius, isSequence)
    local map = {}
    local entities = EntityGetInRadius(x, y, radius)
    for _, eid in ipairs(entities) do
        if isLinkableInRange(eid, x, y, radius) then
            local index = isSequence and #map + 1 or eid
            map[index] = eid
        end
    end
    return map
end

function isLinkableInRange(eid, x, y, radius)
    if not isLinkableItem(eid) then return false end
    local ex, ey = EntityGetTransform(eid)
    local h = ((ex - x) ^ 2 + (ey - y) ^ 2) ^ 0.5
    return h <= radius
end

function isLinkableItem(eid)
    return not isAltar(eid) and (isWandEnhancer(eid) or isFlaskEnhancer(eid))
        and not isInventory(eid) and EntityGetParent(eid) == 0
end

function entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar integer The altar we're checking the links of
---@param isSequence boolean Whether to return the results as an array or a kvp map
---@return integer[]|table array containing the linkables in range as an array or key map.
function linkedItems(altar, isSequence)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for i, child in ipairs(children) do
        local eid = storedInt(child, "eid", true)
        local index = isSequence and i or eid
        if index ~= nil then result[index] = eid end
    end
    return result
end

---Removes any existing links that have been severed by non-existence or removal.
---@param altar integer the altar doing the unlinking/severing
---@param linkables integer[] the linkable indices being checked for severance, as an array
---@param alreadyLinked table the existing links being checked, as a kvp map
---@param beforeSeverFunc fun(altar: integer, eid: integer) the function to perform before severing each item
function cullSeveredLinks(altar, linkables, alreadyLinked, beforeSeverFunc)
    local seen = {}
    for i, linkable in ipairs(linkables) do
        local x, y = EntityGetTransform(linkable)
        seen[i] = { k = linkable, x = x, y = y } -- store the location
    end
    for k, _ in pairs(alreadyLinked) do
        local x, y = EntityGetTransform(k)
        local found = 0
        for i, s in ipairs(seen) do
            if s.k == k then found = s.k end        
        end
        if found == 0 then
            for i, s in ipairs(seen) do
                if s.x == x and s.y == y then found = s.k end
            end
        end
        if found == 0 then
            -- if we can't find an item at the x/y we sever the link
            thonk.about("missing item", k)
            beforeSeverFunc(altar, k)
            sever(altar, k)
        elseif found ~= k then
            -- otherwise update the eid of the holder to that item's
            thonk.about("relinking item", k)
            relink(altar, k, found)
        end
    end
end


---If the x, y of a missing entity id matches a found one
---we naively assume that is the entity "from before".
---@param altar integer The altar of the item that was severed.
---@param eid integer The item that was severed
---@param found integer The item that is in the same x/y
function relink(altar, eid, found)
    
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local relinkId = 0
    for _, hid in ipairs(holders) do
        if storedInt(hid, "eid", true) == eid then
            relinkId = hid
            --thonk.about("killing holder", hid)
        end
    end
    if relinkId ~= 0 then
        removeAll(relinkId, VSC, nil)
        storeInt(relinkId, "eid", found)
    end
    local upperAltar = upperAltarNear(altar)
    -- if the altar is the upper altar *rewrite* its stats back
    -- to the original item using the holder wand stats.
    if upperItems > 0 then
        forceUpdates(altar, eid)
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
    eachEntityWhere(linkedItems(altar, true), destroyPredicate, destroyFunction)
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

function targetOfAltar(altar)
    local links = linkedItems(altar, true)
    if #links > 0 then return links[1] end
    return nil
end

function isLinked(altar, item)
    return linkedItems(altar, false)[item] ~= nil
end

---Create a holder entity sired by the altar, attached to the item
---it represents. This is used to attach components holding its stats.
---@param altar number
---@param item number
---@return number
function linkItemToAltar(altar, item)
    -- create a holder for the item and add it to the altar
    local e = EntityLoad("mods/offerings/entity/holder.xml", EntityGetTransform(altar))
    storeInt(e, "eid", item)
    EntityAddChild(altar, e)
    return e
end

---Handle linking and unlinking items from an altar, setting and reversing various things.
---@param altar integer the altar linking or severing
---@param isUpper boolean whether this is the upper (target) altar
---@param eid integer the item being linked or severed
---@param isLinked boolean whether the item is being linked or not
---@return integer eid the holder being linked in the process, or 0 for severance
function handleAltarLink(altar, isUpper, eid, isLinked)
    toggleAltarRunes(altar, isLinked)

    -- aesthetic stuff when linking the item to the altar, rotation mainly.
    if isLinked then
        local x, y = EntityGetTransform(altar)
        local ex, ey = EntityGetTransform(eid)
        local dx = isUpper and x or ex
        local dy = y - 5 -- floaty
        local uprightRot = isWand(eid) and -math.pi * 0.5 or 0.0
        EntitySetTransform(eid, dx, dy, uprightRot)
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

    -- handle adding or removing item from the altar children
    local holder = linkOrSever(altar, eid, isLinked)

    -- enable particle emitters on linked items, these are the "new item" particles
    eachComponentSet(eid, SPEC, nil, "velocity_always_away_from_center", isLinked)

    return holder
end

---EntityKill DOES NOT kill the entity right away, so there's some cleanup
---of comps needed before an update is coerced.
---@param altar integer The altar of the item that was severed.
---@param eid integer The item that was severed
function sever(altar, eid)    
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local killId = 0
    for _, hid in ipairs(holders) do
        if storedInt(hid, "eid", true) == eid then
            killId = hid
            --thonk.about("killing holder", hid)
        end
    end
    if killId ~= 0 then
        removeAll(killId, VSC, nil)
        removeAll(killId, "AbilityComponent", nil)
        EntityKill(killId)
    end
    local upperAltar = upperAltarNear(altar)
    local upperItems = #linkedItems(upperAltar, true)
    if upperItems > 0 then
        forceUpdates(altar, eid)
    end
end

function forceUpdates(altar, eid)
    --thonk.about("forcing update from altar", altar, "from id severance", eid)
    -- ALWAYS recalc after a severance.
    local upperAltar = upperAltarNear(altar)
    local lowerAltar = lowerAltarNear(altar)
    if isWand(eid) then
        combined = mergeWandStats(upperAltar, lowerAltar)
        --thonk.about("combined stats after severance recalc", combined)
        setWandResult(targetOfAltar(upperAltar), combined)
    end
    if isFlask(eid) then
        combined = mergeWandStats(upperAltar, lowerAltar)
        setFlaskResult(targetOfAltar(upperAltar), combined)
    end
end

---Return the new entity holder representing the link, or 0 if severed.
---@param altar integer the altar linking or severing the relationship
---@param eid integer the item being linked or severed
---@param isLinking boolean whether the relationship is linking or severing
---@return integer eid belonging to the holder
function linkOrSever(altar, eid, isLinking)
    if isLinking then return linkItemToAltar(altar, eid) end
    sever(altar, eid)
    return 0
end

local upperAltarTag = "offeringsUpperAltar"
local lowerAltarTag = "offeringsLowerAltar"

function isUpperAltar(eid) return EntityHasTag(eid, upperAltarTag) end

function isLowerAltar(eid) return EntityHasTag(eid, lowerAltarTag) end

function isAltar(eid) return isUpperAltar(eid) or isLowerAltar(eid) end

function upperAltarNear(eid) return closestToEntity(eid, upperAltarTag) end

function lowerAltarNear(eid) return closestToEntity(eid, lowerAltarTag) end

function toggleAltarRunes(altar, isLitUp)
    toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, 0 }, isLitUp)
end
