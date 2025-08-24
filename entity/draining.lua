local comp_util = dofile_once("mods/offerings/lib/component_utils.lua")
local logger = dofile_once("mods/offerings/lib/log_utils.lua") ---@type offering_logger

logger.about("draining lua firing")
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
    local result = { heldItem = nil, space = 50, msc = nil, isActive = false} ---@type DrainParams
    local player = EntityGetClosestWithTag(dx, dy, "player_unit")
    if not player then return result end

    local inventory = comp_util.firstComponent(player, "Inventory2Component")
    if not inventory then return result end

    result.heldItem = comp_util.cGet(inventory, "mActiveItem")
    if not result.heldItem then return result end
    local enchantVsc = comp_util.firstComponentMatching(result.heldItem, "VariableStorageComponent",
        nil, "name", "offering_flask_enchant_draining")
    if not enchantVsc then return result end

    local parentMsc = comp_util.firstComponent(result.heldItem, "MaterialSuckerComponent", nil)
    if not parentMsc then return result end

    local barrel = comp_util.cGet(parentMsc, "barrel_size")
    local amount = comp_util.cGet(parentMsc, "mAmountUsed")
    result.space = barrel - amount
    result.msc = comp_util.firstComponent(eid, "MaterialSuckerComponent", nil)
    if not result.msc then return result end

    result.isActive = true
    return result
end

local drainParams = getDrainParams(eid, x, y)
logger.about("drain params", drainParams)
if not drainParams.isActive then return end
comp_util.toggleComp(eid, drainParams.msc, drainParams.isActive)
comp_util.cSet(drainParams.msc, "barrel_size", drainParams.space)
local mic = comp_util.firstComponent(eid, "MaterialInventoryComponent", nil)
local parentMic = comp_util.firstComponent(drainParams.heldItem, "MaterialInventoryComponent", nil)
local ourMaterials = comp_util.cGet(mic, "count_per_material_type") ---@type table<integer, integer>
local parentMaterials = comp_util.cGet(parentMic, "count_per_material_type") ---@type table<integer, integer>
for k, m in pairs(ourMaterials) do
    local matId = k - 1
    if m > 0 then
        local amount = m
        if parentMaterials[k] and parentMaterials[k] > 0 then
            amount = amount + parentMaterials[k]
        end
        local material = CellFactory_GetName(k - 1)
        logger.about("transferring material", material, "amount", amount, "from", eid, "to", drainParams.heldItem)
        AddMaterialInventoryMaterial(drainParams.heldItem, material, amount)
        RemoveMaterialInventoryMaterial(eid, material)
    end
end
