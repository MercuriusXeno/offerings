dofile_once("mods/offerings/lib/components.lua")
local thonk = dofile_once("mods/offerings/lib/thonk.lua") ---@type Thonk

thonk.about("draining lua firing")
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
function getDrainParams(d, dx, dy)
    local result = { heldItem = nil, space = 50, msc = nil, isActive = false} ---@type DrainParams
    local player = EntityGetClosestWithTag(dx, dy, "player_unit")
    if not player then return result end

    local inventory = firstComponent(player, "Inventory2Component")
    if not inventory then return result end

    result.heldItem = cGet(inventory, "mActiveItem")
    if not result.heldItem then return result end
    local enchantVsc = firstComponentMatching(result.heldItem, "VariableStorageComponent",
        nil, "name", "offering_flask_enchant_draining")
    if not enchantVsc then return result end

    local parentMsc = firstComponent(result.heldItem, "MaterialSuckerComponent", nil)
    if not parentMsc then return result end

    local barrel = cGet(parentMsc, "barrel_size")
    local amount = cGet(parentMsc, "mAmountUsed")
    result.space = barrel - amount
    result.msc = firstComponent(eid, "MaterialSuckerComponent", nil)
    if not result.msc then return result end

    result.isActive = true
    return result
end

local drainParams = getDrainParams(eid, x, y)
thonk.about("drain params", drainParams)
if not drainParams.isActive then return end
toggleComp(eid, drainParams.msc, drainParams.isActive)
cSet(drainParams.msc, "barrel_size", drainParams.space)
local mic = firstComponent(eid, "MaterialInventoryComponent", nil)
local parentMic = firstComponent(drainParams.heldItem, "MaterialInventoryComponent", nil)
local ourMaterials = cGet(mic, "count_per_material_type") ---@type table<integer, integer>
local parentMaterials = cGet(parentMic, "count_per_material_type") ---@type table<integer, integer>
for k, m in pairs(ourMaterials) do
    local matId = k - 1
    if m > 0 then
        local amount = m
        if parentMaterials[k] and parentMaterials[k] > 0 then
            amount = amount + parentMaterials[k]
        end
        local material = CellFactory_GetName(k - 1)
        thonk.about("transferring material", material, "amount", amount, "from", eid, "to", drainParams.heldItem)
        AddMaterialInventoryMaterial(drainParams.heldItem, material, amount)
        RemoveMaterialInventoryMaterial(eid, material)
    end
end
