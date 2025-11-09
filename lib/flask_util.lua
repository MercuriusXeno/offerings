local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util
local entity_util = dofile_once("mods/offerings/lib/entity_util.lua") ---@type offering_entity_util
local util = dofile_once("mods/offerings/lib/util.lua") ---@type offering_util

local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util

local enchantPrefix = "offering_flask_enchant_"
local flask_enchant_loc_prefix = "$" .. enchantPrefix

local VSC = "VariableStorageComponent"
local MIC = "MaterialInventoryComponent"
local MSC = "MaterialSuckerComponent"
local PBCDC = "PhysicsBodyCollisionDamageComponent"
local DMC = "DamageModelComponent"
local PISC = "PhysicsImageShapeComponent"

local LOCALIZE_PREFIX = "$offering_flask_"
local LOCALIZE_BARREL_SIZE = LOCALIZE_PREFIX .. "barrel_size"
local ORIGINAL_STATS_PREFIX = "original_stats_"
local function unprefix(s, n) return s:sub(n + 1) end

local function prefix_base(s) return ORIGINAL_STATS_PREFIX .. s end

local function prefix_material(s) return prefix_base("material_" .. s) end
local MATERIAL_PREFIX_LENGTH = #prefix_material("")
local function unprefix_material(s) return unprefix(s, MATERIAL_PREFIX_LENGTH) end

local function prefix_enchantment(s) return prefix_base("enchant_" .. s) end
local ENCHANT_PREFIX_LENGTH = #prefix_enchantment("")
local function unprefix_enchantment(s) return unprefix(s, ENCHANT_PREFIX_LENGTH) end

local DRAINING_XML = "mods/offerings/entity/draining.xml"

---@class flask_stat_definition
---@field key string
---@field formula string

local FLASK_STAT_DEFINITIONS = {
    { key = "enchantments",                  formula = "group_sum" },
    { key = "barrel_size",                   formula = "sum" },
    { key = "num_cells_sucked_per_frame",    formula = "sum" },
    { key = "spray_velocity_coeff",          formula = "clamp_blend" },
    { key = "spray_velocity_normalized_min", formula = "clamp_blend" },
    { key = "throw_how_many",                formula = "sum" },
    { key = "materials",                     formula = "group_sum" }
} ---@type flask_stat_definition

---@class flask_stats
---@field enchantments table<string, integer>
---@field barrel_size integer[]
---@field num_cells_sucked_per_frame integer[]
---@field spray_velocity_coeff number[]
---@field spray_velocity_normalized_min number[]
---@field throw_how_many integer[]
---@field materials table<integer, integer>

-- list of enchantments of flasks and their detection item
---@class flask_enchant_definition
---@field key string
---@field evaluators (fun(eid: entity_id):integer)[]
---@field min integer
---@field max integer
---@field apply fun(eid: entity_id, level: integer)
---@field describe fun(stats: flask_stats, key: string, level: integer): string

local M = {} ---@class offering_flask_util

function M.is_flask(eid) return EntityHasTag(eid, "potion") or entity_util.is_item_named(eid, "$item_cocktail") end

---Scrape the level of enchantment an item gives by looping over a def's evaluators
---@param def flask_enchant_definition
---@param eid entity_id
---@return integer
function M.get_item_enchantment_value(def, eid)
    local r = 0
    for _, f in ipairs(def.evaluators) do r = r + f(eid) end
    return r
end

function M.get_tablet_value(eid)
    local value = 0
    if EntityHasTag(eid, "normal_tablet") then value = -1 end
    if EntityHasTag(eid, "forged_tablet") then value = -5 end
    return value
end

function M.get_scroll_value(eid)
    local value = 0
    if EntityHasTag(eid, "scroll") then value = 1 end
    if entity_util.has_word_in_name(eid, "book_s_") then value = 5 end
    return value
end

function M.get_brimstone_value(eid) return EntityHasTag(eid, "brimstone") and 1 or 0 end

function M.get_thunderstone_value(eid) return EntityHasTag(eid, "thunderstone") and 1 or 0 end

function M.get_waterstone_value(eid) return EntityHasTag(eid, "waterstone") and 1 or 0 end

function M.get_potion_mimic_value(eid) return entity_util.is_item_named(eid, "$item_potion_mimic") and 1 or 0 end

function M.get_long_distance_cast_value(eid)
    local itemActionComp = comp_util.first_component(eid, "ItemActionComponent", nil)
    if not itemActionComp then return 0 end
    local actionId = comp_util.get_component_value(itemActionComp, "action_id")
    return actionId == "LONG_DISTANCE_CAST" and 1 or 0
end

function M.set_enchant_level(eid, key, level)
    local fullkey = enchantPrefix .. key
    comp_util.remove_components_of_type_with_field(eid, VSC, nil, "name", fullkey)
    comp_util.set_int(eid, fullkey, level)
end

local default_potion_damage_multiplier_component = {
    air_needed = false,
    blood_material = "",
    drop_items_on_death = false,
    falling_damages = false,
    fire_damage_amount = 0.2,
    fire_probability_of_ignition = 0,
    critical_damage_resistance = 1.0,
    hp = 0.5,
    is_on_fire = false,
    materials_create_messages = false,
    materials_damage = true,
    materials_that_damage = "lava",
    materials_how_much_damage = 0.001,
    ragdoll_filenames_file = "",
    ragdoll_material = ""
}

function M.set_tempered_enchant_level(eid, level)
    M.set_enchant_level(eid, "tempered", level)
    local pbcdc = comp_util.first_component(eid, PBCDC, nil)
    if pbcdc then
        comp_util.set_component_value(pbcdc, "damage_multiplier", (1 - level) * 0.016667)
    end

    if level == 0 then
        EntityAddComponent2(eid, DMC, default_potion_damage_multiplier_component)
    else
        comp_util.remove_all_components_of_type(eid, DMC, nil)
    end

    local dc = comp_util.first_component(eid, DMC, nil)
    comp_util.toggle_component(eid, dc, level == 0)

    local pisc = comp_util.first_component(eid, PISC, nil)
    local temperedGlass = CellFactory_GetType("offering_tempered_glass_box2d")
    comp_util.set_component_value(pisc, "material", temperedGlass)
end

function M.set_reactive_enchant_level(eid, level)
    M.set_enchant_level(eid, "reactive", level)
    local suckComp = comp_util.first_component(eid, MSC, nil)
    local barrel = comp_util.get_component_value(suckComp, "barrel_size")
    local mic = comp_util.first_component(eid, MIC, nil)
    if mic then
        comp_util.set_component_value(mic, "do_reactions", 20 + (level * 20))
        comp_util.set_component_value(mic, "reaction_speed", math.floor(barrel / 200) * (level + 1))
    end
end

function M.set_transmuting_enchant_level(eid, level)
    M.set_enchant_level(eid, "transmuting", level)
    -- TODO
end

function M.set_flooding_enchant_level(eid, level)
    M.set_enchant_level(eid, "flooding", level)
    local barrel_size = comp_util.value_or_default(eid, MSC, "barrel_size", 1000) or 1000 --- @type number
    local potion = comp_util.first_component(eid, "PotionComponent", nil)
    if potion then
        comp_util.set_component_value(potion, "throw_bunch", level == 1)
        comp_util.set_component_value(potion, "throw_how_many", math.floor(math.pow(barrel_size, 0.8)))
    end
end

---TODO make this into "remote" and let it place remotely as well as drain
---@param eid any
---@param level any
function M.set_draining_enchant_level(eid, level)
    M.set_enchant_level(eid, "draining", level)
    -- TODO this is a hack i want to replace per Nathan's suggestion with a parent dynamic
    -- let the flask taking the enchantment sire the draining entity and that'll improve
    -- the logic and make it more sane for multiplayer, but also it's just better praxis.
    if level > 0 then
        local mouseX, mouseY = DEBUG_GetMouseWorld()
        local entitiesNearMouse = EntityGetInRadius(mouseX, mouseY, 100)
        local existingDrain = nil
        for _, e in ipairs(entitiesNearMouse) do
            if EntityGetFilename(e) == DRAINING_XML then existingDrain = e end
        end
        if not existingDrain then
            EntityLoad(DRAINING_XML, mouseX, mouseY)
        end
    end
end

function M.get_localization_key(s) return flask_enchant_loc_prefix .. s end

function M.get_localization(s) return GameTextGet(M.get_localization_key(s)) end

---Default description placeholder. Puts the loc key in the ui description.
---@param combined flask_stats
---@param enchKey string
---@param level integer
---@return string
function M.get_base_enchantment_localization(combined, enchKey, level) return M.get_localization_key(enchKey) end

M.get_tempered_description = M.get_base_enchantment_localization

M.get_draining_description = M.get_base_enchantment_localization

M.get_flooding_description = M.get_base_enchantment_localization

M.get_transmuting_description = M.get_base_enchantment_localization

---Default description placeholder. Puts the loc key in the ui description.
---@param combined flask_stats
---@param enchKey string
---@param level integer
---@return string
function M.get_reactive_description(combined, enchKey, level)
    if level < 0 then return M.get_localization("inert") end
    return M.get_localization(enchKey) .. " " .. level
        .. " " .. M.get_localization("reaction_chance") .. ": " .. M.get_reaction_chance_description(level) .. "%"
        .. " " .. M.get_localization("reaction_speed") .. ": " .. M.get_reaction_speed_description(combined, level)
end

function M.get_reaction_chance_description(level)
    return tostring(20 + (level * 20))
end

---The reaction speed of a flask, in the description
---@param combined flask_stats
---@param level integer
---@return string
function M.get_reaction_speed_description(combined, level)
    local barrel = combined.barrel_size[1]
    return tostring(math.floor(barrel / 200) * (level + 1))
end

M.flask_enchantment_definitions = {
    {
        key = "tempered",
        evaluators = { M.get_brimstone_value },
        min = 0,
        max = 1,
        apply = M.set_tempered_enchant_level,
        describe = M.get_tempered_description
    },
    {
        key = "instant",
        evaluators = { M.get_waterstone_value },
        min = 0,
        max = 1,
        apply = M.set_flooding_enchant_level,
        describe = M.get_flooding_description
    },
    {
        key = "reactive",
        evaluators = { M.get_scroll_value, M.get_tablet_value },
        min = -1,
        max = 4,
        apply = M.set_reactive_enchant_level,
        describe = M.get_reactive_description
    },
    {
        key = "draining",
        evaluators = { M.get_long_distance_cast_value },
        min = 0,
        max = 1,
        apply = M.set_draining_enchant_level,
        describe = M.get_draining_description
    },
    {
        key = "transmuting",
        evaluators = { M.get_potion_mimic_value },
        min = 0,
        max = 1,
        apply = M.set_transmuting_enchant_level,
        describe = M.get_transmuting_description
    }
}

function M.is_flask_offer(eid) return M.is_flask(eid) or M.has_flask_enchant_value(eid) end

---Return whether the item has an enchantment value of any kind
---@param eid entity_id
---@return boolean
function M.has_flask_enchant_value(eid)
    for _, enchant in ipairs(M.flask_enchantment_definitions) do
        if M.get_item_enchantment_value(enchant, eid) ~= 0 then
            return true
        end
    end
    return false
end

---Set the description of the flask in the UI so the player knows its stats
---@param combined flask_stats
---@return string
function M.get_flask_description(combined)
    local result = ""
    for _, def in ipairs(M.flask_enchantment_definitions) do
        if combined.enchantments[def.key] and combined.enchantments[def.key] ~= 0 then
            local enchDesc = def.describe(combined, def.key, combined.enchantments[def.key])
            result = util.append_description(result, enchDesc)
        end
    end
    if combined.barrel_size[1] > 1000 then
        local barrelSizeDesc = GameTextGet(LOCALIZE_BARREL_SIZE) .. ": " .. combined.barrel_size[1]
        result = util.append_description(result, barrelSizeDesc)
    end
    return result
end

function M.get_enchant_level(eid, key)
    return comp_util.get_component_value(
            comp_util.first_component_of_type_with_field_equal(eid, VSC, nil, "name", enchantPrefix .. key), "value_int") or
        0
end

---Turns a collection of VSCs into a material table.
---@param vscs Vsc[]
---@return table<integer, integer>
function M.unpack_map_of_materials(vscs)
    local t = {}
    local function push(vsc)
        -- 0 based offset has to be offset for materials, specifically
        local matId = tonumber(unprefix_material(vsc.name) - 1)
        if not matId then return end
        if vsc.value_int ~= 0 then t[matId] = vsc.value_int end
    end
    util.each(vscs, push)
    return t
end

---Turns a collection of VSCs into an enchantment level table.
---@param vscs Vsc[]
---@return table<string, integer>
function M.unpack_map_of_enchants(vscs)
    local t = {}
    local function push(vsc)
        if vsc.value_int ~= 0 then t[unprefix_enchantment(vsc.name)] = vsc.value_int end
    end
    util.each(vscs, push)
    return t
end

---Return the holders flask stats of the altar provided, which are stored in Vscs
---@param altar entity_id The altar returning holders of the flask stats VSCs
---@return flask_stats[]
function M.get_holder_flask_stats(altar)
    local holders = EntityGetAllChildren(altar) or {}
    local result = {} ---@type flask_stats[]
    for _, holder in ipairs(holders) do
        result[#result + 1] = {
            materials = M.unpack_map_of_materials(comp_util.get_boxes_like(holder, prefix_material(""), "value_int", true)),
            enchantments = M.unpack_map_of_enchants(comp_util.get_boxes_like(holder, prefix_enchantment(""), "value_int",
                true)),
            barrel_size = { comp_util.get_int(holder, prefix_base("barrel_size")) },
            num_cells_sucked_per_frame = { comp_util.get_int(holder, prefix_base("num_cells_sucked_per_frame")) },
            spray_velocity_coeff = { comp_util.get_float(holder, prefix_base("spray_velocity_coeff")) },
            spray_velocity_normalized_min = { comp_util.get_float(holder, prefix_base("spray_velocity_normalized_min")) },
            throw_how_many = { comp_util.get_int(holder, prefix_base("throw_how_many")) }
        } ---@type flask_stats
    end
    return result
end

---Scrape the material inventory of an entity and return its materials as a Materials table
---@param flask entity_id
---@return table<integer, integer>
function M.get_flask_materials(flask)
    if M.is_flask(flask) then
        local comp = comp_util.first_component(flask, MIC, nil)
        return comp_util.get_component_value(comp, "count_per_material_type") ---@type table<integer, integer>
    end
    return {} ---@type table<integer, integer>
end

function M.set_flask_int_from_comp(hid, field, comp)
    comp_util.set_int(hid, prefix_base(field), comp_util.get_component_value(comp, field))
end

function M.set_flask_float_from_comp(hid, field, comp)
    comp_util.set_float(hid, prefix_base(field), comp_util.get_component_value(comp, field))
end

---Store the flask stats of the entity onto the holder as Vscs
---If the holder is a flask enchanter and not a flask, it behaves differently
---@param eid entity_id
---@param hid entity_id
function M.store_flask_stats(eid, hid)
    if comp_util.get_int(hid, "eid") ~= eid then return end

    local function push_enchantment(key, level)
        if level ~= 0 then
            comp_util.set_int(hid, prefix_enchantment(key), level)
        end
    end

    if M.is_flask(eid) then
        -- if the holder has a barrel_size we abort but i forgot why.
        -- i think this is just an already-exists check?
        if comp_util.get_int(hid, prefix_base("barrel_size")) ~= nil then return end
        -- materials
        local materials = M.get_flask_materials(eid)
        local function push_material(matId, amount)
            if amount > 0 then
                comp_util.set_int(hid, prefix_material(matId), amount)
            end
        end
        for matId, amount in pairs(materials) do push_material(matId, amount) end
        for _, def in ipairs(M.flask_enchantment_definitions) do
            push_enchantment(def.key, M.get_enchant_level(eid, def.key))
        end
        -- material sucker properties
        local msc = comp_util.first_component(eid, MSC, nil)
        M.set_flask_int_from_comp(hid, "num_cells_sucked_per_frame", msc)
        M.set_flask_int_from_comp(hid, "barrel_size", msc)
        -- potion comp properties
        local potion = comp_util.first_component(eid, "PotionComponent", nil)
        M.set_flask_float_from_comp(hid, "spray_velocity_coeff", potion)
        M.set_flask_float_from_comp(hid, "spray_velocity_normalized_min", potion)
        M.set_flask_int_from_comp(hid, "throw_how_many", potion)
    elseif M.is_flask_offer(eid) then
        -- enchantments handled here
        -- if the holder already has enchantment we abort early so we don't overwrite it.
        -- this is like the barrel size check in the block above here.
        if #comp_util.get_boxes_like(hid, prefix_enchantment(""), "value_int", true) > 0 then
            return
        end

        -- add any enchant levels to the result
        for _, def in ipairs(M.flask_enchantment_definitions) do
            local level = 0
            for _, eval in ipairs(def.evaluators) do level = level + eval(eid) end
            push_enchantment(def.key, level)
        end
    end
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a nil for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined FlaskStats
---@param upperAltar entity_id
---@param lowerAltar entity_id|nil
---@return flask_stats|nil
function M.merge_flask_stats(upperAltar, lowerAltar)
    local upperFlaskStats = M.get_holder_flask_stats(upperAltar)
    if #upperFlaskStats == 0 then return nil end
    if not lowerAltar then return upperFlaskStats[1] end

    local offerings = M.get_holder_flask_stats(lowerAltar)
    M.collapse_flask_stats(upperFlaskStats[1], offerings)
    return M.get_merged_flask_stats(upperFlaskStats[1])
end

---Scrape the stats out of a flask or holder's stat blocks and collapse them into one result.
---@param target flask_stats an existing flaskStats
---@param offerings flask_stats[] All flask stats as an array of stats holders.
---@return flask_stats
function M.collapse_flask_stats(target, offerings)
    for _, offering in ipairs(offerings) do
        for _, def in ipairs(FLASK_STAT_DEFINITIONS) do
            local stat_pool = offering[def.key]
            if def.formula == "group_sum" then
                for k, v in pairs(stat_pool) do
                    if v ~= 0 then
                        if target[def.key][k] then
                            target[def.key][k] = target[def.key][k] + v
                        else
                            target[def.key][k] = v
                        end
                    end
                end
            else
                for _, value in ipairs(stat_pool) do
                    table.insert(target[def.key], value)
                end
            end
        end
    end
    return target
end

---Returns an empty flask stat table to work on
---@return flask_stats
function M.make_flask_stats()
    return {
        enchantments = {},
        barrel_size = {},
        num_cells_sucked_per_frame = {},
        spray_velocity_coeff = {},
        spray_velocity_normalized_min = {},
        throw_how_many = {},
        materials = {}
    } ---@type flask_stats
end

---Take a single flask stat assemblage and blend the arrays into a flattened FlaskStat with only
---one value per array (or enchants and materials condensed to flat maps, obviously they're still tables)
---@param stats flask_stats|nil
---@return flask_stats|nil
function M.get_merged_flask_stats(stats)
    if not stats then return nil end
    local result = M.make_flask_stats()
    for _, def in ipairs(FLASK_STAT_DEFINITIONS) do
        local pool = stats[def.key]
        if def.formula == "group_sum" then
            for k, v in pairs(pool) do
                if v ~= 0 then
                    if result[def.key][k] then
                        result[def.key][k] = result[def.key][k] + v
                    else
                        result[def.key][k] = v
                    end
                end
            end
        else
            while #pool > 1 do
                local a = table.remove(pool, 1)
                local b = table.remove(pool, 1)
                if def.formula == "sum" then
                    table.insert(pool, 1, a + b)
                elseif def.formula == "clamp_blend" then
                    local scale = 0.5
                    local limit = def.key == "spray_velocity_coeff" and 225 or 1.5
                    local aMerge = util.asymmetricMerge(scale, limit, a, b)
                    table.insert(pool, 1, aMerge)
                end
            end
            table.insert(result[def.key], pool[1])
        end
    end

    -- clamp lower and upper bounds of enchantment def on an enchantment level entry
    ---@param k string enchantment key from the def
    ---@param d flask_enchant_definition
    local function clamp(k, d)
        if result.enchantments[k] then
            result.enchantments[k] = math.min(d.max, math.max(d.min, result.enchantments[k]))
        end
    end
    for _, def in ipairs(M.flask_enchantment_definitions) do if result.enchantments[def.key] then clamp(def.key, def) end end
    return result
end

---Sets the result of the flask item in scope to the stats provided.
---@param flask entity_id
---@param combined flask_stats|nil
function M.set_flask_results(flask, combined)
    if not combined then return end
    entity_util.setDescription(flask, M.get_flask_description(combined))

    local msc = comp_util.first_component(flask, MSC, nil)
    if msc then
        comp_util.set_component_value(msc, "barrel_size", combined.barrel_size[1])
        comp_util.set_component_value(msc, "num_cells_sucked_per_frame", combined.num_cells_sucked_per_frame[1])
    end

    local potion = comp_util.first_component(flask, "PotionComponent", nil)
    if potion then
        comp_util.set_component_value(potion, "spray_velocity_coeff", combined.spray_velocity_coeff[1])
        comp_util.set_component_value(potion, "spray_velocity_normalized_min", combined.spray_velocity_normalized_min[1])
        comp_util.set_component_value(potion, "throw_how_many", combined.throw_how_many[1])
        comp_util.set_component_value(potion, "dont_spray_just_leak_gas_materials", false)
        comp_util.set_component_value(potion, "throw_bunch", false)
    end
    for _, def in ipairs(M.flask_enchantment_definitions) do
        local level = combined.enchantments[def.key] or 0
        def.apply(flask, level)
    end

    -- build the material component by first clearing it
    RemoveMaterialInventoryMaterial(flask)
    local function push(k, v) AddMaterialInventoryMaterial(flask, CellFactory_GetName(k), v) end
    for k, v in pairs(combined.materials or {}) do push(k, v) end
end

return M
