dofile_once("data/scripts/lib/utilities.lua")

local flask_util = dofile_once("mods/offerings/lib/flask_util.lua") ---@type offering_flask_util
local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util
local entity_util = dofile_once("mods/offerings/lib/entity_util.lua") ---@type offering_entity_util
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util
local wand_util = dofile_once("mods/offerings/lib/wand_util.lua") ---@type wand_util

--logger.about("wand_util contents:", wand_util)

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

local UPPER_ALTAR_WIDTH = 25
local LOWER_ALTAR_WIDTH = 58
local UPPER_ALTAR_RANGE = math.ceil(UPPER_ALTAR_WIDTH / 2)
local LOWER_ALTAR_RANGE = math.ceil(LOWER_ALTAR_WIDTH / 2)

local pickup_lua = "script_item_picked_up"
local flask_pickup_script = {
    execute_every_n_frame = 1,
    execute_times = 0,
    limit_how_many_times_per_frame = -1,
    limit_to_every_n_frame = -1,
    remove_after_executed = true,
    script_item_picked_up = "data/scripts/items/potion_effect.lua",
    mLastExecutionFrame = -1,
    mTimesExecutedThisFrame = 0
}

local wand_pickup_sript = {
    execute_every_n_frame = 1,
    execute_times = 0,
    limit_how_many_times_per_frame = -1,
    limit_to_every_n_frame = -1,
    remove_after_executed = true,
    script_item_picked_up = "data/scripts/particles/wand_pickup.lua",
    mLastExecutionFrame = -1,
    mTimesExecutedThisFrame = 0
}

local UPPER_ALTAR_TAG = "offeringsUpperAltar"
local LOWER_ALTAR_TAG = "offeringsLowerAltar"


local M = {} ---@class offering_altar

function M.is_upper_altar(eid) return EntityHasTag(eid, UPPER_ALTAR_TAG) end

function M.is_lower_altar(eid) return EntityHasTag(eid, LOWER_ALTAR_TAG) end

function M.is_altar(eid) return M.is_upper_altar(eid) or M.is_lower_altar(eid) end

function M.get_upper_altar_near(eid) return entity_util.get_nearest_entity_with_tag(eid, UPPER_ALTAR_TAG) end

function M.get_lower_altar_near(eid) return entity_util.get_nearest_entity_with_tag(eid, LOWER_ALTAR_TAG) end

function M.toggle_altar_runes(altar, isLitUp)
    comp_util.toggle_first_comp_matching(altar, PEC, nil, "gravity", { 0, 0 }, isLitUp)
end

function M.is_wand(eid) return EntityHasTag(eid, "wand") end

function M.is_wand_offer(eid) return M.is_wand(eid) end

function M.is_valid_target(eid) return M.is_wand(eid) or flask_util.is_flask(eid) end

function M.is_wand_match(target, offer) return M.is_wand(target) and M.is_wand_offer(offer) end

function M.is_flask_match(target, offer)
    return flask_util.is_flask(target) and
        flask_util.is_flask_offer(offer)
end

---Test that the target can be improved by the offering
---@param target entity_id The linked item on the upper altar
---@param eid entity_id A lower altar potential linked item
---@return boolean result true if the target can consume the offering, otherwise false
function M.is_valid_offer(target, eid)
    return M.is_wand_match(target, eid) or
        M.is_flask_match(target, eid)
end

---Find the missing links in our already linked items, returning those unseen by the loop
---@param seenItems SeenItem[] the linkable indices being checked for severance, as an array
---@param alreadyLinked table<entity_id,LinkMap> the existing links being checked, as a kvp map of item id to LinkMap
---@return MissingLink[] array linked items whose inner id mate needs to be relocated
function M.get_severed_links(seenItems, alreadyLinked)
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
            local innerId = comp_util.get_int(linkMap.holder, "innerId") or 0
            missing[#missing + 1] = { item = linkMap.item, x = linkMap.x, y = linkMap.y, innerId = innerId }
        end
    end
    return missing
end

function M.is_linkable_item(eid)
    return not M.is_altar(eid) and (M.is_wand_offer(eid) or flask_util.is_flask_offer(eid))
        and not entity_util.is_item_in_player_inventory(eid) and EntityGetParent(eid) == 0
end

function M.entityIn(ex, ey, x, y, r, v) return ex >= x - r and ex <= x + r and ey >= y - v and ey <= y + v end

---Returns linkables in range in one of two flavors: sequence or map
---@param altar entity_id the altar we're scanning with
---@param isUpper boolean whether the altar is the upper "target" altar
---@return SeenItem[] table containing the linkables in range as an array or key map.
function M.get_linkable_items_near_altar(altar, isUpper)
    -- different radius b/c wider lower altar
    local radius = isUpper and UPPER_ALTAR_RANGE or LOWER_ALTAR_RANGE
    local x, y = EntityGetTransform(altar)
    -- get linkables based on which altar we are
    local result = {} ---@type SeenItem[]
    local entities = EntityGetInRadius(x, y, radius)
    for _, eid in ipairs(entities) do
        if M.is_linkable_item(eid) then
            local ex, ey = EntityGetTransform(eid)
            local h = ((ex - x) ^ 2 + (ey - y) ^ 2) ^ 0.5
            if h <= radius and M.entityIn(ex, ey, x, y, radius, 10) then
                local innerId = comp_util.get_int(eid, "innerId")
                result[#result + 1] = { item = eid, x = ex, y = ey, innerId = innerId or 0 }
            end
        end
    end
    return result
end

---@class LinkMap
---@field item entity_id
---@field holder entity_id
---@field x number
---@field y number

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar entity_id The altar we're checking the links of
---@return LinkMap[] array containing the linkables in range as an array
function M.linked_item_array(altar)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for i, child in ipairs(children) do
        result[i] = { item = comp_util.get_int(child, "eid") or 0, holder = child }
    end
    return result
end

---Returns already linked items belonging to the altar
---This returns the items, not the holders.
---@param altar entity_id The altar we're checking the links of
---@return integer, table<entity_id,LinkMap> map containing the linkables in range as a key map.
function M.linked_item_map(altar)
    local result = {}
    local count = 0
    local children = EntityGetAllChildren(altar) or {}
    for _, child in ipairs(children) do
        local x, y = EntityGetTransform(child)
        ---@diagnostic disable-next-line: assign-type-mismatch
        local linkMap = { item = comp_util.get_int(child, "eid") or 0, holder = child, x = x, y = y } ---@type LinkMap
        if linkMap.item ~= 0 then
            result[linkMap.item] = linkMap
            count = count + 1
        end
    end
    return count, result
end

function M.childSpellItem(eid)
    if not EntityHasTag(eid, "card_action") then return nil end
    return comp_util.first_component(eid, "ItemComponent", nil)
end

function M.isAlwaysCastSpellComponent(eid)
    return ComponentGetValue2(eid, "permanently_attached") or ComponentGetValue2(eid, "is_frozen")
end

function M.dropSpell(child, itemComp, x, y)
    if not itemComp then return end
    -- TODO consider doing stuff with always cast?
    if M.isAlwaysCastSpellComponent(itemComp) then return end
    EntityRemoveFromParent(child)
    EntitySetComponentsWithTagEnabled(child, "enabled_in_world", true)
    EntitySetTransform(child, x, y)
end

---Stolen from the legacy wand workshop. It's about all that's left of it.
---@param offer entity_id The offer being destroyed
---@param x number The x coord of the offer
---@param y number The y coord of the offer
function M.drop_spells(offer, x, y)
    local children = EntityGetAllChildren(offer) or {}
    for _, child in ipairs(children) do
        local itemSpell = M.childSpellItem(child)
        if itemSpell then M.dropSpell(child, itemSpell, x, y) end
    end
end

function M.target_of_altar(altar)
    local links = M.linked_item_array(altar)
    if #links > 0 then return links[1] end
    return nil
end

function M.force_updates(altar, eid)
    -- ALWAYS recalc after a severance.
    local upper_altar = M.get_upper_altar_near(altar)
    local lower_altar = M.get_lower_altar_near(altar)
    local target = M.target_of_altar(upper_altar)
    if target == nil then return false end
    M.refresh_result(eid, target.item, upper_altar, lower_altar, nil, M.is_wand, flask_util.is_flask)
end

---Handles the logic of determining an object is a valid altar target
---for the upper altar and linking it if possible.
---@param upper_altar entity_id The altar to target items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@param link_count integer the number of linked items on the altar, lets us create ids
---@return boolean is_new_link_formed whether the altar found a new link
function M.target_link_function(upper_altar, seen, link_count)
    if M.target_of_altar(upper_altar) ~= nil then return false end
    if not M.is_valid_target(seen.item) then return false end

    -- handle adding or removing item from the altar children
    local holder = M.make_holder(upper_altar, seen, link_count + 1)
    M.set_linked_item_behaviors(upper_altar, true, seen, holder)
    local lower_altar = M.get_lower_altar_near(upper_altar)
    M.refresh_result(seen.item, seen.item, upper_altar, lower_altar, holder, M.is_wand, flask_util.is_flask)
    return true
end

---Handles the logic of determining an object is a valid offering
---for the lower altar and linking it if possible.
---@param lower_altar entity_id The altar to sacrifice items with
---@param seen SeenItem an item or entity id in the altar's collision field
---@param linked_count integer the number of linked items on the altar, lets us create ids
---@return boolean is_new_link_formed whether the altar found a new link
function M.offer_link_function(lower_altar, seen, linked_count)
    local upper_altar = M.get_upper_altar_near(lower_altar)
    local target = M.target_of_altar(upper_altar)
    if target == nil then return false end
    if not M.is_valid_offer(target.item, seen.item) then return false end
    local holder = M.make_holder(lower_altar, seen, linked_count + 1)
    M.set_linked_item_behaviors(lower_altar, false, seen, holder)
    M.refresh_result(seen.item, target.item, upper_altar, lower_altar, holder, M.is_wand_offer, flask_util.is_flask_offer)
    return true
end

---Before-sever-function for offers, restores them to their vanilla state.
---@param altar entity_id The target altar restoring the item
---@param seenItem SeenItem The item id being restored
function M.offer_sever(altar, seenItem)
    -- NOOP
end

---Before-sever-function for targets, restores them to their vanilla state.
---@param upper_altar entity_id The target altar restoring the item
---@param seen SeenItem The item id being restored
function M.target_sever(upper_altar, seen)
    M.refresh_result(seen.item, seen.item, upper_altar, nil, nil, M.is_wand, flask_util.is_flask)
end

---Common logic of the various update procedures, refactors/deduplicates some calls
---@param item_triggering_update entity_id the item which triggered the update, possibly not the updating item
---@param item_to_update entity_id the item we're targeting
---@param upper_altar entity_id the upper altar id
---@param lower_altar entity_id|nil the lower altar id, passing nil will reset the target item
---@param holder entity_id|nil the holder we attached to represent an item, if applicable
---@param wand_id_function fun(eid: entity_id): boolean Function detecting that the wand side of the update should happen
---@param flask_id_function fun(eid: entity_id): boolean Function detecting that the flask side of the update should happen
function M.refresh_result(item_triggering_update, item_to_update,
                                         upper_altar, lower_altar, holder,
                                         wand_id_function, flask_id_function)
    if wand_id_function(item_triggering_update) then
        if holder then wand_util:store_wand_stats_in_holder(item_to_update, holder) end
        local combinedWands = wand_util:gather_altar_wand_stats_and_merge(upper_altar, lower_altar)
        wand_util:set_wand_result(item_to_update, combinedWands)
    elseif flask_id_function(item_triggering_update) then
        if holder then flask_util.store_flask_stats(item_to_update, holder) end
        local combinedFlasks = flask_util.merge_flask_stats(upper_altar, lower_altar)
        flask_util.set_flask_results(item_to_update, combinedFlasks)
    end
end

---If the x, y of a missing entity id matches a found one
---we naively assume that is the entity "from before".
---@param altar entity_id The altar of the item that was severed.
---@param missing entity_id The item that was severed
---@param relinkTo entity_id The item that is in the same x/y
---@return entity_id|nil hid The new holder Id the relink is tied to
function M.relink(altar, missing, relinkTo)
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local result = nil
    for _, hid in ipairs(holders) do
        if comp_util.get_int(hid, "eid") == missing then
            comp_util.removeMatch(hid, VSC, nil, "name", "eid")
            comp_util.store_int(hid, "eid", relinkTo)
            result = hid
            break
        end
    end
    -- if the item being relinked is the upper altar
    -- our objective is to *reset* the upper altar, not
    -- to regenerate the stats. It will have lost its originals.
    if M.get_upper_altar_near(altar) == altar then
        M.force_updates(altar, missing)
    end
    return result
end

---EntityKill DOES NOT kill the entity right away, so there's some cleanup
---of comps needed before an update is coerced.
---@param altar entity_id The altar of the item that was severed.
---@param eid entity_id The item that was severed
---@param is_pickup boolean Whether the item was flagged as picked up
function M.sever(altar, eid, is_pickup)
    -- if this is the upper altar
    local holders = EntityGetAllChildren(altar) or {}
    local hidToRemove = nil ---@type entity_id
    for _, hid in ipairs(holders) do
        if comp_util.get_int(hid, "eid") == eid then hidToRemove = hid end
    end
    if hidToRemove ~= 0 then
        comp_util.remove_all_comps(hidToRemove, VSC, nil)
        comp_util.remove_all_comps(hidToRemove, "AbilityComponent", nil)
        EntityKill(hidToRemove)
    end
    if is_pickup then return end
    local upperAltar = M.get_upper_altar_near(altar)
    local upperItems = #M.linked_item_array(upperAltar)
    if upperItems > 0 then
        M.force_updates(altar, eid)
    end
end

function M.destroy_used_offerings(target, altar)
    --logger.about("destroying offerings after picking up", target)
    local function is_destroying(offer)
        if M.is_wand(target) then return M.is_wand_offer(offer) end
        if flask_util.is_flask(target) then return flask_util.is_flask_offer(offer) end
        return false
    end
    local function destroy(offer)
        -- before destroying flasks, empty them
        if flask_util.is_flask(offer) then RemoveMaterialInventoryMaterial(offer) end
        -- before destroying wands, drop their spells
        local x, y = EntityGetTransform(offer)
        if M.is_wand(offer) then M.drop_spells(offer, x, y) end

        EntityLoad("data/entities/particles/destruction.xml", x, y)
        GamePlaySound("data/audio/Desktop/projectiles.bank", "magic/common_destroy", x, y)
        M.sever(altar, offer, true) -- isPickup stops the target from recalculating here

        -- sever kills the holder, but we still need to kill the actual offering
        EntityKill(offer)
    end
    for _, linkMap in ipairs(M.linked_item_array(altar)) do
        if is_destroying(linkMap.item) then destroy(linkMap.item) end
    end
end

---Create a holder entity sired by the altar, attached to the item
---it represents. This is used to attach components holding its stats.
---@param altar entity_id
---@param seen SeenItem
---@param innerId integer the number of items on the altar + 1, lets us create links explicitly
---@return entity_id
function M.make_holder(altar, seen, innerId)
    -- create a holder for the item and add it to the altar
    local e = EntityLoad("mods/offerings/entity/holder.xml", seen.x, seen.y)
    comp_util.store_int(e, "eid", seen.item)
    -- reverse lookup thing here, link them to the same id so they know about eachother through a
    -- persistent id. we can't rely on the entity_id but we can persist our own.
    comp_util.store_int(e, "innerId", innerId)
    comp_util.store_int(seen.item, "innerId", innerId)
    EntityAddChild(altar, e)
    return e
end

---Handle linking and unlinking items from an altar, setting and reversing various things.
---@param altar entity_id the altar linking or severing
---@param is_upper_altar boolean whether this is the upper (target) altar
---@param seen SeenItem the item being linked or severed
---@param hid entity_id|nil the holder item linked to the item, if one exists
function M.set_linked_item_behaviors(altar, is_upper_altar, seen, hid)
    local is_holder_linked = hid ~= nil
    M.toggle_altar_runes(altar, is_holder_linked)

    -- aesthetic stuff when linking the item to the altar, rotation mainly.
    if is_holder_linked then
        local x, y = EntityGetTransform(altar)
        local dx = is_upper_altar and x or seen.x
        local dy = y - 5 -- floaty
        local vertically_rotated = M.is_wand(seen.item) and -math.pi * 0.5 or 0.0
        EntitySetTransform(seen.item, dx, dy, vertically_rotated)
        -- ensure the item holder matches the item's new location
        seen.x = dx
        seen.y = dy
        if hid then EntitySetTransform(hid, dx, dy, vertically_rotated) end
        comp_util.each_component_set(seen.item, IC, nil, "spawn_pos", dx, dy)
    end

    -- make "first time pickup" fanfare when picking the item up
    comp_util.each_component_set(seen.item, IC, nil, "has_been_picked_by_player", not is_holder_linked)

    if M.is_wand(seen.item) then
        -- immobilize wands
        comp_util.each_component_set(seen.item, IC, nil, "play_hover_animation", not is_holder_linked)
        comp_util.each_component_set(seen.item, IC, nil, "play_spinning_animation", not is_holder_linked)
        comp_util.toggle_comps(seen.item, SPC, nil, not is_holder_linked)
    else
        comp_util.toggle_comps(seen.item, "VelocityComponent", nil, not is_holder_linked)
    end

    -- re-enables the first time pickup particles, which are fancy
    if is_upper_altar then
        local pickup = M.is_wand(seen.item) and wand_pickup_sript or flask_pickup_script
        if is_holder_linked and not comp_util.has_comp_match(seen.item, LC, nil, pickup_lua, pickup[pickup_lua]) then
            EntityAddComponent2(seen.item, LC, pickup)
        else
            comp_util.toggle_first_comp_matching(seen.item, LC, nil, pickup_lua, pickup[pickup_lua], is_holder_linked)
        end
    end

    -- enable particle emitters on linked items, these are the "new item" particles
    comp_util.each_component_set(seen.item, SPEC, nil, "velocity_always_away_from_center", is_holder_linked)
end

---Removes any existing links that have been severed by non-existence or removal.
---@param altar entity_id the altar doing the unlinking/severing
---@param missing_links SeenItem[] the existing links being checked, as a kvp map of item id to LinkMap
---@param linkables SeenItem[] the linkable indices being checked for severance, as an array
---@param on_pre_sever fun(altar: entity_id, seenItem: SeenItem) the function to perform before severing each item
---@return LinkMap[] relinkedItems the links restored by item location
function M.cull_or_relink_items(altar, missing_links, linkables, on_pre_sever)
    local relinks = {} ---@type table<SeenItem, SeenItem>
    local culls = {} ---@type SeenItem[]
    local results = {} ---@type LinkMap[]
    for _, missing_link in ipairs(missing_links) do
        -- figure out if the link can be restored from an item
        -- at the exact same x and y coordinates as the missing link
        for _, linkable in ipairs(linkables) do
            --logger.about("missing link", missingLink, "possible replacement", linkable)
            if missing_link.innerId == linkable.innerId then
                relinks[missing_link] = linkable
                break
            end
        end
        if relinks[missing_link] == nil then
            culls[#culls + 1] = missing_link
            break
        end
    end
    for missing, found in pairs(relinks) do
        --logger.about("relinking item", missing.item, "to item", found.item)
        local reHolder = M.relink(altar, missing.item, found.item)
        if reHolder then
            results[#results + 1] = { holder = reHolder, item = found.item, x = found.x, y = found.y }
        end
    end
    for _, cull in ipairs(culls) do
        --logger.about("severing missing item", cull.item)
        local is_upper_altar = M.is_upper_altar(altar)
        -- restore vanilla behaviors to now-not-linked item
        M.set_linked_item_behaviors(altar, is_upper_altar, cull, nil)
        if is_upper_altar and entity_util.is_item_in_player_inventory(cull.item) then
            M.destroy_used_offerings(cull.item, M.get_lower_altar_near(altar))
            M.sever(altar, cull.item, true)
        else
            on_pre_sever(altar, cull)
            M.sever(altar, cull.item, false)
        end
    end
    return results
end

---Handles the altar lifecycle "tick", getting linkable items and
---looking for severed connections, particles and other logic.
---@param altar entity_id the altar id running the scan
---@param is_upper_altar boolean whether the altar is the target altar
---@param link_function fun(altar: entity_id, eid: SeenItem, linkCount: integer): boolean the link function to use
---@param pre_sever_function fun(altar: entity_id, eid: SeenItem)
function M.do_altar_update_tick(altar, is_upper_altar, link_function, pre_sever_function)
    -- ignore altars that are far from the player.
    local x, y = EntityGetTransform(altar)

    -- floaty particle stuff and a light when player is near
    local is_player_near = #EntityGetInRadiusWithTag(x, y, 120, "player_unit") > 0
    comp_util.toggle_first_comp_matching(altar, PEC, nil, "gravity", { 0, -10 }, is_player_near)
    comp_util.toggle_comps(altar, "LightComponent", nil, is_player_near)
    local has_any_link = false
    if is_player_near then
        -- search for linkables, including already linked items
        -- we need all items because we are culling any items that aren't in range
        -- and already linked items don't want to be *culled*, just avoid linking >1 time.
        local linkables = M.get_linkable_items_near_altar(altar, is_upper_altar)
        local link_count, alreadyLinked = M.linked_item_map(altar)
        local missing_links = M.get_severed_links(linkables, alreadyLinked)
        local relinked_links = M.cull_or_relink_items(altar, missing_links, linkables, pre_sever_function)
        for _, linkmap in ipairs(relinked_links) do
            alreadyLinked[linkmap.item] = linkmap
        end
        for _, seen in ipairs(linkables) do
            if alreadyLinked[seen.item] == nil then
                has_any_link = link_function(altar, seen, link_count) or has_any_link
            else
                has_any_link = true
            end
        end
    end
    -- these lights ALSO turn off if the player goes away
    comp_util.toggle_first_comp_matching(altar, PEC, nil, "gravity", { 0, 0 }, has_any_link)
end

return M
