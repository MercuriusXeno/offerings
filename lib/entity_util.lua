local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util

local M = {} ---@class offering_entity_util

function M.itemNameContains(eid, s) return comp_util.hasCompLike(eid, "ItemComponent", nil, "item_name", s) end

function M.itemNamed(eid, name) return comp_util.has_comp_match(eid, "ItemComponent", nil, "item_name", name) end

function M.entityName(eid) return EntityGetName(eid) end

function M.isEntityNamed(eid, s) return M.entityName(eid) == s end

function M.is_item_in_player_inventory(eid) return M.isEntityNamed(EntityGetParent(eid), "inventory_quick") end

function M.closest(tag, x, y) return EntityGetClosestWithTag(x, y, tag) end

function M.get_nearest_entity_with_tag(eid, tag) return M.closest(tag, EntityGetTransform(eid)) end

---Set the UI description of an item component (ui_description)
---to the description provided.
---@param eid entity_id
---@param description string
function M.setDescription(eid, description)
    if description == "" then return end
    local comp = comp_util.first_component(eid, "ItemComponent", nil)
    comp_util.component_set(comp, "ui_description", description)
end

return M