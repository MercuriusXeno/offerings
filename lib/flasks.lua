dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")

local enchantPrefix = "offering_flask_enchant_"
local flask_enchant_loc_prefix = "$" .. enchantPrefix

local VSC = "VariableStorageComponent"
local MIC = "MaterialInventoryComponent"
local MSC = "MaterialSuckerComponent"
local PBCDC = "PhysicsBodyCollisionDamageComponent"

local originalStats = "original_stats_"
local function unprefix(s, n) return s:sub(n + 1) end

local function prefOg(s) return originalStats .. s end
local OG = #prefOg("")
local function unprefOg(s) return unprefix(s, OG) end

local function prefMat(s) return prefOg("material_" .. s) end
local MAT = #prefMat("")
local function unprefMat(s) return unprefix(s, MAT) end

local function prefEnch(s) return prefOg("enchant_" .. s) end
local ENCH = #prefEnch("")
local function unprefEnch(s) return unprefix(s, ENCH) end

function flaskMaterials(eid) return isFlask(eid) and cGet(firstComponent(eid, MIC), "count_per_material_type") or {} end

-- list of enchantments of flasks and their detection item
local enchants = {}

function registerFlaskEnchantment(key, evaluators, max, apply, describe, antipode)
    enchants[key] = {
        {
            key = key,
            value = evaluators,
            max = max,
            apply = apply,
            describe = describe,
            negates = antipode
        }
    }
end

registerFlaskEnchantment("tempered", { brimstoneValue }, 1, removeDamageModels, describeTempered)
registerFlaskEnchantment("instant", { thunderstoneValue }, 1, makeInstant, describeInstant)
registerFlaskEnchantment("inert", { tabletValue }, 1, makeInert, describeInert, "reactive")
registerFlaskEnchantment("reactive", { scrollValue }, 4, makeReactive, describeReactive, "inert")
registerFlaskEnchantment("draining", { waterstoneValue }, 1, makeDraining, describeDraining)
registerFlaskEnchantment("transmuting", { potionMimicValue }, 1, makeTransmuting, describeTransmuting)


function hasAnyEnchantValue(eid)
    for _, enchant in ipairs(enchants) do if enchant.value(eid) > 0 then return true end end
    return false
end

function brimstoneValue(eid) return EntityHasTag(eid, "brimstone") and 1 or 0 end

function thunderstoneValue(eid) return EntityHasTag(eid, "thunderstone") and 1 or 0 end

function potionMimicValue(eid) return itemNamed(eid, "$item_potion_mimic") and 1 or 0 end

function waterstoneValue(eid) return EntityHasTag(eid, "waterstone") and 1 or 0 end

function removeDamageModels(eid) removeAny(eid, "DamageModelComponent") end

function makeInert(eid, level)
    eachComponentSet(eid, MIC, nil, "reaction_rate", level == 0 and 20 or 0)
end

function makeReactive(eid, level)
    eachComponentSet(eid, MIC, nil, "reaction_rate", math.min(20 + (level * 20), 100))
end

function makeTransmuting(eid, level)
    local key = enchantPrefix .. "transmuting"
    removeMatch(eid, VSC, nil, "name", key)
    storeInt(eid, key, level)
end

function makeInstant(eid)
    local barrel_size = valueOrDefault(eid, MSC, "barrel_size", 1000)
    local potionComp = firstComponent(eid, "PotionComponent")
    setValue(potionComp, "throw_bunch", true)
    setValue(potionComp, "throw_how_many", barrel_size)
end

function makeDraining(eid, level)
    local key = enchantPrefix .. "draining"
    removeMatch(eid, VSC, nil, "name", key)
    storeInt(eid, key, level)
end

function locKey(s) return flask_enchant_loc_prefix .. s end

function loc(s) return GameTextGet(locKey(s)) end

function default_enchant_loc(_, enchantment_key, _) return locKey(enchantment_key) end

describeInert = default_enchant_loc

describeTempered = default_enchant_loc

describeDraining = default_enchant_loc

describeInstant = default_enchant_loc

describeTransmuting = default_enchant_loc

function describeReactive(combined, key, level)
    return loc(key) .. " " .. level
        .. " " .. loc("reaction_chance") .. ": " .. reactionChance(combined)
        .. " " .. loc("reaction_speed") .. ": " .. reactionSpeed(combined)
end

function reactionChance(combined_stats)
    -- STUB
    return ""
end

function reactionSpeed(combined_stats)
    -- STUB
    return ""
end

function setFlaskReactivity(upperAltar, eid, lowerAltar)
    local reactivity = reactivity(upperAltar, lowerAltar)
    local comp = firstComponent(eid, MIC)
    cSet(comp, "do_reactions", reactivity.chance)
    cSet(comp, "reaction_speed", reactivity.speed)
end

function reactivity(upperAltar, lowerAltar)
    local combined = combineFlasks(upperAltar, lowerAltar)
    local base = 20
    local per = 20
    local level = 0

    local ench = combined.enchantments or {}
    -- inert subtracts, reactive adds
    level = level + (tonumber(ench.reactive) or 0)
    level = level - (tonumber(ench.inert) or 0)

    local cap = tonumber(combined.barrel_size) or 0
    local react_pixels_base = math.floor(cap / 200)

    local chance = math.min(100, math.max(0, base + per * level))
    local speed = level >= 0 and (react_pixels_base * (2 ^ level)) or react_pixels_base

    return { chance = chance, speed = speed }
end

--== FLASK MERGING ==--

function setFlaskDamageModelsAndPhysicsBodyDamage(upperAltar, eid, lowerAltar, isRestoringState)
    local isBreakable = isRestoringState and not enchantLevel(eid, "tempered") > 0
    eachComponentSet(eid, PBCDC, nil, "damage_multiplier", isBreakable and 0.016667 or 0.0)
end

function enchantLevel(eid, key)
    return cGet(firstComponentMatching(eid, VSC, nil, "name", enchantPrefix .. key), "value_int")
end

function storeFlaskStats(altar, eid)
    clearOriginalStats(altar)
    for matId, amount in pairs(flaskMaterials(eid)) do storeInt(altar, prefMat(matId), amount) end
    for key, _ in pairs(enchants) do storeInt(altar, prefEnch(key), enchantLevel(eid, key)) end
    local msc = firstComponent(eid, MSC)
    storeInt(altar, prefOg("num_cells_sucked_per_frame"), cGet(msc, "num_cells_sucked_per_frame"))
    storeInt(altar, prefOg("barrel_size"), cGet(msc, "barrel_size"))
    local potion = firstComponent(eid, "PotionComponent")
    storeFloat(altar, prefOg("spray_velocity_coeff"), cGet(potion, "spray_velocity_coeff"))
    storeFloat(altar, prefOg("spray_velocity_normalized_min"), cGet(potion, "spray_velocity_normalized_min"))
    storeInt(altar, prefOg("throw_how_many"), cGet(potion, "throw_how_many"))
end

function originalFlask(altar)
    return {
        materials = vscToKvp(storedIntsLike(altar, prefMat("")), "value_int", prefMat(""), unprefMat),
        enchantments = vscToKvp(storedIntsLike(altar, prefEnch("")), "value_int", prefEnch(""), unprefEnch),
        barrel_size = storedInt(altar, prefOg("barrel_size")),
        num_cells_sucked_per_frame = storedInt(altar, prefOg("num_cells_sucked_per_frame")),
        spray_velocity_coeff = storedFloat(altar, prefOg("spray_velocity_coeff")),
        spray_velocity_normalized_min = storedFloat(altar, prefOg("spray_velocity_normalized_min")),
        throw_how_many = storedInt(altar, prefOg("throw_how_many"))
    }
end

function combineFlasks(upperAltar, lowerAltar)
    local result = originalFlask(upperAltar)
    local offered = flaskEnhancers(lowerAltar)
    for _, offer in ipairs(offered) do
        if isFlask(offer) then
            for matId, amount in pairs(flaskMaterials(offer)) do
                result.materials[matId] = (result.materials[matId] or 0) + amount
            end
            local msc = firstComponent(offer, MSC)
            result.barrel_size = result.barrel_size + cGet(msc, "barrel_size")
            result.num_cells_sucked_per_frame = result.num_cells_sucked_per_frame + cGet(msc, "num_cells_sucked_per_frame")
            
            for key, _ in pairs(enchants) do
                local flask_enchant_level = enchantLevel(offer, key)
                if flask_enchant_level > 0 then
                    enchantment_map[key] = (enchantment_map[key] or 0) + flask_enchant_level
                end
            end

            local potion_comp = EntityGetFirstComponentIncludingDisabled(offer, "PotionComponent")
            if potion_comp then
                local spray_velocity_coeff = ComponentGetValue2(potion_comp, "spray_velocity_coeff")
                result.spray_velocity_coeff = Approach_Limit(result.spray_velocity_coeff,
                    spray_velocity_coeff, velocity_coeff_limit, velocity_limit_step_cap)

                local spray_velocity_normalized_min = ComponentGetValue2(potion_comp, "spray_velocity_normalized_min")
                result.spray_velocity_normalized_min = Approach_Limit(result.spray_velocity_normalized_min,
                    spray_velocity_normalized_min, velocity_norm_limit, velocity_limit_step_cap)
                local throw_how_many = ComponentGetValue2(potion_comp, "throw_how_many")
                result.throw_how_many = result.throw_how_many + throw_how_many
                if result.barrel_size > 10000 then
                    result.throw_how_many = math.floor(result.barrel_size ^ 0.75)
                end
            end
        end
    end

    -- Collapse material map to array
    for key, amount in pairs(materials) do
        result.materials[key] = amount
    end

    -- add enchantments from the items we've added on the altar.
    for key, def in pairs(enchants) do
        for _, item in ipairs(offeredEnhancers) do
            if def.value(item) > 0 then
                enchantment_map[key] = (enchantment_map[key] or 0) + def.value(item)
            end
        end
    end

    -- Negation pass: cancel out conflicting enchantments
    for key, enchantment_level in pairs(enchantment_map) do
        local def = enchants[key]
        local inverse = def and def.negates
        if inverse and enchantment_map[inverse] then
            local other = enchantment_map[inverse]
            local delta = enchantment_level - other

            if delta > 0 then
                enchantment_map[key] = delta
                enchantment_map[inverse] = nil
            elseif delta < 0 then
                enchantment_map[inverse] = -delta
                enchantment_map[key] = nil
            else
                enchantment_map[key] = nil
                enchantment_map[inverse] = nil
            end
        end
    end

    -- throttle the max level
    for key, _ in pairs(enchantment_map) do
        local def = enchants[key]
        enchantment_map[key] = math.min(def.max, enchantment_map[key] or 0)
    end

    -- Add enchantments, respecting max level
    for key, _ in pairs(enchantment_map) do
        result.enchantments[key] = enchantment_map[key] or 0
    end

    return result
end

---Using the combined stats of the item, create a description for the user
---to give them a better idea of the power of their flask.
---@param combined any
function Create_Description_From_Stats(combined)
    local result = ""
    for key, def in pairs(enchants) do
        if combined.enchantments[key] and combined.enchantments[key] > 0 then
            local enchant_desc = def.describe(combined, key, combined.enchantments[key])
            result = appendDescription(result, enchant_desc)
        end
    end
    if combined.barrel_size > 1000 then
        local barrel_size_description = GameTextGet(barrel_size_localization) .. ": " .. combined.barrel_size
        result = appendDescription(result, barrel_size_description)
    end
    if result ~= "" then debugOut("Description assigned to result item: " .. result) end
    return result
end

function Approach_Limit(result_stat, merge_stat, limit, step)
    if limit < result_stat then return limit end
    local step_max = (limit - result_stat) * step
    local actual_step = math.min(step_max, merge_stat)
    return math.min(limit, result_stat + actual_step)
end

function setFlaskResult(target, upperAltar, lowerAltar)
    local combined = combineFlasks(upperAltar, lowerAltar)
    local description = Create_Description_From_Stats(combined)
    setDescription(target, description)

    for key, level in pairs(combined.enchantments or {}) do enchants[key].apply(target, level) end

    local msc = firstComponent(target, MSC)
    cSet(msc, "barrel_size", combined.barrel_size)
    cSet(msc, "num_cells_sucked_per_frame", combined.num_cells_sucked_per_frame)

    local potion_comp = EntityGetFirstComponentIncludingDisabled(target, "PotionComponent")
    if potion_comp then
        ComponentSetValue2(potion_comp, "spray_velocity_coeff", combined.spray_velocity_coeff)
        ComponentSetValue2(potion_comp, "spray_velocity_normalized_min", combined.spray_velocity_normalized_min)
        ComponentSetValue2(potion_comp, "throw_how_many", combined.throw_how_many)
        -- this automatically sets to true because leaking gas with a HUGE flask is super slow
        ComponentSetValue2(potion_comp, "dont_spray_just_leak_gas_materials", false)
        -- this kicks in once flasks are bigger than 10k and it becomes a hassle to empty them
        if combined.barrel_size > 10000 then
            ComponentSetValue2(potion_comp, "throw_bunch", true)
        end
    end

    local mic = firstComponent(target, MIC)
    -- ONLY FOR THE TARGET TEMPORARILY PART 1
    -- render the flask inert temporarily because this is a bad time to do accident alchemy
    ComponentSetValue2(mic, "do_reactions", 0)
    ComponentSetValue2(mic, "reaction_speed", 0)

    -- ONLY FOR THE TARGET TEMPORARILY PART 2
    -- make the flask immune to physics damage and other damage, is_static makes it shatter
    local phys_comps = EntityGetComponentIncludingDisabled(target, "PhysicsBodyCollisionDamageComponent") or {}
    for _, phys_comp in ipairs(phys_comps) do
        -- default is 0.016667 , set it to 0
        ComponentSetValue2(phys_comp, "damage_multiplier", 0.0)
    end
    local damage_comps = EntityGetComponentIncludingDisabled(target, "DamageModelComponent") or {}
    for _, damage_comp in ipairs(damage_comps) do
        EntitySetComponentIsEnabled(target, damage_comp, false)
    end

    -- this removes all material from the flask by design (empty material_name does it)
    RemoveMaterialInventoryMaterial(target)

    debugOut("building flask from reserved/combined state:")
    -- Add new materials
    for mat_id, amount in pairs(combined.materials or {}) do
        local material_type = CellFactory_GetName(mat_id)
        AddMaterialInventoryMaterial(target, material_type, amount)
    end
end
