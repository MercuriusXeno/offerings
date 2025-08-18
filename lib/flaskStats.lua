dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

local enchantPrefix = "offering_flask_enchant_"
local flask_enchant_loc_prefix = "$" .. enchantPrefix

local VSC = "VariableStorageComponent"
local MIC = "MaterialInventoryComponent"
local MSC = "MaterialSuckerComponent"
local PBCDC = "PhysicsBodyCollisionDamageComponent"

local locPrefix = "$offerings_flask_"
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

---@class FlaskEnchant
---@field key string
---@field level integer

---@class Reactivity
---@field chance integer
---@field speed integer

local flaskEnchantDefs = {} ---@type FlaskEnchantDef[]

---Registers a flask enchantment definition to the array. Can be called externally
function registerFlaskEnchantment(key, evaluators, min, max, apply, describe)
    local def = {
        key = key,
        evaluators = evaluators,
        min = min,
        max = max,
        apply = apply,
        describe = describe
    } ---@type FlaskEnchantDef
    flaskEnchantDefs[#flaskEnchantDefs + 1] = def
end

registerFlaskEnchantment("tempered", { brimstoneValue }, 0, 1, removeDamageModels, describeTempered)
registerFlaskEnchantment("instant", { thunderstoneValue }, 0, 1, makeInstant, describeInstant)
registerFlaskEnchantment("reactive", { scrollValue, tabletValue }, -1, 5, makeReactive, describeReactive)
registerFlaskEnchantment("draining", { ldcValue }, 0, 1, makeDraining, describeDraining)
registerFlaskEnchantment("transmuting", { potionMimicValue }, 0, 1, makeTransmuting, describeTransmuting)

function isFlask(eid) return EntityHasTag(eid, "potion") or itemNamed(eid, "$item_cocktail") end

function isFlaskEnhancer(eid) return isFlask(eid) or hasAnyEnchantValue(eid) end

function itemEnchantmentValue(def, eid)
    local r = 0
    for _, f in ipairs(def.evaluators) do r = r + f(eid) end
    return r
end

function hasAnyEnchantValue(eid)
    for _, enchant in pairs(flaskEnchantDefs) do
        if itemEnchantmentValue(enchant, eid) ~= 0 then return true end
    end
    return false
end

function tabletValue(eid)
    local value = 0
    if EntityHasTag(eid, "normal_tablet") then value = -1 end
    if EntityHasTag(eid, "forged_tablet") then value = -5 end
    return value
end

function scrollValue(eid)
    local value = 0
    if EntityHasTag(eid, "scroll") then value = 1 end
    if itemNameContains(eid, "book_s_") then value = 5 end
    return value
end

function brimstoneValue(eid) return EntityHasTag(eid, "brimstone") and 1 or 0 end

function thunderstoneValue(eid) return EntityHasTag(eid, "thunderstone") and 1 or 0 end

function potionMimicValue(eid) return itemNamed(eid, "$item_potion_mimic") and 1 or 0 end

function ldcValue(eid) return EntityHasTag(eid, "waterstone") and 1 or 0 end

function removeDamageModels(eid) removeAll(eid, "DamageModelComponent") end

function makeReactive(eid, level)
    eachComponentSet(eid, MIC, nil, "reaction_rate", math.max(0, math.min(20 + (level * 20), 100)))
end

function makeTransmuting(eid, level)
    local key = enchantPrefix .. "transmuting"
    removeMatch(eid, VSC, nil, "name", key)
    storeInt(eid, key, level)
end

function makeInstant(eid, _)
    local barrel_size = valueOrDefault(eid, MSC, "barrel_size", 1000)
    local potionComp = firstComponent(eid, "PotionComponent", nil)
    setValue(potionComp, "throw_bunch", true)
    setValue(potionComp, "throw_how_many", barrel_size)
end

function makeDraining(eid, level)
    local key = enchantPrefix .. "draining"
    removeMatch(eid, VSC, nil, "name", key)
    storeInt(eid, key, level) -- temporary draining flag
end

function locKey(s) return flask_enchant_loc_prefix .. s end

function loc(s) return GameTextGet(locKey(s)) end

function defaultEnchantLoc(combined, enchKey, level) return locKey(enchKey) end

describeTempered = defaultEnchantLoc

describeDraining = defaultEnchantLoc

describeInstant = defaultEnchantLoc

describeTransmuting = defaultEnchantLoc

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

---Set the description of the flask in the UI so the player knows its stats
---@param combined FlaskStats
---@return string
function describeFlask(combined)
    local result = ""
    for _, def in ipairs(flaskEnchantDefs) do
        if combined.enchantments[def.key] and combined.enchantments[def.key] ~= 0 then
            local enchDesc = def.describe(combined, def.key, combined.enchantments[def.key])
            result = appendDescription(result, enchDesc)
        end
    end
    if combined.barrel_size[1] > 1000 then
        local barrelSizeDesc = GameTextGet(barrelSizeLoc) .. ": " .. combined.barrel_size[1]
        result = appendDescription(result, barrelSizeDesc)
    end
    return result
end

function enchantLevel(eid, key)
    return cGet(firstComponentMatching(eid, VSC, nil, "name", enchantPrefix .. key), "value_int") or 0
end

---Turns a collection of VSCs into a material table.
---@param vscs Vsc[]
---@return table<integer, integer>
function materializeMaterials(vscs)
    local t = {}
    local function push(vsc)
        -- 0 based offset has to be offset for materials, specifically
        local matId = tonumber(unprefMat(vsc.name) - 1)
        if not matId then return end
        if vsc.value_int ~= 0 then t[matId] = vsc.value_int end
    end
    each(vscs, push)
    return t
end

---Turns a collection of VSCs into an enchantment level table.
---@param vscs Vsc[]
---@return table<string, integer>
function materializeEnchants(vscs)
    local t = {}
    local function push(vsc)
        if vsc.value_int ~= 0 then t[unprefEnch(vsc.name)] = vsc.value_int end
    end
    each(vscs, push)
    return t
end

---Return the holders flask stats of the altar provided, which are stored in Vscs
---@param altar entity_id The altar returning holders of the flask stats VSCs
---@return FlaskStats[]
function holderFlaskStats(altar)
    local holders = EntityGetAllChildren(altar) or {}
    local result = {} ---@type FlaskStats[]
    for _, holder in ipairs(holders) do
        result[#result + 1] = {
            materials = materializeMaterials(storedsBoxedLike(holder, prefMat(""), "value_int", true)),
            enchantments = materializeEnchants(storedsBoxedLike(holder, prefEnch(""), "value_int", true)),
            barrel_size = { storedInt(holder, prefOg("barrel_size")) },
            num_cells_sucked_per_frame = { storedInt(holder, prefOg("num_cells_sucked_per_frame")) },
            spray_velocity_coeff = { storedFloat(holder, prefOg("spray_velocity_coeff")) },
            spray_velocity_normalized_min = { storedFloat(holder, prefOg("spray_velocity_normalized_min")) },
            throw_how_many = { storedInt(holder, prefOg("throw_how_many")) }
        } ---@type FlaskStats
    end
    return result
end

---Scrape the material inventory of an entity and return its materials as a Materials table
---@param flask entity_id
---@return table<integer, integer>
function flaskMaterials(flask)
    if isFlask(flask) then
        local comp = firstComponent(flask, MIC, nil)
        return cGet(comp, "count_per_material_type") ---@type table<integer, integer>
    end
    return {} ---@type table<integer, integer>
end

---Store the flask stats of the entity onto the holder as Vscs
---If the holder is a flask enchanter and not a flask, it behaves differently
---@param eid entity_id
---@param hid entity_id
function storeFlaskStats(eid, hid)
    if storedInt(hid, "eid") ~= eid then return end

    local function pushEnch(key, level)
        if level ~= 0 then storeInt(hid, prefEnch(key), level) end
    end
    if isFlask(eid) then
        -- if the holder has a barrel_size VSC ALSO don't overwrite it.
        local existing = storedInt(hid, prefOg("barrel_size"))
        if existing then return end

        local materials = flaskMaterials(eid)
        local function pushMat(matId, amount) if amount > 0 then storeInt(hid, prefMat(matId), amount) end end
        for matId, amount in pairs(materials) do pushMat(matId, amount) end
        for key, _ in pairs(flaskEnchantDefs) do pushEnch(key, enchantLevel(eid, key)) end

        local msc = firstComponent(eid, MSC, nil)
        storeInt(hid, prefOg("num_cells_sucked_per_frame"), cGet(msc, "num_cells_sucked_per_frame"))
        storeInt(hid, prefOg("barrel_size"), cGet(msc, "barrel_size"))

        local potion = firstComponent(eid, "PotionComponent", nil)
        storeFloat(hid, prefOg("spray_velocity_coeff"), cGet(potion, "spray_velocity_coeff"))
        storeFloat(hid, prefOg("spray_velocity_normalized_min"), cGet(potion, "spray_velocity_normalized_min"))
        storeInt(hid, prefOg("throw_how_many"), cGet(potion, "throw_how_many"))
    elseif isFlaskEnhancer(eid) then
        local existing = storedsLike(hid, prefEnch(""), "value_int", true)
        if #existing > 0 then return end

        -- if the holder already has enchantment VSCs ALSO don't overwrite it
        for _, def in ipairs(flaskEnchantDefs) do
            local level = 0
            for _, eval in ipairs(def.evaluators) do
                level = level + eval(eid)
            end
            pushEnch(def.key, level)
        end
    end
end

---Return the reactivity stats of a flask stat amalgam.
---@param c FlaskStats
---@return Reactivity
function reactivity(c)
    local level = 0
    if c.enchantments["reactive"] then level = level + c.enchantments["reactive"] end
    return {
        chance = 20 + (level * 20),
        --- vanilla flasks with 1000 max have a 5 speed (1/200th of size)
        --- this keeps that proportion, possibly imbalanced?
        speed = math.floor(c.barrel_size[1] / 200) * (level + 1)
    }
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a nil for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined FlaskStats
---@param upperAltar entity_id
---@param lowerAltar entity_id|nil
---@return FlaskStats|nil
function mergeFlaskStats(upperAltar, lowerAltar)
    local upperFlaskStats = holderFlaskStats(upperAltar)
    if #upperFlaskStats == 0 then return nil end
    if not lowerAltar then return upperFlaskStats[1] end

    local offerings = holderFlaskStats(lowerAltar)
    injectFlaskStatsIntoFlaskStats(upperFlaskStats[1], offerings)
    --thonk.about("results before blend", upperFlaskStats[1], "offerings before blend", offerings)

    local blended = blendFlaskStats(upperFlaskStats[1])

    --thonk.about("blended flask result", blended)
    return blended
end

---Scrape the stats out of a flask or holder's stat blocks
---@param flaskStats FlaskStats an existing flaskStats
---@param allOfferingsStats FlaskStats[] All flask stats as an array of stats holders.
---@return FlaskStats
function injectFlaskStatsIntoFlaskStats(flaskStats, allOfferingsStats)
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
function newFlaskStats()
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
function blendFlaskStats(flaskStats)
    if not flaskStats then return nil end
    local result = newFlaskStats()
    for _, def in ipairs(flaskStatDefs) do
        local pool = flaskStats[def.key]
        -- thonk.about(def.key .. " pool of stats blending", pool)
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
            -- thonk.about("pool of stats", pool, "merge strategy", def.formula)
            while #pool > 1 do
                local a = table.remove(pool, 1)
                local b = table.remove(pool, 1)
                if def.formula == "sum" then
                    table.insert(pool, 1, a + b)
                elseif def.formula == "clamp_blend" then
                    local scale = 0.5
                    local limit = def.key == "spray_velocity_coeff" and 225 or 1.5
                    local aMerge = asymmetricMerge(scale, limit, a, b)
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
        if #result.enchantments[k] ~= 0 then
            result.enchantments[k] = math.min(d.max, math.max(d.min, result.enchantments[k]))
        end
    end
    for _, def in ipairs(flaskEnchantDefs) do if result.enchantments[def.key] then clamp(def.key, def) end end
    --thonk.about("flask combo results", result)
    return result
end

function setFlaskReactivity(flask, reactivity)
    local comp = firstComponent(flask, MIC, nil)
    cSet(comp, "do_reactions", reactivity.chance)
    cSet(comp, "reaction_speed", reactivity.speed)
end

function setFlaskDamageModelsAndPhysicsBodyDamage(flask, combined)
    local tempered = combined.enchantments.tempered or 0
    eachComponentSet(flask, PBCDC, nil, "damage_multiplier", (1 - tempered) * 0.016667)
    toggleComps(flask, "DamageModelComponent", nil, tempered == 0)
end

---Sets the result of the flask item in scope to the stats provided.
---@param flask entity_id
---@param combined FlaskStats|nil
function setFlaskResult(flask, combined)
    if not combined then return end
    setDescription(flask, describeFlask(combined))
    for key, level in pairs(combined.enchantments or {}) do flaskEnchantDefs[key].apply(flask, level) end
    local msc = firstComponent(flask, MSC, nil)
    cSet(msc, "barrel_size", combined.barrel_size[1])
    cSet(msc, "num_cells_sucked_per_frame", combined.num_cells_sucked_per_frame[1])

    local potion = firstComponent(flask, "PotionComponent", nil)
    cSet(potion, "spray_velocity_coeff", combined.spray_velocity_coeff[1])
    cSet(potion, "spray_velocity_normalized_min", combined.spray_velocity_normalized_min[1])
    cSet(potion, "throw_how_many", combined.throw_how_many[1])
    cSet(potion, "dont_spray_just_leak_gas_materials", false)
    if combined.barrel_size[1] > 10000 then cSet(potion, "throw_bunch", true) end
    local reactivity = reactivity(combined)
    setFlaskReactivity(flask, reactivity)
    setFlaskDamageModelsAndPhysicsBodyDamage(flask, combined)
    -- build the material component by first clearing it
    RemoveMaterialInventoryMaterial(flask)
    local function push(k, v) AddMaterialInventoryMaterial(flask, CellFactory_GetName(k), v) end
    for k, v in pairs(combined.materials or {}) do push(k, v) end
end
