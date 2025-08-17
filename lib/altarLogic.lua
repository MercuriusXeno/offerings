dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/logging.lua")
dofile_once("mods/offerings/lib/flaskStats.lua")
dofile_once("mods/offerings/lib/wandStats.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

---@class SeenItem
---@field item entity_id
---@field x number
---@field y number

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

---Executes a linking function and a severing function when the
---requirements for either is met, which depends on the altar calling it.
---@param altar entity_id the altar id running the scan
---@param isUpper boolean whether the altar is the target altar
---@param linkFunc fun(altar: entity_id, eid: SeenItem): boolean the link function to use
---@param beforeSeverFunc fun(altar: entity_id, linkables: entity_id[],
---    beforeSeverFunc:fun(altar: entity_id, eid: entity_id))
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
        local linkables = linkableItemsNear(altar, isUpper)
        local alreadyLinked = linkedItemsMap(altar)
        local missingLinks = detectSeveredLinks(linkables, alreadyLinked)
        local relinkedLinkmaps = cullOrRelinkItemLinks(altar, missingLinks, linkables, beforeSeverFunc)
        for i, linkmap in ipairs(relinkedLinkmaps) do
            alreadyLinked[linkmap.item] = linkmap
        end
        for _, seen in ipairs(linkables) do
            if alreadyLinked[seen.item] == nil then
                hasAnyLink = linkFunc(altar, seen) or hasAnyLink
            else
                hasAnyLink = true
            end
        end
    end
    -- these lights ALSO turn off if the player goes away
    toggleFirstCompMatching(altar, PEC, nil, "gravity", { 0, 0 }, hasAnyLink)
end

function isValidTarget(eid) return isWand(eid) or isFlask(eid) end

---Handles the logic of determining an object is a valid altar target
---for the upper altar and linking it if possible.
---@param upperAltar entity_id The altar to target items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@return boolean isNewLinkFormed whether the altar found a new link
function targetLinkFunc(upperAltar, seen)
    if targetOfAltar(upperAltar) ~= nil then return false end
    if not isValidTarget(seen.item) then return false end
    local holder = altarLinkToSeenItem(upperAltar, true, seen, true)
    --thonk.about("holder", holder, "holder wand", seen.item)
    if isWand(seen.item) then
        if holder then storeWandStats(seen.item, holder) end
        local combinedWands = mergeWandStats(upperAltar, lowerAltarNear(upperAltar))
        setWandResult(seen.item, combinedWands)
    elseif isFlask(seen.item) then
        --thonk.about("holder", holder, "holder flask", eid)
        if holder then storeFlaskStats(seen.item, holder) end
        local combinedFlasks = mergeFlaskStats(upperAltar, lowerAltarNear(upperAltar))
        setFlaskResult(seen.item, combinedFlasks)
    end
    return true
end

---Handles the logic of determining an object is a valid offering
---for the lower altar and linking it if possible.
---@param lowerAltar entity_id The altar to sacrifice items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@return boolean isNewLinkFormed whether the altar found a new link
function offerLinkFunc(lowerAltar, seen)
    local upperAltar = upperAltarNear(lowerAltar)
    local target = targetOfAltar(upperAltar)
    if target == nil then return false end
    --thonk.about("target", target)
    if not isValidOffer(target.item, seen.item) then return false end
    local holder = altarLinkToSeenItem(lowerAltar, false, seen, true)
    if isWand(seen.item) then
        if holder then storeWandStats(seen.item, holder) end
        combined = mergeWandStats(upperAltar, lowerAltar)
        setWandResult(target.item, combined)
    end
    if isFlask(seen.item) then
        if holder then storeFlaskStats(seen.item, holder) end
        combined = mergeFlaskStats(upperAltar, lowerAltar)
        setFlaskResult(target.item, combined)
    end
    return true
end

function offerSeverNoop(lowerAltar, eid)
end

---Before-sever-function for targets, restores them to their vanilla state.
---@param altar entity_id The target altar restoring the item
---@param eid entity_id The item id being restored
function restoreTargetOriginalStats(altar, eid)
    --thonk.about("restoring item ", eid)
    if isWand(eid) then
        local combinedWands = mergeWandStats(altar, nil)
        setWandResult(eid, combinedWands)
    elseif isFlask(eid) then
        local combinedFlasks = mergeFlaskStats(altar, nil)
        setFlaskResult(eid, combinedFlasks)
    end
end

function isWandMatch(target, offer) return isWand(target) and isWandEnhancer(offer) end

function isFlaskMatch(target, offer) return isFlask(target) and isFlaskEnhancer(offer) end

---Test that the target can be improved by the offering
---@param target entity_id The linked item on the upper altar
---@param eid entity_id A lower altar potential linked item
---@return boolean result true if the target can consume the offering, otherwise false
function isValidOffer(target, eid) return isWandMatch(target, eid) or isFlaskMatch(target, eid) end

---Find the missing links in our already linked items, returning those unseen by the loop
---@param seenItems SeenItem[] the linkable indices being checked for severance, as an array
---@param alreadyLinked table<entity_id,LinkMap> the existing links being checked, as a kvp map of item id to LinkMap
---@return SeenItem[] array of seen items (in this case unseen items) ids and x/y coordinates
function detectSeveredLinks(seenItems, alreadyLinked)
    local unseen = {} ---@type SeenItem[]
    for linkedItem, linkMap in pairs(alreadyLinked) do
        local found = nil
        for _, s in ipairs(seenItems) do
            if s.item == linkedItem then found = s.item end
        end
        if not found then
            unseen[#unseen + 1] = { item = linkedItem, x = linkMap.x, y = linkMap.y }
        end
    end
    return unseen
end

---Removes any existing links that have been severed by non-existence or removal.
---@param altar entity_id the altar doing the unlinking/severing
---@param missingLinks SeenItem[] the existing links being checked, as a kvp map of item id to LinkMap
---@param linkables SeenItem[] the linkable indices being checked for severance, as an array
---@param beforeSeverFunc fun(altar: entity_id, eid: entity_id) the function to perform before severing each item
---@return LinkMap[] relinkedItems the links restored by item location
function cullOrRelinkItemLinks(altar, missingLinks, linkables, beforeSeverFunc)
    local relinks = {} ---@type table<SeenItem, SeenItem>
    local culls = {} ---@type SeenItem[]
    local results = {} ---@type LinkMap[]
    for i, missingLink in ipairs(missingLinks) do
        -- figure out if the link can be restored from an item
        -- at the exact same x and y coordinates as the missing link
        for _, linkable in ipairs(linkables) do
            --thonk.about("missing link", missingLink, "possible replacement", linkable)
            if missingLink.x == linkable.x and missingLink.y == linkable.y then
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
        --thonk.about("relinking item", missing.item, "to item", found.item)
        local newHolder = relink(altar, missing.item, found.item)
        if newHolder then
            results[#results + 1] = { holder = newHolder, item = found.item, x = found.x, y = found.y }
        end
    end
    for _, cull in ipairs(culls) do
        --thonk.about("severing missing item", cull.item)
        if isUpperAltar(altar) and isMissingItemPickedUp(cull) then
            destroyAltarItemsUsedInTarget(cull.item, lowerAltarNear(altar))
            sever(altar, cull.item, true)
        else
            beforeSeverFunc(altar, cull.item)
            sever(altar, cull.item, false)
        end
    end
    return results
end

---Whether the item was picked up by the player nearby, in which case
---we avoid doing certain recalculations and destroy the offerings if needed.
---@param seen SeenItem
function isMissingItemPickedUp(seen)
    --thonk.about("entity picked up item", isItemInInventory(seen.item))
    if isItemInInventory(seen.item) then return true end
    return false
end

---If the x, y of a missing entity id matches a found one
---we naively assume that is the entity "from before".
---@param altar entity_id The altar of the item that was severed.
---@param missing entity_id The item that was severed
---@param relinkTo entity_id The item that is in the same x/y
---@return entity_id|nil hid The new holder Id the relink is tied to
function relink(altar, missing, relinkTo)
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local result = nil
    for _, hid in ipairs(holders) do
        if storedInt(hid, "eid") == missing then
            removeAll(hid, VSC, nil)
            storeInt(hid, "eid", relinkTo)
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

---Returns linkables in range in one of two flavors: sequence or map
---@param altar entity_id the altar we're scanning with
---@param isUpper boolean whether the altar is the upper "target" altar
---@return SeenItem[] table containing the linkables in range as an array or key map.
function linkableItemsNear(altar, isUpper)
    -- different radius b/c wider lower altar
    local radius = isUpper and targetAltarRadius or offerAltarRadius
    local x, y = EntityGetTransform(altar)
    -- get linkables based on which altar we are
    local result = {} ---@type SeenItem[]
    local entities = EntityGetInRadius(x, y, radius)
    for _, eid in ipairs(entities) do
        if isLinkableItem(eid) then
            local ex, ey = EntityGetTransform(eid)
            local h = ((ex - x) ^ 2 + (ey - y) ^ 2) ^ 0.5
            if h <= radius then
                result[#result + 1] = { item = eid, x = ex, y = ey }
            end
        end
    end
    return result
end

function isLinkableItem(eid)
    return not isAltar(eid) and (isWandEnhancer(eid) or isFlaskEnhancer(eid))
        and not isItemInInventory(eid) and EntityGetParent(eid) == 0
end

function entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

---@class LinkMap
---@field item entity_id
---@field holder entity_id
---@field x number
---@field y number

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar entity_id The altar we're checking the links of
---@return LinkMap[] array containing the linkables in range as an array
function linkedItemsArray(altar)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for i, child in ipairs(children) do
        result[i] = { item = storedInt(child, "eid") or 0, holder = child }
    end
    return result
end

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar entity_id The altar we're checking the links of
---@return table<entity_id,LinkMap> map containing the linkables in range as a key map.
function linkedItemsMap(altar)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for _, child in ipairs(children) do
        local x, y = EntityGetTransform(child)
        ---@diagnostic disable-next-line: assign-type-mismatch
        local linkMap = { item = storedInt(child, "eid") or 0, holder = child, x = x, y = y } ---@type LinkMap
        if linkMap.item ~= 0 then result[linkMap.item] = linkMap end
    end
    return result
end

---EntityKill DOES NOT kill the entity right away, so there's some cleanup
---of comps needed before an update is coerced.
---@param altar entity_id The altar of the item that was severed.
---@param eid entity_id The item that was severed
---@param isPickup boolean Whether the item was flagged as picked up
function sever(altar, eid, isPickup)
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local hidToRemove = nil ---@type entity_id
    for _, hid in ipairs(holders) do
        if storedInt(hid, "eid") == eid then
            hidToRemove = hid
            --thonk.about("killing holder", hid)
        end
    end
    if hidToRemove ~= 0 then
        removeAll(hidToRemove, VSC, nil)
        removeAll(hidToRemove, "AbilityComponent", nil)
        EntityKill(hidToRemove)
    end
    if isPickup then return end
    local upperAltar = upperAltarNear(altar)
    local upperItems = #linkedItemsArray(upperAltar)
    if upperItems > 0 then
        forceUpdates(altar, eid)
    end
end

function forceUpdates(altar, eid, isResetting)
    --thonk.about("forcing update from altar", altar, "from id severance", eid)
    -- ALWAYS recalc after a severance.
    local upperAltar = upperAltarNear(altar)
    local lowerAltar = lowerAltarNear(altar)
    local target = targetOfAltar(upperAltar)
    if target == nil then return false end
    if isWand(eid) then
        local combinedWands = nil
        if not isResetting then
            combinedWands = mergeWandStats(upperAltar, lowerAltar)
        end
        --thonk.about("combined stats after severance recalc", combined)
        setWandResult(target.item, combinedWands)
    end
    if isFlask(eid) then
        local combinedFlasks = nil
        if not isResetting then
            combinedFlasks = mergeFlaskStats(upperAltar, lowerAltar)
        end
        setFlaskResult(target.item, combinedFlasks)
    end
end

function destroyAltarItemsUsedInTarget(target, altar)
    --thonk.about("destroying offerings after picking up", target)
    local function shouldDestroy(offer)
        if isWand(target) then return isWandEnhancer(offer) end
        if isFlask(target) then return isFlaskEnhancer(offer) end
        return false
    end
    local function destroy(offer)
        -- before destroying flasks, empty them
        if isFlask(offer) then RemoveMaterialInventoryMaterial(offer) end
        -- before destroying wands, drop their spells
        local x, y = EntityGetTransform(offer)
        if isWand(offer) then dropSpells(offer, x, y) end

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

---Stolen from the legacy wand workshop. It's about all that's left of it.
---@param offer entity_id The offer being destroyed
---@param x number The x coord of the offer
---@param y number The y coord of the offer
function dropSpells(offer, x, y)
    local children = EntityGetAllChildren(offer) or {}
    for _, child in ipairs(children) do
        local itemSpell = childSpellItem(child)
        if itemSpell then dropSpell(child, itemSpell, x, y) end
    end
end

function childSpellItem(eid)
    if not EntityHasTag(eid, "card_action") then return nil end
    return firstComponent(eid, "ItemComponent", nil)
end

function dropSpell(child, itemComp, x, y)
    if not itemComp then return end
    -- TODO consider doing stuff with always cast?
    if isAlwaysCastSpellComponent(itemComp) then return end
    EntityRemoveFromParent(child)
    EntitySetComponentsWithTagEnabled(child, "enabled_in_world", true)
    EntitySetTransform(child, x, y)
end

function isAlwaysCastSpellComponent(eid)
    return ComponentGetValue2(eid, "permanently_attached") or ComponentGetValue2(eid, "is_frozen")
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
    local links = linkedItemsArray(altar)
    if #links > 0 then return links[1] end
    return nil
end

function isLinked(altar, item)
    return linkedItemsMap(altar)[item] ~= nil
end

---Create a holder entity sired by the altar, attached to the item
---it represents. This is used to attach components holding its stats.
---@param altar entity_id
---@param seen SeenItem
---@return entity_id
function makeHolderLink(altar, seen)
    -- create a holder for the item and add it to the altar
    local e = EntityLoad("mods/offerings/entity/holder.xml", seen.x, seen.y)
    storeInt(e, "eid", seen.item)
    EntityAddChild(altar, e)
    return e
end

---Handle linking and unlinking items from an altar, setting and reversing various things.
---@param altar entity_id the altar linking or severing
---@param isUpper boolean whether this is the upper (target) altar
---@param seen SeenItem the item being linked or severed
---@return entity_id|nil eid the holder being linked in the process, or nil for severance
function altarLinkToSeenItem(altar, isUpper, seen, isItemLinked)
    toggleAltarRunes(altar, isItemLinked)

    -- aesthetic stuff when linking the item to the altar, rotation mainly.
    if isItemLinked then
        local x, y = EntityGetTransform(altar)
        local dx = isUpper and x or seen.x
        local dy = y - 5 -- floaty
        local uprightRot = isWand(seen.item) and -math.pi * 0.5 or 0.0
        EntitySetTransform(seen.item, dx, dy, uprightRot)
        -- ensure the item holder matches the item's new location
        seen.x = dx
        seen.y = dy
        eachComponentSet(seen.item, IC, nil, "spawn_pos", dx, dy)
    end

    -- make "first time pickup" fanfare when picking the item up
    eachComponentSet(seen.item, IC, nil, "has_been_picked_by_player", not isItemLinked)

    if isWand(seen.item) then
        -- immobilize wands
        eachComponentSet(seen.item, IC, nil, "play_hover_animation", not isItemLinked)
        eachComponentSet(seen.item, IC, nil, "play_spinning_animation", not isItemLinked)
        toggleComps(seen.item, SPC, nil, not isItemLinked)
    end

    -- re-enables the first time pickup particles, which are fancy
    if isUpper then
        local pickup = isWand(seen.item) and pickupWand or pickupFlask
        if isItemLinked and not hasCompMatch(seen.item, LC, nil, pickupLua, pickup[pickupLua]) then
            EntityAddComponent2(seen.item, LC, pickup)
        else
            toggleFirstCompMatching(seen.item, LC, nil, pickupLua, pickup[pickupLua], isItemLinked)
        end
    end

    -- handle adding or removing item from the altar children
    local holder = makeHolderLink(altar, seen)

    -- enable particle emitters on linked items, these are the "new item" particles
    eachComponentSet(seen.item, SPEC, nil, "velocity_always_away_from_center", isItemLinked)

    return holder
end
