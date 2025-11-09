local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util

local IC = "ItemComponent"
local M = {} ---@class offering_entity_util

function M.has_word_in_name(eid, s)
    return comp_util.has_component_field_value_like(eid, IC, nil, "item_name", s)
end

function M.is_item_named(eid, name)
    return comp_util.has_component_of_type_with_field_equal(eid, IC, nil, "item_name", name)
end

function M.get_entity_name(eid)
    return
        EntityGetName(eid)
end

function M.is_entity_named(eid, s)
    return
        M.get_entity_name(eid) == s
end

function M.is_item_in_player_inventory(eid)
    return M.is_entity_named(EntityGetParent(eid), "inventory_quick")
end

function M.get_entity_with_tag_nearest_to_coordinates(tag, x, y)
    return EntityGetClosestWithTag(x, y, tag)
end

function M.get_entity_with_tag_nearest_to_entity(eid, tag)
    return M.get_entity_with_tag_nearest_to_coordinates(tag, EntityGetTransform(eid))
end

---Set the UI description of an item component (ui_description)
---to the description provided.
---@param eid entity_id
---@param description string
function M.setDescription(eid, description)
    if description == "" then return end
    local comp = comp_util.first_component(eid, IC, nil)
    comp_util.set_component_value(comp, "ui_description", description)
end

return M
