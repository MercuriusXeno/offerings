dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/components.lua")

local flask_enchant_prefix = "offering_flask_enchant_"
local flask_enchant_loc_prefix = "$" .. flask_enchant_prefix
local VSC = "VariableStorageComponent"
local MIC = "MaterialInventoryComponent"
local MSC = "MaterialSuckerComponent"


function flaskMaterials(eid) return isFlask(eid) and cGet(firstComponent(eid, MIC), "count_per_material_type") or {} end

-- list of enchantments of flasks and their detection item
local enchants = {
    tempered = { value = brimstoneValue, max = 1, apply = removeDamageModels, describe = describeTempered },
    instant = { value = thunderstoneValue, max = 1, apply = makeInstant, describe = describeInstant },
    inert = { value = tabletValue, max = 1, apply = makeInert, negates = "reactive", describe = describeInert },
    reactive = { value = scrollValue, max = 4, apply = makeReactive, negates = "inert", describe = describeReactive },
    draining = { value = waterstoneValue, max = 1, apply = makeDraining, describe = describeDraining },
    transmuting = { value = potionMimicValue, max = 1, apply = makeTransmuting, describe = describeTransmuting }
}

function hasAnyEnchantValue(eid)
    for _, ench in ipairs(enchants) do if ench.value(eid) > 0 then return true end end
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

--- Increase reaction rate from 20 to 100 in 5 steps (Reactive I-V)
function makeReactive(eid, level)
    eachComponentSet(eid, MIC, nil, "reaction_rate", math.min(20 + (level * 20), 100))
end

function makeTransmuting(eid, level)
    local key = flask_enchant_prefix .. "transmuting"

    -- Remove any existing component with this key
    removeMatch(eid, VSC, nil, "name", key)

    -- Add new component with level set
    storeInt(eid, key, level)
end

function makeInstant(eid)
    local capacity = valueOrDefault(eid, MSC, "barrel_size", 1000)
    local potionComp = firstComponent(eid, "PotionComponent")
    setValue(potionComp, "throw_bunch", true)
    setValue(potionComp, "throw_how_many", capacity)
end

function makeDraining(eid, level)
    local key = flask_enchant_prefix .. "draining"
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

---Used to set the flask to reactive after being inert while on the target pedestal.
---This is mostly to stop the flask from reacting prematurely, but it can react as soon
---as it is lifted from the altar, so this may not help much.
---@param target_flask_id any
---@param target_altar_id any
---@param offer_altar_id any
function setFlaskReactivity(target_altar_id, target_flask_id, offer_altar_id)
    local combined = combinedFlasks(target_altar_id, offer_altar_id)
    local reactivity = Get_Reactivity_Stats(combined)
    local comp = EntityGetFirstComponentIncludingDisabled(target_flask_id, "MaterialInventoryComponent")
    if reactivity and comp then
        debugOut("Reactivity " .. reactivity.chance .. " and speed " .. reactivity.speed)
        ComponentSetValue2(comp, "do_reactions", reactivity.chance)
        ComponentSetValue2(comp, "reaction_speed", reactivity.speed)
    end
end

---Returns the reactivity stats based on the combined stats of the flask being output
---Used to fix the reactivity of the flask at the last possible moment, prior to which it is inert.
---Also used to get the reactivity stats for display on the item description.
---@param combined_stats table
---@return table
function Get_Reactivity_Stats(combined_stats)
    local base = 20
    local per = 20
    local level = 0

    local ench = combined_stats.enchantments or {}
    -- inert subtracts, reactive adds
    level = level + (tonumber(ench.reactive) or 0)
    level = level - (tonumber(ench.inert) or 0)

    local cap = tonumber(combined_stats.capacity) or 0
    local react_pixels_base = math.floor(cap / 200)

    local chance = math.min(100, math.max(0, base + per * level))
    local speed = level >= 0 and (react_pixels_base * (2 ^ level)) or react_pixels_base

    return { chance = chance, speed = speed }
end

--== FLASK MERGING ==--

function setFlaskDamageModelsAndPhysicsBodyDamage(target_altar_id, target_flask_id, offer_altar_id)
    local combined = combinedFlasks(target_altar_id, offer_altar_id)
    -- tempered *leaves* the effect in play.
    if Get_Level_Of_Flask_Enchantment(target_flask_id, "tempered") > 0 then return end

    local phys_comps = EntityGetComponentIncludingDisabled(target_flask_id, "PhysicsBodyCollisionDamageComponent") or {}
    for _, phys_comp in ipairs(phys_comps) do
        -- default is 0.016667
        ComponentSetValue2(phys_comp, "damage_multiplier", 0.016667)
    end
end

---Check whether a flask has a specific enchantment.
---@param flask_id integer
---@param enchantment_key string
---@return number
function Get_Level_Of_Flask_Enchantment(flask_id, enchantment_key)
    local key = flask_enchant_prefix .. enchantment_key
    local comps = EntityGetComponentIncludingDisabled(flask_id, "VariableStorageComponent") or {}

    for _, comp in ipairs(comps) do
        if ComponentGetValue2(comp, "name") == key then
            return ComponentGetValue2(comp, "value_int")
        end
    end

    return 0
end

--- Reserve the current flask state (materials, enchantments) on the altar
---@param altar_id integer
---@param flask_id integer
function storeFlaskStats(altar_id, flask_id)
    -- clear old reservation
    clearOriginalStats(altar_id)

    -- reserve material contents
    local materials = flaskMaterials(flask_id)
    for mat_id, amount in pairs(materials) do
        EntityAddComponent2(altar_id, "VariableStorageComponent", {
            name = "reserved_material_" .. mat_id,
            value_string = mat_id,
            value_int = amount,
            _tags = target_stat_buffer
        })
    end

    -- reserve enchantments (and their levels)
    for key, _ in pairs(flask_enchantments) do
        local level = Get_Level_Of_Flask_Enchantment(flask_id, key)
        if level > 0 then
            EntityAddComponent2(altar_id, "VariableStorageComponent", {
                name = "reserved_enchant_" .. key,
                value_int = level,
                _tags = target_stat_buffer
            })
        end
    end

    -- reserve capacity of original
    local sucker_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent")
    if sucker_comp then
        local capacity = ComponentGetValue2(sucker_comp, "barrel_size")
        local fill_rate = ComponentGetValue2(sucker_comp, "num_cells_sucked_per_frame")
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_capacity", value_int = capacity, _tags = target_stat_buffer })
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_fill_rate", value_int = fill_rate, _tags = target_stat_buffer })
    end

    local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent")
    if potion_comp then
        local spray_velocity_coeff = ComponentGetValue2(potion_comp, "spray_velocity_coeff")
        local spray_velocity_norm = ComponentGetValue2(potion_comp, "spray_velocity_normalized_min")
        local throw_how_many = ComponentGetValue2(potion_comp, "throw_how_many")
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_spray_velocity_coeff", value_int = spray_velocity_coeff, _tags = target_stat_buffer })
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_spray_velocity_norm", value_int = spray_velocity_norm, _tags = target_stat_buffer })
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_throw_how_many", value_int = throw_how_many, _tags = target_stat_buffer })
    end
end

--- Retrieve reserved flask state from the target altar
---@param altar_id integer
---@return table state { materials: {name, amount}, enchantments: {name, level}, capacity: integer }
function Get_Reserved_Flask_State(altar_id)
    local comps = EntityGetComponentIncludingDisabled(altar_id, "VariableStorageComponent") or {}
    local materials = {}
    local enchantments = {}
    local capacity = 0
    local fill_rate = 0
    local spray_velocity_coeff = 0
    local spray_velocity_norm = 0
    local throw_how_many = 0
    for _, comp in ipairs(comps) do
        if ComponentHasTag(comp, target_stat_buffer) then
            local name = ComponentGetValue2(comp, "name")
            if string.sub(name, 1, 18) == "reserved_material_" then
                local mat_id = tonumber(ComponentGetValue2(comp, "value_string")) or 0
                local amount = ComponentGetValue2(comp, "value_int")
                materials[mat_id] = amount
            elseif string.sub(name, 1, 17) == "reserved_enchant_" then
                local key = string.sub(name, 18)
                local level = ComponentGetValue2(comp, "value_int")
                enchantments[key] = level
            elseif name == "reserved_capacity" then
                capacity = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_fill_rate" then
                fill_rate = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_spray_velocity_coeff" then
                spray_velocity_coeff = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_spray_velocity_norm" then
                spray_velocity_norm = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_throw_how_many" then
                throw_how_many = ComponentGetValue2(comp, "value_int")
            end
        end
    end

    return {
        materials = materials,
        enchantments = enchantments,
        capacity = capacity,
        fill_rate = fill_rate,
        spray_velocity_coeff = spray_velocity_coeff,
        spray_velocity_norm = spray_velocity_norm,
        throw_how_many = throw_how_many
    }
end

---Get and humanely display the combined stats of the result wand for debugging.
---@param target_altar_id any
---@param offer_altar_id any
function printFlaskStats(target_altar_id, offer_altar_id)
    local combined_stats = combinedFlasks(target_altar_id, offer_altar_id)
    debugOut("Taking potion:")
    for key, stat in pairs(combined_stats) do
        if type(stat) == "table" then
            debugOut(key .. " ")
            for inner_key, item in pairs(stat) do
                local name = key == "materials" and CellFactory_GetName(inner_key) or inner_key
                debugOut(name .. " " .. tostring(item))
            end
        elseif type(stat) == "number" then
            debugOut(key .. " " .. tostring(stat))
        end
    end
end

---Combine reserved flask state with enchantment effects and merged flask contents.
---@param reserved table original attributes of the target flask
---@param offer_flasks integer[] the ids of the flasks being offered on the altar
---@return table { materials<mat_id,amount>, enchantments<key,level>, capacity, fill_rate,
---@    spray_velocity_coeff, spray_velocity_norm, throw_how_many}
function Combine_Flask_State(reserved, offer_flasks, offer_enhancers)
    local result = {
        materials = {},
        enchantments = {},
        capacity = reserved.capacity or 0,
        fill_rate = reserved.fill_rate or 0,
        spray_velocity_coeff = reserved.spray_velocity_coeff or 0,
        spray_velocity_norm = reserved.spray_velocity_norm or 0,
        throw_how_many = reserved.throw_how_many or 0
    }

    -- Clone reserved materials and enchantments
    local material_map = {}
    for mat_id, mat in pairs(reserved.materials or {}) do
        material_map[mat_id] = (material_map[mat_id] or 0) + mat
    end
    local enchantment_map = {}
    for key, level in pairs(reserved.enchantments or {}) do
        enchantment_map[key] = (enchantment_map[key] or 0) + level
    end

    -- combine offered flasks contents capacity and enchantments
    -- note we do not yet perform negations or limits. Total only.
    for _, flask_id in ipairs(offer_flasks) do
        -- merge contents
        local mat_list = flaskMaterials(flask_id)

        for mat_id, mat in pairs(mat_list) do
            material_map[mat_id] = (material_map[mat_id] or 0) + mat
        end

        -- merge capacities and fill rates
        local suck_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent")
        if suck_comp then
            local merged_capacity = ComponentGetValue2(suck_comp, "barrel_size")
            result.capacity = result.capacity + merged_capacity
            local merged_fill_rate = ComponentGetValue2(suck_comp, "num_cells_sucked_per_frame")
            result.fill_rate = result.fill_rate + merged_fill_rate
        end

        -- merge enchants,
        for key, _ in pairs(flask_enchantments) do
            local flask_enchant_level = Get_Level_Of_Flask_Enchantment(flask_id, key)
            if flask_enchant_level > 0 then
                enchantment_map[key] = (enchantment_map[key] or 0) + flask_enchant_level
            end
        end

        local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent")
        if potion_comp then
            local spray_velocity_coeff = ComponentGetValue2(potion_comp, "spray_velocity_coeff")
            result.spray_velocity_coeff = Approach_Limit(result.spray_velocity_coeff,
                spray_velocity_coeff, velocity_coeff_limit, velocity_limit_step_cap)

            local spray_velocity_norm = ComponentGetValue2(potion_comp, "spray_velocity_normalized_min")
            result.spray_velocity_norm = Approach_Limit(result.spray_velocity_norm,
                spray_velocity_norm, velocity_norm_limit, velocity_limit_step_cap)
            local throw_how_many = ComponentGetValue2(potion_comp, "throw_how_many")
            result.throw_how_many = result.throw_how_many + throw_how_many
            -- at 10k capacity it gets progressively harder to empty flasks and this formula changes
            if result.capacity > 10000 then
                result.throw_how_many = math.floor(reserved.capacity ^ 0.75)
            end
        end
    end

    -- Collapse material map to array
    for key, amount in pairs(material_map) do
        result.materials[key] = amount
    end

    -- add enchantments from the items we've added on the altar.
    for key, def in pairs(flask_enchantments) do
        for _, item in ipairs(offer_enhancers) do
            if def.value(item) > 0 then
                enchantment_map[key] = (enchantment_map[key] or 0) + def.value(item)
            end
        end
    end

    -- Negation pass: cancel out conflicting enchantments
    for key, enchantment_level in pairs(enchantment_map) do
        local def = flask_enchantments[key]
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
        local def = flask_enchantments[key]
        enchantment_map[key] = math.min(def.max, enchantment_map[key] or 0)
    end

    -- Add enchantments, respecting max level
    for key, _ in pairs(enchantment_map) do
        result.enchantments[key] = enchantment_map[key] or 0
    end

    return result
end

function Approach_Limit(result_stat, merge_stat, limit, step)
    if limit < result_stat then return limit end
    local step_max = (limit - result_stat) * step
    local actual_step = math.min(step_max, merge_stat)
    return math.min(limit, result_stat + actual_step)
end

---Apply the combined flask state to the given flask entity.
---@param flask_id integer
---@param combined table
function Apply_Flask_State(flask_id, combined)
    local comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialInventoryComponent")
    if not comp then return end
    debugOut("Applying combined state to flask on the target altar for updates")
    -- Apply enchantments
    for key, level in pairs(combined.enchantments or {}) do
        local enchant = flask_enchantments[key]
        debugOut("Enchant " .. key .. " " .. level)
        if enchant and enchant.apply then enchant.apply(flask_id, level) end
    end

    -- Set combined capacity, warning, it's on a different component
    local sucker_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent")
    if sucker_comp then
        ComponentSetValue2(sucker_comp, "barrel_size", combined.capacity)
        ComponentSetValue2(sucker_comp, "num_cells_sucked_per_frame", combined.fill_rate)
    end

    -- Set combined capacity, warning, it's on a different component
    local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent")
    if potion_comp then
        ComponentSetValue2(potion_comp, "spray_velocity_coeff", combined.spray_velocity_coeff)
        ComponentSetValue2(potion_comp, "spray_velocity_normalized_min", combined.spray_velocity_norm)
        ComponentSetValue2(potion_comp, "throw_how_many", combined.throw_how_many)
        -- this automatically sets to true because leaking gas with a HUGE flask is super slow
        ComponentSetValue2(potion_comp, "dont_spray_just_leak_gas_materials", false)
        -- this kicks in once flasks are bigger than 10k and it becomes a hassle to empty them
        if combined.capacity > 10000 then
            ComponentSetValue2(potion_comp, "throw_bunch", true)
        end
    end

    -- ONLY FOR THE TARGET TEMPORARILY PART 1
    -- render the flask inert temporarily because this is a bad time to do accident alchemy
    ComponentSetValue2(comp, "do_reactions", 0)
    ComponentSetValue2(comp, "reaction_speed", 0)

    -- ONLY FOR THE TARGET TEMPORARILY PART 2
    -- make the flask immune to physics damage and other damage, is_static makes it shatter
    local phys_comps = EntityGetComponentIncludingDisabled(flask_id, "PhysicsBodyCollisionDamageComponent") or {}
    for _, phys_comp in ipairs(phys_comps) do
        -- default is 0.016667 , set it to 0
        ComponentSetValue2(phys_comp, "damage_multiplier", 0.0)
    end
    local damage_comps = EntityGetComponentIncludingDisabled(flask_id, "DamageModelComponent") or {}
    for _, damage_comp in ipairs(damage_comps) do
        EntitySetComponentIsEnabled(flask_id, damage_comp, false)
    end

    -- this removes all material from the flask by design (empty material_name does it)
    RemoveMaterialInventoryMaterial(flask_id)

    debugOut("building flask from reserved/combined state:")
    -- Add new materials
    for mat_id, amount in pairs(combined.materials or {}) do
        local material_type = CellFactory_GetName(mat_id)
        debugOut("Material: " .. material_type .. " x" .. amount)
        AddMaterialInventoryMaterial(flask_id, material_type, amount)
    end
end

---@param target_flask_id integer
---@param target_altar_id integer
---@param offer_altar_id integer
function Calculate_Flask_Stats(target_flask_id, target_altar_id, offer_altar_id)
    local combined_stats = combinedFlasks(target_altar_id, offer_altar_id)
    local description = Create_Description_From_Stats(combined_stats)
    Set_Custom_Description(target_flask_id, description)
    Apply_Flask_State(target_flask_id, combined_stats)
end

---Return the combined stats of flasks and offered flasks, and enhancers.
---@param target_altar_id any
---@param offer_altar_id any
---@return table
function combinedFlasks(target_altar_id, offer_altar_id)
    local reserved = Get_Reserved_Flask_State(target_altar_id)
    local offer_flasks = flasks(offer_altar_id)
    local offer_enhancers = flaskEnhancers(offer_altar_id)
    return Combine_Flask_State(reserved, offer_flasks, offer_enhancers)
end

---Using the combined stats of the item, create a description for the user
---to give them a better idea of the power of their flask.
---@param combined any
function Create_Description_From_Stats(combined)
    local result = ""
    for key, def in pairs(flask_enchantments) do
        if combined.enchantments[key] and combined.enchantments[key] > 0 then
            local enchant_desc = def.describe(combined, key, combined.enchantments[key])
            result = Append_Description_Line(result, enchant_desc)
        end
    end
    if combined.capacity > 1000 then
        local capacity_description = GameTextGet(barrel_size_localization) .. ": " .. combined.capacity
        result = Append_Description_Line(result, capacity_description)
    end
    if result ~= "" then debugOut("Description assigned to result item: " .. result) end
    return result
end
