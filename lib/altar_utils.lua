dofile_once("data/scripts/lib/utilities.lua")
local flask_utils = dofile_once("mods/offerings/lib/flask_utils.lua") ---@type offering_flask_util
local wand_utils = dofile_once("mods/offerings/lib/wand_utils.lua") ---@type offering_wand_util

local comp_util = dofile_once("mods/offerings/lib/component_utils.lua") ---@type offering_component_util
local entity_utils = dofile_once("mods/offerings/lib/entity_utils.lua") ---@type offering_entity_util
local logger = dofile("mods/offerings/lib/log_utils.lua") ---@type offering_logger


local VSC = "VariableStorageComponent"
local IC = "ItemComponent"
local LC = "LuaComponent"
local SPC = "SimplePhysicsComponent"
local SPEC = "SpriteParticleEmitterComponent"
local PEC = "ParticleEmitterComponent"

---@class SeenItem
---@field item entity_id
---@field innerId integer
---@field x number
---@field y number

---@class MissingLink
---@field item entity_id
---@field innerId integer

local targetAltarWidth = 25
targetAltarWidth = targetAltarWidth
local offerAltarWidth = 58
offerAltarWidth = offerAltarWidth
local targetAltarRadius = math.ceil(targetAltarWidth / 2)
targetAltarRadius = targetAltarRadius
local offerAltarRadius = math.ceil(offerAltarWidth / 2)
offerAltarRadius = offerAltarRadius

local pickupLua = "script_item_picked_up"
pickupLua = pickupLua
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

local upperAltarTag = "offeringsUpperAltar"
local lowerAltarTag = "offeringsLowerAltar"

local function isUpperAltar(eid) return EntityHasTag(eid, upperAltarTag) end

local function isLowerAltar(eid) return EntityHasTag(eid, lowerAltarTag) end

local function isAltar(eid) return isUpperAltar(eid) or isLowerAltar(eid) end

local function upperAltarNear(eid) return entity_utils.closestToEntity(eid, upperAltarTag) end

local function lowerAltarNear(eid) return entity_utils.closestToEntity(eid, lowerAltarTag) end

local function toggleAltarRunes(altar, isLitUp)
    comp_util.toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, 0 }, isLitUp)
end

local function isValidTarget(eid) return wand_utils.isWand(eid) or flask_utils.isFlask(eid) end

local function isWandMatch(target, offer) return wand_utils.isWand(target) and wand_utils.isWandEnhancer(offer) end

local function isFlaskMatch(target, offer) return flask_utils.isFlask(target) and flask_utils.isFlaskEnhancer(offer) end

---Test that the target can be improved by the offering
---@param target entity_id The linked item on the upper altar
---@param eid entity_id A lower altar potential linked item
---@return boolean result true if the target can consume the offering, otherwise false
local function isValidOffer(target, eid) return isWandMatch(target, eid) or isFlaskMatch(target, eid) end

---Find the missing links in our already linked items, returning those unseen by the loop
---@param seenItems SeenItem[] the linkable indices being checked for severance, as an array
---@param alreadyLinked table<entity_id,LinkMap> the existing links being checked, as a kvp map of item id to LinkMap
---@return MissingLink[] array linked items whose inner id mate needs to be relocated
local function detectSeveredLinks(seenItems, alreadyLinked)
    local missing = {} ---@type SeenItem[]
    for _, linkMap in pairs(alreadyLinked) do
        local found = nil
        for _, s in ipairs(seenItems) do
            if s.item == linkMap.item then
                -- when the item has moved resync the item to the holder's x and y
                -- this is not backwards. we want the item to stay where it landed.
                if s.x ~= linkMap.x or s.y ~= linkMap.y then
                    EntitySetTransform(linkMap.item, linkMap.x, linkMap.y)
                end
                found = s.item
            end
        end
        if not found then
            local innerId = comp_util.storedInt(linkMap.holder, "innerId") or 0
            missing[#missing + 1] = { item = linkMap.item, x = linkMap.x, y = linkMap.y, innerId = innerId }
        end
    end
    return missing
end

---Whether the item was picked up by the player nearby, in which case
---we avoid doing certain recalculations and destroy the offerings if needed.
---@param seen SeenItem
local function isMissingItemPickedUp(seen)
    --logger.about("entity picked up item", isItemInInventory(seen.item))
    if entity_utils.isItemInInventory(seen.item) then return true end
    return false
end

local function isLinkableItem(eid)
    --logger.about("eid", eid, "is altar?", isAltar(eid), "isWandEnhancer?", isWandEnhancer(eid),
    --     "isFlaskEnhancer?", isFlaskEnhancer(eid), "isItemInInventory?", isItemInInventory(eid),
    --     "is any parent?", EntityGetParent(eid) == 0)
    return not isAltar(eid) and (wand_utils.isWandEnhancer(eid) or flask_utils.isFlaskEnhancer(eid))
        and not entity_utils.isItemInInventory(eid) and EntityGetParent(eid) == 0
end

---Returns linkables in range in one of two flavors: sequence or map
---@param altar entity_id the altar we're scanning with
---@param isUpper boolean whether the altar is the upper "target" altar
---@return SeenItem[] table containing the linkables in range as an array or key map.
local function linkableItemsNear(altar, isUpper)
    -- different radius b/c wider lower altar
    local radius = isUpper and targetAltarRadius or offerAltarRadius
    local x, y = EntityGetTransform(altar)
    -- get linkables based on which altar we are
    local result = {} ---@type SeenItem[]
    local entities = EntityGetInRadius(x, y, radius)
    for _, eid in ipairs(entities) do
        if isLinkableItem(eid) then
            --logger.about("linkable item found", eid)
            local ex, ey = EntityGetTransform(eid)
            local h = ((ex - x) ^ 2 + (ey - y) ^ 2) ^ 0.5
            if h <= radius then
                local innerId = comp_util.storedInt(eid, "innerId")
                result[#result + 1] = { item = eid, x = ex, y = ey, innerId = innerId or 0 }
            end
        end
    end
    return result
end

local function entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

---@class LinkMap
---@field item entity_id
---@field holder entity_id
---@field x number
---@field y number

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar entity_id The altar we're checking the links of
---@return LinkMap[] array containing the linkables in range as an array
local function linkedItemsArray(altar)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for i, child in ipairs(children) do
        result[i] = { item = comp_util.storedInt(child, "eid") or 0, holder = child }
    end
    return result
end

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar entity_id The altar we're checking the links of
---@return integer, table<entity_id,LinkMap> map containing the linkables in range as a key map.
local function linkedItemsMap(altar)
    local result = {}
    local count = 0
    local children = EntityGetAllChildren(altar) or {}
    for _, child in ipairs(children) do
        local x, y = EntityGetTransform(child)
        ---@diagnostic disable-next-line: assign-type-mismatch
        local linkMap = { item = comp_util.storedInt(child, "eid") or 0, holder = child, x = x, y = y } ---@type LinkMap
        if linkMap.item ~= 0 then
            result[linkMap.item] = linkMap
            count = count + 1
        end
    end
    return count, result
end

local function childSpellItem(eid)
    if not EntityHasTag(eid, "card_action") then return nil end
    return comp_util.firstComponent(eid, "ItemComponent", nil)
end

local function isAlwaysCastSpellComponent(eid)
    return ComponentGetValue2(eid, "permanently_attached") or ComponentGetValue2(eid, "is_frozen")
end

local function dropSpell(child, itemComp, x, y)
    if not itemComp then return end
    -- TODO consider doing stuff with always cast?
    if isAlwaysCastSpellComponent(itemComp) then return end
    EntityRemoveFromParent(child)
    EntitySetComponentsWithTagEnabled(child, "enabled_in_world", true)
    EntitySetTransform(child, x, y)
end

---Stolen from the legacy wand workshop. It's about all that's left of it.
---@param offer entity_id The offer being destroyed
---@param x number The x coord of the offer
---@param y number The y coord of the offer
local function dropSpells(offer, x, y)
    local children = EntityGetAllChildren(offer) or {}
    for _, child in ipairs(children) do
        local itemSpell = childSpellItem(child)
        if itemSpell then dropSpell(child, itemSpell, x, y) end
    end
end

local function targetOfAltar(altar)
    local links = linkedItemsArray(altar)
    if #links > 0 then return links[1] end
    return nil
end

local function forceUpdates(altar, eid, isResetting)
    --logger.about("forcing update from altar", altar, "from id severance", eid)
    -- ALWAYS recalc after a severance.
    local upperAltar = upperAltarNear(altar)
    local lowerAltar = lowerAltarNear(altar)
    local target = targetOfAltar(upperAltar)
    if target == nil then return false end
    if wand_utils.isWand(eid) then
        local combinedWands = nil
        if not isResetting then
            combinedWands = wand_utils.mergeWandStats(upperAltar, lowerAltar)
        end
        --logger.about("combined stats after severance recalc", combined)
        wand_utils.setWandResult(target.item, combinedWands)
    end
    if flask_utils.isFlask(eid) then
        local combinedFlasks = nil
        if not isResetting then
            combinedFlasks = flask_utils.mergeFlaskStats(upperAltar, lowerAltar)
        end
        flask_utils.setFlaskResult(target.item, combinedFlasks)
    end
end

---If the x, y of a missing entity id matches a found one
---we naively assume that is the entity "from before".
---@param altar entity_id The altar of the item that was severed.
---@param missing entity_id The item that was severed
---@param relinkTo entity_id The item that is in the same x/y
---@return entity_id|nil hid The new holder Id the relink is tied to
local function relink(altar, missing, relinkTo)
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local result = nil
    for _, hid in ipairs(holders) do
        if comp_util.storedInt(hid, "eid") == missing then
            comp_util.removeMatch(hid, VSC, nil, "name", "eid")
            comp_util.storeInt(hid, "eid", relinkTo)
            result = hid
            break
        end
    end
    local upperAltar = upperAltarNear(altar)
    -- if the item being relinked is the upper altar
    -- our objective is to *reset* the upper altar, not
    -- to regenerate the stats. It will have lost its originals.
    if upperAltar == altar then
        forceUpdates(altar, missing)
    end
    return result
end

---EntityKill DOES NOT kill the entity right away, so there's some cleanup
---of comps needed before an update is coerced.
---@param altar entity_id The altar of the item that was severed.
---@param eid entity_id The item that was severed
---@param isPickup boolean Whether the item was flagged as picked up
local function sever(altar, eid, isPickup)
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local hidToRemove = nil ---@type entity_id
    for _, hid in ipairs(holders) do
        if comp_util.storedInt(hid, "eid") == eid then
            hidToRemove = hid
            --logger.about("killing holder", hid)
        end
    end
    if hidToRemove ~= 0 then
        comp_util.removeAll(hidToRemove, VSC, nil)
        comp_util.removeAll(hidToRemove, "AbilityComponent", nil)
        EntityKill(hidToRemove)
    end
    if isPickup then return end
    local upperAltar = upperAltarNear(altar)
    local upperItems = #linkedItemsArray(upperAltar)
    if upperItems > 0 then
        forceUpdates(altar, eid)
    end
end

local function destroyAltarItemsUsedInTarget(target, altar)
    --logger.about("destroying offerings after picking up", target)
    local function shouldDestroy(offer)
        if wand_utils.isWand(target) then return wand_utils.isWandEnhancer(offer) end
        if flask_utils.isFlask(target) then return flask_utils.isFlaskEnhancer(offer) end
        return false
    end
    local function destroy(offer)
        -- before destroying flasks, empty them
        if flask_utils.isFlask(offer) then RemoveMaterialInventoryMaterial(offer) end
        -- before destroying wands, drop their spells
        local x, y = EntityGetTransform(offer)
        if wand_utils.isWand(offer) then dropSpells(offer, x, y) end

        EntityLoad("data/entities/particles/destruction.xml", x, y)
        GamePlaySound("data/audio/Desktop/projectiles.bank", "magic/common_destroy", x, y)
        sever(altar, offer, true) -- isPickup stops the target from recalculating here

        -- sever kills the holder, but we still need to kill the actual offering
        EntityKill(offer)
    end
    for _, linkMap in ipairs(linkedItemsArray(altar)) do
        if shouldDestroy(linkMap.item) then destroy(linkMap.item) end
    end
end

local function isLinked(altar, item)
    return linkedItemsMap(altar)[item] ~= nil
end

---Create a holder entity sired by the altar, attached to the item
---it represents. This is used to attach components holding its stats.
---@param altar entity_id
---@param seen SeenItem
---@param innerId integer the number of items on the altar + 1, lets us create links explicitly
---@return entity_id
local function makeHolderLink(altar, seen, innerId)
    -- create a holder for the item and add it to the altar
    local e = EntityLoad("mods/offerings/entity/holder.xml", seen.x, seen.y)
    comp_util.storeInt(e, "eid", seen.item)
    -- reverse lookup thing here, link them to the same id so they know about eachother through a
    -- persistent id. we can't rely on the entity_id but we can persist our own.
    comp_util.storeInt(e, "innerId", innerId)
    comp_util.storeInt(seen.item, "innerId", innerId)
    EntityAddChild(altar, e)
    return e
end

---Handle linking and unlinking items from an altar, setting and reversing various things.
---@param altar entity_id the altar linking or severing
---@param isUpper boolean whether this is the upper (target) altar
---@param seen SeenItem the item being linked or severed
---@param hid entity_id|nil the holder item linked to the item, if one exists
local function setLinkedItemBehaviors(altar, isUpper, seen, hid)
    local isItemLinked = hid ~= nil
    toggleAltarRunes(altar, isItemLinked)

    -- aesthetic stuff when linking the item to the altar, rotation mainly.
    if isItemLinked then
        local x, y = EntityGetTransform(altar)
        local dx = isUpper and x or seen.x
        local dy = y - 5 -- floaty
        local uprightRot = wand_utils.isWand(seen.item) and -math.pi * 0.5 or 0.0
        EntitySetTransform(seen.item, dx, dy, uprightRot)
        -- ensure the item holder matches the item's new location
        seen.x = dx
        seen.y = dy
        if hid then EntitySetTransform(hid, dx, dy, uprightRot) end
        comp_util.eachComponentSet(seen.item, IC, nil, "spawn_pos", dx, dy)
    end

    -- make "first time pickup" fanfare when picking the item up
    comp_util.eachComponentSet(seen.item, IC, nil, "has_been_picked_by_player", not isItemLinked)

    if wand_utils.isWand(seen.item) then
        -- immobilize wands
        comp_util.eachComponentSet(seen.item, IC, nil, "play_hover_animation", not isItemLinked)
        comp_util.eachComponentSet(seen.item, IC, nil, "play_spinning_animation", not isItemLinked)
        comp_util.toggleComps(seen.item, SPC, nil, not isItemLinked)
    else
        comp_util.toggleComps(seen.item, "VelocityComponent", nil, not isItemLinked)
    end

    -- re-enables the first time pickup particles, which are fancy
    if isUpper then
        local pickup = wand_utils.isWand(seen.item) and pickupWand or pickupFlask
        if isItemLinked and not comp_util.hasCompMatch(seen.item, LC, nil, pickupLua, pickup[pickupLua]) then
            EntityAddComponent2(seen.item, LC, pickup)
        else
            comp_util.toggleFirstCompMatching(seen.item, LC, nil, pickupLua, pickup[pickupLua], isItemLinked)
        end
    end

    -- enable particle emitters on linked items, these are the "new item" particles
    comp_util.eachComponentSet(seen.item, SPEC, nil, "velocity_always_away_from_center", isItemLinked)
end

---Removes any existing links that have been severed by non-existence or removal.
---@param altar entity_id the altar doing the unlinking/severing
---@param missingLinks SeenItem[] the existing links being checked, as a kvp map of item id to LinkMap
---@param linkables SeenItem[] the linkable indices being checked for severance, as an array
---@param beforeSeverFunc fun(altar: entity_id, seenItem: SeenItem) the function to perform before severing each item
---@return LinkMap[] relinkedItems the links restored by item location
local function cullOrRelinkItemLinks(altar, missingLinks, linkables, beforeSeverFunc)
    local relinks = {} ---@type table<SeenItem, SeenItem>
    local culls = {} ---@type SeenItem[]
    local results = {} ---@type LinkMap[]
    for i, missingLink in ipairs(missingLinks) do
        -- figure out if the link can be restored from an item
        -- at the exact same x and y coordinates as the missing link
        for _, linkable in ipairs(linkables) do
            --logger.about("missing link", missingLink, "possible replacement", linkable)
            if missingLink.innerId == linkable.innerId then
                relinks[missingLink] = linkable
                break
            end
        end
        if relinks[missingLink] == nil then
            culls[#culls + 1] = missingLink
            break
        end
    end
    for missing, found in pairs(relinks) do
        --logger.about("relinking item", missing.item, "to item", found.item)
        local reHolder = relink(altar, missing.item, found.item)
        if reHolder then
            results[#results + 1] = { holder = reHolder, item = found.item, x = found.x, y = found.y }
        end
    end
    for _, cull in ipairs(culls) do
        --logger.about("severing missing item", cull.item)
        local isUpper = isUpperAltar(altar)
        -- restore vanilla behaviors to now-not-linked item
        setLinkedItemBehaviors(altar, isUpper, cull, nil)
        if isUpper and isMissingItemPickedUp(cull) then
            destroyAltarItemsUsedInTarget(cull.item, lowerAltarNear(altar))
            sever(altar, cull.item, true)
        else
            beforeSeverFunc(altar, cull)
            sever(altar, cull.item, false)
        end
    end
    return results
end

local M = {} ---@class offering_altar

---Executes a linking function and a severing function when the
---requirements for either is met, which depends on the altar calling it.
---@param altar entity_id the altar id running the scan
---@param isUpper boolean whether the altar is the target altar
---@param linkFunc fun(altar: entity_id, eid: SeenItem, linkCount: integer): boolean the link function to use
---@param beforeSeverFunc fun(altar: entity_id, eid: SeenItem)
function M.scanForLinkableItems(altar, isUpper, linkFunc, beforeSeverFunc)
    -- ignore altars that are far from the player.
    local x, y = EntityGetTransform(altar)

    -- floaty particle stuff and a light when player is near
    local isPlayerNear = #EntityGetInRadiusWithTag(x, y, 120, "player_unit") > 0
    comp_util.toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, -10 }, isPlayerNear)
    comp_util.toggleComps(altar, "LightComponent", nil, isPlayerNear)
    local hasAnyLink = false
    if isPlayerNear then
        -- search for linkables, including already linked items
        -- we need all items because we are culling any items that aren't in range
        -- and already linked items don't want to be *culled*, just avoid linking >1 time.
        local linkables = linkableItemsNear(altar, isUpper)
        local linkCount, alreadyLinked = linkedItemsMap(altar)
        local missingLinks = detectSeveredLinks(linkables, alreadyLinked)
        local relinkedLinkmaps = cullOrRelinkItemLinks(altar, missingLinks, linkables, beforeSeverFunc)
        for _, linkmap in ipairs(relinkedLinkmaps) do
            alreadyLinked[linkmap.item] = linkmap
        end
        for _, seen in ipairs(linkables) do
            if alreadyLinked[seen.item] == nil then
                hasAnyLink = linkFunc(altar, seen, linkCount) or hasAnyLink
            else
                hasAnyLink = true
            end
        end
    end
    -- these lights ALSO turn off if the player goes away
    comp_util.toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, 0 }, hasAnyLink)
end

---Handles the logic of determining an object is a valid altar target
---for the upper altar and linking it if possible.
---@param upperAltar entity_id The altar to target items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@param linkedCount integer the number of linked items on the altar, lets us create ids
---@return boolean isNewLinkFormed whether the altar found a new link
function M.targetLinkFunc(upperAltar, seen, linkedCount)
    if targetOfAltar(upperAltar) ~= nil then return false end
    if not isValidTarget(seen.item) then return false end

    -- handle adding or removing item from the altar children
    local holder = makeHolderLink(upperAltar, seen, linkedCount + 1)
    setLinkedItemBehaviors(upperAltar, true, seen, holder)
    --logger.about("holder", holder, "holder wand", seen.item)
    if wand_utils.isWand(seen.item) then
        if holder then wand_utils.storeWandStats(seen.item, holder) end
        local combinedWands = wand_utils.mergeWandStats(upperAltar, lowerAltarNear(upperAltar))
        wand_utils.setWandResult(seen.item, combinedWands)
    elseif flask_utils.isFlask(seen.item) then
        --logger.about("holder", holder, "holder flask", eid)
        if holder then flask_utils.storeFlaskStats(seen.item, holder) end
        local combinedFlasks = flask_utils.mergeFlaskStats(upperAltar, lowerAltarNear(upperAltar))
        flask_utils.setFlaskResult(seen.item, combinedFlasks)
    end
    return true
end

---Handles the logic of determining an object is a valid offering
---for the lower altar and linking it if possible.
---@param lowerAltar entity_id The altar to sacrifice items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@param linkedCount integer the number of linked items on the altar, lets us create ids
---@return boolean isNewLinkFormed whether the altar found a new link
function M.offerLinkFunc(lowerAltar, seen, linkedCount)
    local upperAltar = upperAltarNear(lowerAltar)
    local target = targetOfAltar(upperAltar)
    if target == nil then return false end
    --logger.about("target", target)
    if not isValidOffer(target.item, seen.item) then return false end
    local holder = makeHolderLink(lowerAltar, seen, linkedCount + 1)
    setLinkedItemBehaviors(lowerAltar, false, seen, holder)
    if wand_utils.isWandEnhancer(seen.item) then
        if holder then wand_utils.storeWandStats(seen.item, holder) end
        local combined = wand_utils.mergeWandStats(upperAltar, lowerAltar)
        wand_utils.setWandResult(target.item, combined)
    end
    if flask_utils.isFlaskEnhancer(seen.item) then
        if holder then flask_utils.storeFlaskStats(seen.item, holder) end
        local combined = flask_utils.mergeFlaskStats(upperAltar, lowerAltar)
        flask_utils.setFlaskResult(target.item, combined)
    end
    return true
end

---Before-sever-function for offers, restores them to their vanilla state.
---@param altar entity_id The target altar restoring the item
---@param seenItem SeenItem The item id being restored
function M.offerSever(altar, seenItem) end

---Before-sever-function for targets, restores them to their vanilla state.
---@param altar entity_id The target altar restoring the item
---@param seenItem SeenItem The item id being restored
function M.targetSever(altar, seenItem)
    --logger.about("restoring item ", seenItem)
    if wand_utils.isWand(seenItem.item) then
        local combinedWands = wand_utils.mergeWandStats(altar, nil)
        wand_utils.setWandResult(seenItem.item, combinedWands)
    elseif flask_utils.isFlask(seenItem.item) then
        local combinedFlasks = flask_utils.mergeFlaskStats(altar, nil)
        flask_utils.setFlaskResult(seenItem.item, combinedFlasks)
    end
end

M.lowerAltarNear = lowerAltarNear

return M