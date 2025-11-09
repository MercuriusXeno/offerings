local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util

--logger.about("draining lua firing")
local eid = GetUpdatedEntityID()
local x, y = DEBUG_GetMouseWorld()
EntitySetTransform(eid, x, y)

---@class DrainParams
---@field heldItem entity_id|nil
---@field space integer
---@field msc component_id|nil
---@field isActive boolean

---Get the parameters of the drain that are available at this frame.
---@param d entity_id the entity draining, following the mouse around
---@param dx number the x coord of the drain
---@param dy number the y coord of the drain
---@return DrainParams
local function getDrainParams(d, dx, dy)
     ---@type DrainParams
    local result =
    {
        heldItem = nil,
        space = 50,
        msc = comp_util.first_component(d, "MaterialSuckerComponent", nil),
        isActive = false
    }
    if not result.msc then return result end

    local player = EntityGetClosestWithTag(dx, dy, "player_unit")
    if not player then return result end

    local inventory = comp_util.first_component(player, "Inventory2Component")
    if not inventory then return result end

    result.heldItem = comp_util.component_get(inventory, "mActiveItem")
    if not result.heldItem then return result end
    local enchantVsc = comp_util.firstComponentMatching(result.heldItem, "VariableStorageComponent",
        nil, "name", "offering_flask_enchant_draining")
    if not enchantVsc or comp_util.get_int(result.heldItem, "offering_flask_enchant_draining") == 0 then return result end

    local parentMsc = comp_util.first_component(result.heldItem, "MaterialSuckerComponent", nil)
    if not parentMsc then return result end

    local barrel = comp_util.component_get(parentMsc, "barrel_size")
    local amount = comp_util.component_get(parentMsc, "mAmountUsed")
    result.space = barrel - amount

    result.isActive = true
    return result
end

local drainParams = getDrainParams(eid, x, y)
--logger.about("drain params", drainParams)
comp_util.toggleComp(eid, drainParams.msc, drainParams.isActive)
-- don't do anything else, just turn the comp off and exit.
if not drainParams.isActive then return end
comp_util.component_set(drainParams.msc, "barrel_size", drainParams.space)
local mic = comp_util.first_component(eid, "MaterialInventoryComponent", nil)
local parentMic = comp_util.first_component(drainParams.heldItem, "MaterialInventoryComponent", nil)
local ourMaterials = comp_util.component_get(mic, "count_per_material_type") ---@type table<integer, integer>
local parentMaterials = comp_util.component_get(parentMic, "count_per_material_type") ---@type table<integer, integer>
for k, m in pairs(ourMaterials) do
    local matId = k - 1
    if m > 0 then
        local amount = m
        if parentMaterials[k] and parentMaterials[k] > 0 then
            amount = amount + parentMaterials[k]
        end
        local material = CellFactory_GetName(matId)
        --logger.about("transferring material", material, "amount", amount, "from", eid, "to", drainParams.heldItem)
        AddMaterialInventoryMaterial(drainParams.heldItem, material, amount)
        RemoveMaterialInventoryMaterial(eid, material)
    end
end
