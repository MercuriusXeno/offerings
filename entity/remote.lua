local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util

local remote_entity_id = GetUpdatedEntityID()
local x, y = DEBUG_GetMouseWorld()
EntitySetTransform(remote_entity_id, x, y)

---@class DrainParams
---@field heldItem entity_id|nil
---@field space integer
---@field msc component_id|nil
---@field isActive boolean

---Get the parameters of the drain that are available at this frame.
---@param remote_entity_id entity_id the entity doing remote things, following the mouse around
---@param dx number the x coord of the mouse
---@param dy number the y coord of the mouse
---@return DrainParams
local function getDrainParams(remote_entity_id, dx, dy)
    ---@type DrainParams
    local result =
    {
        heldItem = nil,
        space = 50,
        msc = comp_util.first_component(remote_entity_id, "MaterialSuckerComponent", nil),
        isActive = false
    }
    if not result.msc then return result end

    local player = EntityGetClosestWithTag(dx, dy, "player_unit")
    if not player then return result end

    local inventory = comp_util.first_component(player, "Inventory2Component")
    if not inventory then return result end

    result.heldItem = comp_util.get_component_value(inventory, "mActiveItem")
    if not result.heldItem or result.heldItem ~= EntityGetParent(remote_entity_id) then return result end

    local parentMsc = comp_util.first_component(result.heldItem, "MaterialSuckerComponent", nil)
    if not parentMsc then return result end

    local barrel = comp_util.get_component_value(parentMsc, "barrel_size")
    local amount = comp_util.get_component_value(parentMsc, "mAmountUsed")
    result.space = barrel - amount

    result.isActive = true
    return result
end

local function do_drain_action()
    local drainParams = getDrainParams(remote_entity_id, x, y)
    comp_util.toggle_component(remote_entity_id, drainParams.msc, drainParams.isActive)
    -- don't do anything else, just turn the comp off and exit.
    if not drainParams.isActive then return end
    comp_util.set_component_value(drainParams.msc, "barrel_size", drainParams.space)
    local mic = comp_util.first_component(remote_entity_id, "MaterialInventoryComponent", nil)
    local parentMic = comp_util.first_component(drainParams.heldItem, "MaterialInventoryComponent", nil)
    local ourMaterials = comp_util.get_component_value(mic, "count_per_material_type") ---@type table<integer, integer>
    local parentMaterials = comp_util.get_component_value(parentMic, "count_per_material_type") ---@type table<integer, integer>
    for raw_material_id, amount in pairs(ourMaterials) do
        local material_id = raw_material_id - 1
        if amount > 0 then
            -- if there's already some material of this type in the container we have to collate it
            -- or we'll erase it in the AddMaterial method, which doesn't actually *add* material lol
            if parentMaterials[raw_material_id] and parentMaterials[raw_material_id] > 0 then
                amount = amount + parentMaterials[raw_material_id]
            end
            -- this is the transfer mechanism between the remote container and the real one.
            local material = CellFactory_GetName(material_id)
            AddMaterialInventoryMaterial(drainParams.heldItem, material, amount)
            RemoveMaterialInventoryMaterial(remote_entity_id, material)
        end
    end
end

do_drain_action()
