dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")

local enchantPrefix = "offering_flask_enchant_"
local flask_enchant_loc_prefix = "$" .. enchantPrefix

local VSC = "VariableStorageComponent"
local MIC = "MaterialInventoryComponent"
local MSC = "MaterialSuckerComponent"
local PBCDC = "PhysicsBodyCollisionDamageComponent"

local locPrefix = "$offerings_"
local barrelSizeLoc = locPrefix .. "barrel_size"
--this seems more balanced than taking .5% of the barrel size.
local reactSpeedExp = (math.log(5) / math.log(1000))
local originalStats = "original_stats_"
local function unprefix(s, n) return s:sub(n + 1) end

local function prefOg(s) return originalStats .. s end

local function prefMat(s) return prefOg("material_" .. s) end
local MAT = #prefMat("")
local function unprefMat(s) return unprefix(s, MAT) end

local function prefEnch(s) return prefOg("enchant_" .. s) end
local ENCH = #prefEnch("")
local function unprefEnch(s) return unprefix(s, ENCH) end

function flaskMaterials(eid)
    if isFlask(eid) then
        local comp = firstComponent(eid, MIC)
        return cGet(comp, "count_per_material_type")
    end
    return {}
end

-- list of enchantments of flasks and their detection item
local enchants = {}

local function sumEnchantPower(def, eid)
    local r = 0
    for _, f in ipairs(def.evaluators) do r = r + f(eid) end
    return r
end

function registerFlaskEnchantment(key, evaluators, min, max, apply, describe)
    local def = {
        key = key,
        evaluators = evaluators,
        min = min,
        max = max,
        apply = apply,
        describe = describe
    }
    local function defSum(eid) return sumEnchantPower(enchants[key], eid) end
    def.value = defSum
    enchants[key] = def
end

registerFlaskEnchantment("tempered", { brimstoneValue }, 0, 1, removeDamageModels, describeTempered)
registerFlaskEnchantment("instant", { thunderstoneValue }, 0, 1, makeInstant, describeInstant)
registerFlaskEnchantment("reactive", { scrollValue, tabletValue }, -1, 5, makeReactive, describeReactive)
registerFlaskEnchantment("draining", { waterstoneValue }, 0, 1, makeDraining, describeDraining)
registerFlaskEnchantment("transmuting", { potionMimicValue }, 0, 1, makeTransmuting, describeTransmuting)

function hasAnyEnchantValue(eid)
    for _, enchant in pairs(enchants) do
        if enchant.value(eid) ~= 0 then return true end
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

function waterstoneValue(eid) return EntityHasTag(eid, "waterstone") and 1 or 0 end

function removeDamageModels(eid) removeAll(eid, "DamageModelComponent") end

function makeReactive(eid, level)
    eachComponentSet(eid, MIC, nil, "reaction_rate", math.max(0, math.min(20 + (level * 20), 100)))
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

function describeFlask(combined)
    local result = ""
    for key, def in pairs(enchants) do
        if combined.enchantments[key] and combined.enchantments[key] ~= 0 then
            local enchDesc = def.describe(combined, key, combined.enchantments[key])
            result = appendDescription(result, enchDesc)
        end
    end
    if combined.barrel_size > 1000 then
        local barrelSizeDesc = GameTextGet(barrelSizeLoc) .. ": " .. combined.barrel_size
        result = appendDescription(result, barrelSizeDesc)
    end
    return result
end

function enchantLevel(eid, key)
    return cGet(firstComponentMatching(eid, VSC, nil, "name", enchantPrefix .. key), "value_int") or 0
end

function materialize(vscs, unpref, isMaterialOffset)
end

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

function materializeEnchants(vscs)
    local t = {}
    local function push(vsc)
        if vsc.value_int ~= 0 then t[unprefEnch(vsc.name)] = vsc.value_int end
    end
    each(vscs, push)
    return t
end

function originalFlask(altar)
    return {
        materials = materializeMaterials(storedsLike(altar, prefMat(""), false, "value_int", true)),
        enchantments = materializeEnchants(storedsLike(altar, prefEnch(""), false, "value_int", true)),
        barrel_size = storedInt(altar, prefOg("barrel_size"), true),
        num_cells_sucked_per_frame = storedInt(altar, prefOg("num_cells_sucked_per_frame"), true),
        spray_velocity_coeff = storedFloat(altar, prefOg("spray_velocity_coeff"), true),
        spray_velocity_normalized_min = storedFloat(altar, prefOg("spray_velocity_normalized_min"), true),
        throw_how_many = storedInt(altar, prefOg("throw_how_many"), true)
    }
end

function storeFlaskStats(altar, eid)
    clearOriginalStats(altar)
    local function pushMat(matId, amount) if amount > 0 then storeInt(altar, prefMat(matId), amount) end end
    for matId, amount in pairs(flaskMaterials(eid)) do pushMat(matId, amount) end
    local function pushEnch(key, level)
        if level ~= 0 then
            debugOut(" enchant " .. key .. " is level " .. level .. " so we are storing the int!")
            storeInt(altar, prefEnch(key), level)
        end
    end
    for key, _ in pairs(enchants) do pushEnch(key, enchantLevel(eid, key)) end
    local msc = firstComponent(eid, MSC)
    storeInt(altar, prefOg("num_cells_sucked_per_frame"), cGet(msc, "num_cells_sucked_per_frame"))
    storeInt(altar, prefOg("barrel_size"), cGet(msc, "barrel_size"))
    local potion = firstComponent(eid, "PotionComponent")
    storeFloat(altar, prefOg("spray_velocity_coeff"), cGet(potion, "spray_velocity_coeff"))
    storeFloat(altar, prefOg("spray_velocity_normalized_min"), cGet(potion, "spray_velocity_normalized_min"))
    storeInt(altar, prefOg("throw_how_many"), cGet(potion, "throw_how_many"))
end

function reactivity(c)
    local level = c.enchantments.reactive or 0
    return {
        chance = 20 + (level * 20),
        speed = math.floor(c.barrel_size ^ reactSpeedExp) * (level + 1)
    }
end

function combineFlasks(upperAltar, lowerAltar, isRestore)
    local t = originalFlask(upperAltar)
    local offered = isRestore and {} or flaskEnhancers(lowerAltar)
    for _, offer in ipairs(offered) do
        if isFlask(offer) then
            local function pushMat(k, v) if v > 0 then increment(t.materials, prefMat(k), v) end end
            for matId, amount in pairs(flaskMaterials(offer)) do pushMat(matId, amount) end
            local function pushEnch(k, v) if v ~= 0 then increment(t.enchantments, k, v) end end
            for k, _ in pairs(enchants) do pushEnch(k, enchantLevel(offer, k)) end
            local msc = firstComponent(offer, MSC)
            cSum(t, msc, "barrel_size")
            cSum(t, msc, "num_cells_sucked_per_frame")
            local potion = firstComponent(offer, "PotionComponent")
            cMerge(t, potion, "spray_velocity_coeff", 225, 0.5)
            cMerge(t, potion, "spray_velocity_normalized_min", 1.5, 0.5)
            cMerge(t, potion, "throw_how_many", t.barrel_size ^ 0.75, 1)
        else
            local function pushEnch(k, v) increment(t.enchantments, k, v) end
            for k, def in pairs(enchants) do pushEnch(k, def.value(offer)) end
        end
    end

    -- clamp lower and upper bounds
    local function clamp(k, d) t.enchantments[k] = math.min(d.max, math.max(d.min, t.enchantments[k])) end
    for key, def in pairs(enchants) do if t.enchantments[key] then clamp(key, def) end end

    return t
end

function setFlaskReactivity(flask, reactivity)
    local comp = firstComponent(flask, MIC)
    cSet(comp, "do_reactions", reactivity.chance)
    cSet(comp, "reaction_speed", reactivity.speed)
end

function setFlaskDamageModelsAndPhysicsBodyDamage(flask, combined)
    local tempered = combined.enchantments.tempered or 0
    eachComponentSet(flask, PBCDC, nil, "damage_multiplier", (1 - tempered) * 0.016667)
    toggleComps(flask, "DamageModelComponent", nil, tempered == 0)
end

function setFlaskResult(flask, combined)
    setDescription(flask, describeFlask(combined))
    for key, level in pairs(combined.enchantments or {}) do enchants[key].apply(flask, level) end
    local msc = firstComponent(flask, MSC)
    cSet(msc, "barrel_size", combined.barrel_size)
    cSet(msc, "num_cells_sucked_per_frame", combined.num_cells_sucked_per_frame)

    local potion = firstComponent(flask, "PotionComponent")
    cSet(potion, "spray_velocity_coeff", combined.spray_velocity_coeff)
    cSet(potion, "spray_velocity_normalized_min", combined.spray_velocity_normalized_min)
    cSet(potion, "throw_how_many", combined.throw_how_many)
    cSet(potion, "dont_spray_just_leak_gas_materials", false)
    if combined.barrel_size > 10000 then cSet(potion, "throw_bunch", true) end
    local reactivity = reactivity(combined)
    setFlaskReactivity(flask, reactivity)
    setFlaskDamageModelsAndPhysicsBodyDamage(flask, combined)
    -- build the material component by first clearing it
    RemoveMaterialInventoryMaterial(flask)
    local function push(k, v) AddMaterialInventoryMaterial(flask, CellFactory_GetName(k), v) end
    for k, v in pairs(combined.materials or {}) do push(k, v) end
end
