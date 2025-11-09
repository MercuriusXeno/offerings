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

local locPrefix = "$offering_flask_"
local barrelSizeLoc = locPrefix .. "barrel_size"
local originalStats = "original_stats_"
local function unprefix(s, n) return s:sub(n + 1) end

local function prefOg(s) return originalStats .. s end

local function prefMat(s) return prefOg("material_" .. s) end
local MAT = #prefMat("")
local function unprefMat(s) return unprefix(s, MAT) end

local function prefEnch(s) return prefOg("enchant_" .. s) end
local ENCH = #prefEnch("")
local function unprefEnch(s) return unprefix(s, ENCH) end

---@class FlaskStatDef
---@field key string
---@field formula string

local flaskStatDefs = {
    { key = "enchantments",                  formula = "group_sum" },
    { key = "barrel_size",                   formula = "sum" },
    { key = "num_cells_sucked_per_frame",    formula = "sum" },
    { key = "spray_velocity_coeff",          formula = "clamp_blend" },
    { key = "spray_velocity_normalized_min", formula = "clamp_blend" },
    { key = "throw_how_many",                formula = "sum" },
    { key = "materials",                     formula = "group_sum" }
} ---@type FlaskStatDef

---@class FlaskStats
---@field enchantments table<string, integer>
---@field barrel_size integer[]
---@field num_cells_sucked_per_frame integer[]
---@field spray_velocity_coeff number[]
---@field spray_velocity_normalized_min number[]
---@field throw_how_many integer[]
---@field materials table<integer, integer>

-- list of enchantments of flasks and their detection item
---@class FlaskEnchantDef
---@field key string
---@field evaluators (fun(eid: entity_id):integer)[]
---@field min integer
---@field max integer
---@field apply fun(eid: entity_id, level: integer)
---@field describe fun(stats: FlaskStats, key: string, level: integer): string

local M = {} ---@class offering_flask_util

function M.is_flask(eid) return EntityHasTag(eid, "potion") or entity_util.itemNamed(eid, "$item_cocktail") end

---Scrape the level of enchantment an item gives by looping over a def's evaluators
---@param def FlaskEnchantDef
---@param eid entity_id
---@return integer
function M.itemEnchantmentValue(def, eid)
    local r = 0
    for _, f in ipairs(def.evaluators) do r = r + f(eid) end
    return r
end

function M.tabletValue(eid)
    local value = 0
    if EntityHasTag(eid, "normal_tablet") then value = -1 end
    if EntityHasTag(eid, "forged_tablet") then value = -5 end
    return value
end

function M.scrollValue(eid)
    local value = 0
    if EntityHasTag(eid, "scroll") then value = 1 end
    if entity_util.itemNameContains(eid, "book_s_") then value = 5 end
    return value
end

function M.brimstoneValue(eid) return EntityHasTag(eid, "brimstone") and 1 or 0 end

function M.thunderstoneValue(eid) return EntityHasTag(eid, "thunderstone") and 1 or 0 end

function M.potionMimicValue(eid) return entity_util.itemNamed(eid, "$item_potion_mimic") and 1 or 0 end

function M.ldcValue(eid)
    local itemActionComp = comp_util.first_component(eid, "ItemActionComponent", nil)
    if not itemActionComp then return 0 end
    local actionId = comp_util.component_get(itemActionComp, "action_id")
    return actionId == "LONG_DISTANCE_CAST" and 1 or 0
end

function M.storeEnchantKey(eid, key, level)
    local fullkey = enchantPrefix .. key
    comp_util.removeMatch(eid, VSC, nil, "name", fullkey)
    comp_util.store_int(eid, fullkey, level)
end

local defaultPotionDmc = {
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

function M.makeTempered(eid, level)
    M.storeEnchantKey(eid, "tempered", level)
    --logger.log("tempered-ing", eid, "level", level)
    local pbcdc = comp_util.first_component(eid, PBCDC, nil)
    comp_util.component_set(pbcdc, "damage_multiplier", (1 - level) * 0.016667)
    if level == 0 then
        EntityAddComponent2(eid, DMC, defaultPotionDmc)
    else
        comp_util.remove_all_comps(eid, DMC, nil)
    end

    local dc = comp_util.first_component(eid, DMC, nil)
    comp_util.toggleComp(eid, dc, level == 0)

    local pisc = comp_util.first_component(eid, PISC, nil)
    local temperedGlass = CellFactory_GetType("offering_tempered_glass_box2d")
    comp_util.component_set(pisc, "material", temperedGlass)
end

function M.makeReactive(eid, level)
    M.storeEnchantKey(eid, "reactive", level)
    --logger.log("reactive-ing", eid, "level", level)
    local suckComp = comp_util.first_component(eid, MSC, nil)
    local barrel = comp_util.component_get(suckComp, "barrel_size")
    local comp = comp_util.first_component(eid, MIC, nil)
    comp_util.component_set(comp, "do_reactions", 20 + (level * 20))
    comp_util.component_set(comp, "reaction_speed", math.floor(barrel / 200) * (level + 1))
end

function M.makeTransmuting(eid, level)
    M.storeEnchantKey(eid, "transmuting", level)
    --logger.log("transmuting-ing", eid, "level", level)
    -- TODO
end

function M.makeInstant(eid, level)
    M.storeEnchantKey(eid, "instant", level)
    --logger.log("instant-ing", eid, "level", level)
    local barrel_size = comp_util.valueOrDefault(eid, MSC, "barrel_size", 1000) or 1000--- @type number
    local potionComp = comp_util.first_component(eid, "PotionComponent", nil)
    comp_util.component_set(potionComp, "throw_bunch", level == 1)
    comp_util.component_set(potionComp, "throw_how_many", math.floor(math.pow(barrel_size, 0.8)))
end

local drainXml = "mods/offerings/entity/draining.xml"
function M.makeDraining(eid, level)
    M.storeEnchantKey(eid, "draining", level)
    --logger.log("draining-ing", eid, "level", level)

    --draining is kind of a hack. The moment a draining entity exists they
    --are with you forever, but only "functional" when holding a draining flask.
    -- it just kinda follows you everywhere. There can only be one.
    if level > 0 then
        local mouseX, mouseY = DEBUG_GetMouseWorld()
        local entitiesNearMouse = EntityGetInRadius(mouseX, mouseY, 100)
        local existingDrain = nil
        for _, e in ipairs(entitiesNearMouse) do
            if EntityGetFilename(e) == drainXml then existingDrain = e end
        end
        if not existingDrain then
            EntityLoad(drainXml, mouseX, mouseY)
        end
    end
end

function M.locKey(s) return flask_enchant_loc_prefix .. s end

function M.loc(s) return GameTextGet(M.locKey(s)) end

---Default description placeholder. Puts the loc key in the ui description.
---@param combined FlaskStats
---@param enchKey string
---@param level integer
---@return string
function M.defaultEnchantLoc(combined, enchKey, level) return M.locKey(enchKey) end

M.describeTempered = M.defaultEnchantLoc

M.describeDraining = M.defaultEnchantLoc

M.describeInstant = M.defaultEnchantLoc

M.describeTransmuting = M.defaultEnchantLoc

---Default description placeholder. Puts the loc key in the ui description.
---@param combined FlaskStats
---@param enchKey string
---@param level integer
---@return string
function M.describeReactive(combined, enchKey, level)
    if level < 0 then return M.loc("inert") end
    return M.loc(enchKey) .. " " .. level
        .. " " .. M.loc("reaction_chance") .. ": " .. M.reactionChance(level) .. "%"
        .. " " .. M.loc("reaction_speed") .. ": " .. M.reactionSpeed(combined, level)
end

function M.reactionChance(level)
    return tostring(20 + (level * 20))
end

---The reaction speed of a flask, in the description
---@param combined FlaskStats
---@param level integer
---@return string
function M.reactionSpeed(combined, level)
    local barrel = combined.barrel_size[1]
    return tostring(math.floor(barrel / 200) * (level + 1))
end

M.flaskEnchantDefs = {
    {
        key = "tempered",
        evaluators = { M.brimstoneValue },
        min = 0,
        max = 1,
        apply = M.makeTempered,
        describe = M.describeTempered
    },
    {
        key = "instant",
        evaluators = { M.thunderstoneValue },
        min = 0,
        max = 1,
        apply = M.makeInstant,
        describe = M.describeInstant
    },
    {
        key = "reactive",
        evaluators = { M.scrollValue, M.tabletValue },
        min = -1,
        max = 4,
        apply = M.makeReactive,
        describe = M.describeReactive
    },
    {
        key = "draining",
        evaluators = { M.ldcValue },
        min = 0,
        max = 1,
        apply = M.makeDraining,
        describe = M.describeDraining
    },
    {
        key = "transmuting",
        evaluators = { M.potionMimicValue },
        min = 0,
        max = 1,
        apply = M.makeTransmuting,
        describe = M.describeTransmuting
    }
}

function M.is_flask_offer(eid) return M.is_flask(eid) or M.hasAnyEnchantValue(eid) end

---Return whether the item has an enchantment value of any kind
---@param eid entity_id
---@return boolean
function M.hasAnyEnchantValue(eid)
    --logger.log("enchantment defs", flaskEnchantDefs)
    for _, enchant in ipairs(M.flaskEnchantDefs) do
        --logger.log("def evaluators", #enchant.evaluators)
        if M.itemEnchantmentValue(enchant, eid) ~= 0 then
            --logger.log("enchant", enchant, "value detected on", eid)
            return true
        end
    end
    return false
end

---Set the description of the flask in the UI so the player knows its stats
---@param combined FlaskStats
---@return string
function M.describeFlask(combined)
    local result = ""
    for _, def in ipairs(M.flaskEnchantDefs) do
        if combined.enchantments[def.key] and combined.enchantments[def.key] ~= 0 then
            local enchDesc = def.describe(combined, def.key, combined.enchantments[def.key])
            result = util.appendDescription(result, enchDesc)
        end
    end
    --logger.log("describing flask, combined stats", combined)
    if combined.barrel_size[1] > 1000 then
        local barrelSizeDesc = GameTextGet(barrelSizeLoc) .. ": " .. combined.barrel_size[1]
        result = util.appendDescription(result, barrelSizeDesc)
    end
    return result
end

function M.enchantLevel(eid, key)
    return comp_util.component_get(comp_util.firstComponentMatching(eid, VSC, nil, "name", enchantPrefix .. key), "value_int") or 0
end

---Turns a collection of VSCs into a material table.
---@param vscs Vsc[]
---@return table<integer, integer>
function M.materializeMaterials(vscs)
    local t = {}
    local function push(vsc)
        -- 0 based offset has to be offset for materials, specifically
        local matId = tonumber(unprefMat(vsc.name) - 1)
        if not matId then return end
        if vsc.value_int ~= 0 then t[matId] = vsc.value_int end
    end
    util.each(vscs, push)
    return t
end

---Turns a collection of VSCs into an enchantment level table.
---@param vscs Vsc[]
---@return table<string, integer>
function M.materializeEnchants(vscs)
    local t = {}
    local function push(vsc)
        if vsc.value_int ~= 0 then t[unprefEnch(vsc.name)] = vsc.value_int end
    end
    util.each(vscs, push)
    return t
end

---Return the holders flask stats of the altar provided, which are stored in Vscs
---@param altar entity_id The altar returning holders of the flask stats VSCs
---@return FlaskStats[]
function M.holderFlaskStats(altar)
    local holders = EntityGetAllChildren(altar) or {}
    local result = {} ---@type FlaskStats[]
    for _, holder in ipairs(holders) do
        result[#result + 1] = {
            materials = M.materializeMaterials(comp_util.storedBoxesLike(holder, prefMat(""), "value_int", true)),
            enchantments = M.materializeEnchants(comp_util.storedBoxesLike(holder, prefEnch(""), "value_int", true)),
            barrel_size = { comp_util.get_int(holder, prefOg("barrel_size")) },
            num_cells_sucked_per_frame = { comp_util.get_int(holder, prefOg("num_cells_sucked_per_frame")) },
            spray_velocity_coeff = { comp_util.storedFloat(holder, prefOg("spray_velocity_coeff")) },
            spray_velocity_normalized_min = { comp_util.storedFloat(holder, prefOg("spray_velocity_normalized_min")) },
            throw_how_many = { comp_util.get_int(holder, prefOg("throw_how_many")) }
        } ---@type FlaskStats
    end
    return result
end

---Scrape the material inventory of an entity and return its materials as a Materials table
---@param flask entity_id
---@return table<integer, integer>
function M.flaskMaterials(flask)
    if M.is_flask(flask) then
        local comp = comp_util.first_component(flask, MIC, nil)
        return comp_util.component_get(comp, "count_per_material_type") ---@type table<integer, integer>
    end
    return {} ---@type table<integer, integer>
end

---Store the flask stats of the entity onto the holder as Vscs
---If the holder is a flask enchanter and not a flask, it behaves differently
---@param eid entity_id
---@param hid entity_id
function M.store_flask_stats(eid, hid)
    if comp_util.get_int(hid, "eid") ~= eid then return end

    local function pushEnch(key, level)
        if level ~= 0 then comp_util.store_int(hid, prefEnch(key), level) end
    end
    if M.is_flask(eid) then
        --logger.log("adding flask to offerings")
        -- if the holder has a barrel_size VSC ALSO don't overwrite it.
        local existing = comp_util.get_int(hid, prefOg("barrel_size"))
        if existing then return end

        local materials = M.flaskMaterials(eid)
        local function pushMat(matId, amount) if amount > 0 then comp_util.store_int(hid, prefMat(matId), amount) end end
        for matId, amount in pairs(materials) do pushMat(matId, amount) end
        for _, def in ipairs(M.flaskEnchantDefs) do pushEnch(def.key, M.enchantLevel(eid, def.key)) end

        local msc = comp_util.first_component(eid, MSC, nil)
        comp_util.store_int(hid, prefOg("num_cells_sucked_per_frame"), comp_util.component_get(msc, "num_cells_sucked_per_frame"))
        comp_util.store_int(hid, prefOg("barrel_size"), comp_util.component_get(msc, "barrel_size"))

        local potion = comp_util.first_component(eid, "PotionComponent", nil)
        comp_util.storeFloat(hid, prefOg("spray_velocity_coeff"), comp_util.component_get(potion, "spray_velocity_coeff"))
        comp_util.storeFloat(hid, prefOg("spray_velocity_normalized_min"), comp_util.component_get(potion, "spray_velocity_normalized_min"))
        comp_util.store_int(hid, prefOg("throw_how_many"), comp_util.component_get(potion, "throw_how_many"))
    elseif M.is_flask_offer(eid) then
        local existing = comp_util.storedBoxesLike(hid, prefEnch(""), "value_int", true)
        --logger.log("adding enchantment to offerings", eid, "existing enchants", existing)
        if #existing > 0 then return end

        -- if the holder already has enchantment VSCs ALSO don't overwrite it
        for _, def in ipairs(M.flaskEnchantDefs) do
            local level = 0
            for _, eval in ipairs(def.evaluators) do
                level = level + eval(eid)
            end
            --logger.log("def", def, "level", level)
            pushEnch(def.key, level)
        end
    end
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a nil for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined FlaskStats
---@param upperAltar entity_id
---@param lowerAltar entity_id|nil
---@return FlaskStats|nil
function M.merge_flask_stats(upperAltar, lowerAltar)
    local upperFlaskStats = M.holderFlaskStats(upperAltar)
    if #upperFlaskStats == 0 then return nil end
    if not lowerAltar then return upperFlaskStats[1] end

    local offerings = M.holderFlaskStats(lowerAltar)
    M.injectFlaskStatsIntoFlaskStats(upperFlaskStats[1], offerings)
    --logger.log("results before blend", upperFlaskStats[1], "offerings before blend", offerings)

    local blended = M.blendFlaskStats(upperFlaskStats[1])

    --logger.log("blended flask result", blended)
    return blended
end

---Scrape the stats out of a flask or holder's stat blocks
---@param flaskStats FlaskStats an existing flaskStats
---@param allOfferingsStats FlaskStats[] All flask stats as an array of stats holders.
---@return FlaskStats
function M.injectFlaskStatsIntoFlaskStats(flaskStats, allOfferingsStats)
    for _, offeringStats in ipairs(allOfferingsStats) do
        for _, def in ipairs(flaskStatDefs) do
            local statPool = offeringStats[def.key]
            if def.formula == "group_sum" then
                for k, v in pairs(statPool) do
                    if v ~= 0 then
                        if flaskStats[def.key][k] then
                            flaskStats[def.key][k] = flaskStats[def.key][k] + v
                        else
                            flaskStats[def.key][k] = v
                        end
                    end
                end
            else
                for _, value in ipairs(statPool) do
                    table.insert(flaskStats[def.key], value)
                end
            end
        end
    end
    return flaskStats
end

---Returns an empty flask stat table to work on
---@return FlaskStats
function M.newFlaskStats()
    return {
        enchantments = {},
        barrel_size = {},
        num_cells_sucked_per_frame = {},
        spray_velocity_coeff = {},
        spray_velocity_normalized_min = {},
        throw_how_many = {},
        materials = {}
    } ---@type FlaskStats
end

---Take a single flask stat assemblage and blend the arrays into a flattened FlaskStat with only
---one value per array (or enchants and materials condensed to flat maps, obviously they're still tables)
---@param flaskStats FlaskStats|nil
---@return FlaskStats|nil
function M.blendFlaskStats(flaskStats)
    if not flaskStats then return nil end
    local result = M.newFlaskStats()
    for _, def in ipairs(flaskStatDefs) do
        local pool = flaskStats[def.key]
        --logger.log(def.key .. " pool of stats blending", pool)
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
            --logger.log("pool of stats", pool, "merge strategy", def.formula)
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
    ---@param d FlaskEnchantDef
    local function clamp(k, d)
        if result.enchantments[k] then
            result.enchantments[k] = math.min(d.max, math.max(d.min, result.enchantments[k]))
        end
    end
    for _, def in ipairs(M.flaskEnchantDefs) do if result.enchantments[def.key] then clamp(def.key, def) end end
    --logger.log("flask combo results", result)
    return result
end

---Sets the result of the flask item in scope to the stats provided.
---@param flask entity_id
---@param combined FlaskStats|nil
function M.set_flask_results(flask, combined)
    --logger.log("setting flask results", flask, "results", combined)
    if not combined then return end
    entity_util.setDescription(flask, M.describeFlask(combined))

    local msc = comp_util.first_component(flask, MSC, nil)
    comp_util.component_set(msc, "barrel_size", combined.barrel_size[1])
    comp_util.component_set(msc, "num_cells_sucked_per_frame", combined.num_cells_sucked_per_frame[1])

    local potion = comp_util.first_component(flask, "PotionComponent", nil)
    comp_util.component_set(potion, "spray_velocity_coeff", combined.spray_velocity_coeff[1])
    comp_util.component_set(potion, "spray_velocity_normalized_min", combined.spray_velocity_normalized_min[1])
    comp_util.component_set(potion, "throw_how_many", combined.throw_how_many[1])
    comp_util.component_set(potion, "dont_spray_just_leak_gas_materials", false)
    comp_util.component_set(potion, "throw_bunch", false)

    for _, def in ipairs(M.flaskEnchantDefs) do
        local level = combined.enchantments[def.key] or 0
        def.apply(flask, level)
    end

    -- build the material component by first clearing it
    RemoveMaterialInventoryMaterial(flask)
    local function push(k, v) AddMaterialInventoryMaterial(flask, CellFactory_GetName(k), v) end
    for k, v in pairs(combined.materials or {}) do push(k, v) end
end

return M