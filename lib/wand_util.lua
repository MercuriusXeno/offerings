local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util
---@class wand_stats:{[wand_stat_key]: number}

---@alias wand_stat_key
---| "actions_per_round"
---| "reload_time"
---| "deck_capacity"
---| "shuffle_deck_when_empty"
---| "fire_rate_wait"
---| "spread_degrees"
---| "speed_multiplier"
---| "mana_charge_speed"
---| "mana_max"
---| "gun_level"

local key_map = {
    actions_per_round = "actions_per_round",
    reload_time = "reload_time",
    deck_capacity = "deck_capacity",
    shuffle_deck_when_empty = "shuffle_deck_when_empty",
    fire_rate_wait = "fire_rate_wait",
    spread_degrees = "spread_degrees",
    speed_multiplier = "speed_multiplier",
    mana_charge_speed = "mana_charge_speed",
    mana_max = "mana_max",
    gun_level = "gun_level"
} ---@type {[string]: wand_stat_key}

local key_array = {
    key_map.gun_level,
    key_map.mana_max,
    key_map.mana_charge_speed,
    key_map.deck_capacity,
    key_map.actions_per_round,
    key_map.reload_time,
    key_map.fire_rate_wait,
    key_map.spread_degrees,
    key_map.speed_multiplier,
    key_map.shuffle_deck_when_empty
} ---@type wand_stat_key[]

---@class bounds
---@field min number
---@field max number
---@field base number

---@class wand_stat_def
---@field key wand_stat_key
---@field cObj? gun_object
---@field min number
---@field max number
---@field base number
---@field inverted boolean
---@field step_size number
---@field growth number
---@field perfect number
---@field total_perfection_cost number
---@field base_cost number?

local stat_def_mt = {} ---@class wand_stat_def
stat_def_mt.__index = stat_def_mt

local wand_util = {} ---@class wand_util:{[wand_stat_key]: wand_stat_def}

---Default method to obtain an object or unnested property of an ability comp in a wand.
---@param abilityComp component_id the ability component of the stat
---@return number
function stat_def_mt:pull(abilityComp)
    local result = 0
    if self.cObj then
        result = comp_util.get_component_object_value(abilityComp, self.cObj, self.key)
    else
        result = comp_util.get_component_value(abilityComp, self.key)
    end
    if type(result) == "boolean" then
        if result then result = 1 else result = 0 end
    end
    return result
end

---Default method to obtain an object or unnested property of an ability comp in a wand.
---@param abilityComp component_id the ability component of the stat
---@param amount number the amount to set the value of the comp field to
function stat_def_mt:push(abilityComp, amount)
    local value = amount ---@type number|boolean
    if self.key == key_map.shuffle_deck_when_empty then value = (value == 1) end
    if self.cObj then
        comp_util.set_component_object_value(abilityComp, self.cObj, self.key, value)
    else
        comp_util.set_component_value(abilityComp, self.key, value)
    end
end

---Sets the stats (ability component) of the
---entity provided to be the stats passed in.
---@param wand entity_id
---@param wandStats? wand_stats
function wand_util:set_wand_result(wand, wandStats)
    if not wandStats then return end
    local ability = comp_util.first_component(wand, "AbilityComponent", nil)
    if not ability then return end
    for _, key in ipairs(key_array) do
        local d = self[key]
        d:push(ability, wandStats[key])
    end
end

---Returns an empty wand stat table to work on
---@return wand_stats
function wand_util:make_stats()
    local stats = {} ---@type wand_stats
    for _, k in ipairs(key_array) do
        local d = self[k]
        stats[k] = d.base
    end
    return stats
end

---Scrape the ability component for wand stats.
---@param eid entity_id Any wand or holder with ability component(s)
---@return wand_stats
function wand_util:convert_to_wand_stats(eid)
    local comp = comp_util.first_component(eid, "AbilityComponent", nil)
    local result = self:make_stats()
    if not comp then return result end
    for _, key in ipairs(key_array) do
        local def = self[key]
        local value = def:pull(comp)
        if type(value) == "boolean" then value = value and 1 or 0 end
        result[key] = value
    end
    return result
end

---Returns the clamped amount of a stat based on its min and max
---@param amount number the number to clamp by the cfg min and max
---@return number the clamped amount after applying the stat def min and max
function stat_def_mt:clamp(amount)
    return math.max(self.min, math.min(self.max, amount))
end

--- Compute signed steps from base toward perfection a given
--- value has already taken, without clamping.
function stat_def_mt:steps_from_value(value)
    local delta_from_base = self.inverted and (self.base - value) or (value - self.base)
    return delta_from_base / self.step_size
end

---Determine the "cost value" of a signed step count. Preserves direction of steps.
---@param signed_steps number the positive or negative steps toward [or away] from perfection
---@return number The area under the curve representing the cumulative value of the steps
function stat_def_mt:area_under_curve_of_steps(signed_steps)
    local adjusted_growth = self.growth - 1.0
    local sign = (signed_steps < 0) and -1 or 1
    local steps = signed_steps * sign
    local linear_growth = 1.0 - 0.5 * adjusted_growth
    local result = (linear_growth * steps + 0.5 * adjusted_growth * steps * steps)
    --- diminish the impact of negative results slightly
    if (sign < 0) then result = math.pow(result, 0.9) end
    return result * sign
end

function stat_def_mt:area_under_curve_of_value(value)
    return self:area_under_curve_of_steps(self:steps_from_value(value))
end

---Solves the base_cost of a wand stat by computing the area under the curve
---marching from self.base toward self.perfect, with a cost of total_perfection_cost
---which gets divided by the number of steps, accounting for growth, in the stat def.
---@return number
function stat_def_mt:solve_base_cost()
    local adjusted_growth = self.growth - 1.0
    if self.base_cost then return self.base_cost end
    local steps_to_perfect =
        (self.inverted and (self.base - self.perfect) or (self.perfect - self.base))
        / self.step_size -- should be > 0 by construction
    local linear_growth = 1.0 - 0.5 * adjusted_growth
    local area_to_perfect =
        linear_growth * steps_to_perfect + 0.5 * adjusted_growth * steps_to_perfect ^ 2
    self.base_cost = self.total_perfection_cost / area_to_perfect
    return self.base_cost
end

---Solves the cost-worth of the stat value based on the math of a stat-def.
---@param val number The stat value we want the worth of
---@return number the worth of the stat based on config factors.
function stat_def_mt:worth_from_value(val)
    return self.base_cost * self:area_under_curve_of_value(val)
end

---Turns a number with decimal precision into a string truncated to 2 decimal places at most.
---@param n number some number
---@return string the cleaned up number
local function pretty(n) return tostring(math.floor(n * 100) / 100) end

function stat_def_mt:value_from_worth(worth)
    local adjusted_growth = self.growth - 1.0
    -- specifically mana and charge are linear and we don't want to divide by zero.
    -- if other things change to linear this guards against dumb.
    local result = 0
    if adjusted_growth == 0 then
        local unsigned_worth = math.abs(worth)
        local steps_from_base = (unsigned_worth / self.base_cost)
        local distance = steps_from_base * self.step_size
        local direction_flip = (self.inverted == (worth < 0)) and 1 or -1
        local unclamped_result = self.base + direction_flip * distance
        result = self:clamp(unclamped_result)
    else
        local unsigned_worth = math.abs(worth)
        local linear_growth = 1.0 - 0.5 * adjusted_growth
        local area = unsigned_worth / self.base_cost
        local quadratic_term = linear_growth ^ 2 + 2.0 * adjusted_growth * area
        local steps_from_base = (-linear_growth + math.sqrt(quadratic_term)) / adjusted_growth
        local distance = steps_from_base * self.step_size
        local direction_flip = (self.inverted == (worth < 0)) and 1 or -1
        local unclamped_result = self.base + direction_flip * distance
        result = self:clamp(unclamped_result)
    end
    return result
end

---Insert a new wandStatDefinition into the table.
---@param t wand_stat_def
---@return wand_stat_def
function stat_def_mt:new(t)
    assert(t.key, "Wand stat definition needs a key (component field)")
    assert(t.min, "Wand stat definition needs min")
    assert(t.max, "Wand stat definition needs max")
    assert(t.base ~= nil, "Wand stat definition needs base")
    assert(t.step_size, "Wand stat definition needs delta")
    assert(t.growth, "Wand stat definition needs growth")
    assert(t.perfect ~= nil, "Wand stat definition needs perfect")
    assert(t.total_perfection_cost ~= nil, "Wand stat definition needs cost")
    assert(t.inverted ~= nil, "Wand stat definition needs inverted")

    local stat_definition = {
        key = t.key,
        cObj = t.cObj,
        min = t.min,
        max = t.max,
        base = t.base,
        inverted = t.inverted,
        step_size = t.step_size,
        growth = t.growth,
        perfect = t.perfect,
        total_perfection_cost = t.total_perfection_cost,
    } ---@type wand_stat_def
    setmetatable(stat_definition, stat_def_mt)
    wand_util[stat_definition.key] = stat_definition
    return stat_definition
end

---Scrape the stats out of a wand or holder's ability component(s)
---@param stats wand_stats an existing wandstats
---@param offerings wand_stats[] All wands stats as an array of stats holders.
---@return wand_stats
function wand_util:collapse_stat_sums(stats, offerings)
    for _, key in ipairs(key_array) do
        local def = self[key]
        local worth = def:worth_from_value(stats[key])
        for _, offer in ipairs(offerings) do
            worth = worth + def:worth_from_value(offer[key])
        end
        stats[key] = def:value_from_worth(worth)
    end
    return stats
end

---Gather all the wand stats belonging to holder children of the altar.
---These are the holder stats, NOT the wands they represent.
---@param altar entity_id the altar we want the stats of wands on
---@return wand_stats[] result an array of wand stats
function wand_util:holder_wand_stats_from_altar(altar)
    local holders = EntityGetAllChildren(altar) or {}
    local result = {}
    for _, child in ipairs(holders) do
        result[#result + 1] = self:convert_to_wand_stats(child)
    end
    return result
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a 0 for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined WandStats
---@param upper_altar entity_id
---@param lower_altar entity_id|nil
---@return wand_stats|nil
function wand_util:merge_wand_stats(upper_altar, lower_altar)
    local upper_wand_stats = self:holder_wand_stats_from_altar(upper_altar)
    if #upper_wand_stats == 0 then return nil end
    if not lower_altar then return upper_wand_stats[1] end

    local offerings = self:holder_wand_stats_from_altar(lower_altar)
    local blended = self:collapse_stat_sums(upper_wand_stats[1], offerings)
    return blended
end

---Store a wand's stats in a holder linking to the item.
---@param eid entity_id the wand being added to the altar
---@param hid entity_id the holder of the wand representative
function wand_util:set_holder_wand_stats(eid, hid)
    -- if the holder doesn't align DO NOT overwrite its stats
    if comp_util.get_int(hid, "eid") ~= eid then return end
    -- we don't care to do anything with it, just ensure it exists
    local _ = comp_util.get_or_create_comp(hid, "AbilityComponent", nil)
    local stats = self:convert_to_wand_stats(eid)
    -- set the empty ability component stats to be stored ones
    self:set_wand_result(hid, stats)
end

---@alias gun_object
---| "gunaction_config"
---| "gun_config"

local config_types = {
    card = "gunaction_config",
    gun = "gun_config"
} ---@type {[string]: gun_object}

---@class wand_stat_math
---@field name wand_stat_key
---@field min number the lowest value the stat can have (not necessarily worst)
---@field max number the highest value the stat can have (not necessarily best)
---@field base number where the stat starts on the spectrum of good/bad
---@field inverted boolean whether the step is negative or positive direction when defining "better"
---@field delta number the step distance of a step toward "good"
---@field growth number the growth factor of each step, if applicable.
---@field perfect number the perfection anchor
---@field total_cost_of_perfection number to solve for "base to anchor" perfection cost in steps

-- stat configs, which we bake into defs
---@type {[wand_stat_key]: wand_stat_math}
local stat_configs = {
    gun_level = {
        name = "gun_level",
        min = 1,
        max = 15,
        base = 1,
        inverted = false,
        delta = 1.0,
        growth = 10.0,
        perfect = 15,
        total_cost_of_perfection = 30000,
    },
    actions_per_round = {
        name = "actions_per_round",
        min = 1,
        max = 26,
        base = 1,
        inverted = false,
        delta = 1.0,
        growth = 2.0,
        perfect = 26,
        total_cost_of_perfection = 16000,
    },
    deck_capacity = {
        name = "deck_capacity",
        min = 1,
        max = 26,
        base = 1,
        inverted = false,
        delta = 1.0,
        growth = 2.0,
        perfect = 26,
        total_cost_of_perfection = 16000.0,
    },
    shuffle_deck_when_empty = {
        name = "shuffle_deck_when_empty",
        min = 0,
        max = 1,
        base = 1,
        inverted = true,
        delta = 1.0,
        growth = 1.0,
        perfect = 0,
        total_cost_of_perfection = 300.0,
    },
    reload_time = {
        name = "reload_time",
        min = -240.0,
        max = 240.0,
        base = 30.0,
        inverted = true,
        delta = 1.0,
        growth = 1.4,
        perfect = -240.0,
        total_cost_of_perfection = 12000.0
    },
    speed_multiplier = {
        name = "speed_multiplier",
        min = 0.9,
        max = 10.0,
        base = 0.9,
        inverted = false,
        delta = 0.01,
        growth = 1.8,
        perfect = 10.0,
        total_cost_of_perfection = 18400.0
    },
    spread_degrees = {
        name = "spread_degrees",
        min = -1080.0,
        max = 1080.0,
        base = 8.0,
        inverted = true,
        delta = 1.0,
        growth = 1.6,
        perfect = -1440.0,
        total_cost_of_perfection = 10960.0
    },
    fire_rate_wait = {
        name = "fire_rate_wait",
        min = -240.0,
        max = 240.0,
        base = 8.0,
        inverted = true,
        delta = 1.0,
        growth = 1.4,
        perfect = -240.0,
        total_cost_of_perfection = 10240.0
    },
    mana_max = {
        name = "mana_max",
        min = 0,
        max = 1e9,
        base = 0,
        inverted = false,
        delta = 1.0,
        growth = 1.0025,
        perfect = 1e9,
        total_cost_of_perfection = 1e10
    },
    mana_charge_speed = {
        name = "mana_charge_speed",
        min = 0,
        max = 1e9,
        base = 0,
        inverted = false,
        delta = 1.0,
        growth = 1.005,
        perfect = 1e9,
        total_cost_of_perfection = 1e10
    },
}

-- cache this module across frames/runs
local MODULE_CACHE_KEY = "__offerings_wand_util"
local cached = rawget(_G, MODULE_CACHE_KEY)
if cached then return cached end

---Create a wand stat definition with no min, max or functions
---@param key wand_stat_key The field of the stat, which is also it's key for lookups
---@param cObj? gun_object The object the key resides in, if it resides in gunaction_config|gun_config
---@return wand_stat_def result
function wand_util:make_wand_stat_definition(key, cObj)
    local stat_math = stat_configs[key]
    assert(stat_math, ("Missing stat config for key '%s'"):format(key))
    local result = stat_def_mt:new({
        key = key,
        cObj = cObj,
        min = stat_math.min,
        max = stat_math.max,
        base = stat_math.base,
        inverted = stat_math.inverted,
        step_size = stat_math.delta,
        growth = stat_math.growth,
        perfect = stat_math.perfect,
        total_perfection_cost = stat_math.total_cost_of_perfection,
    })
    result.base_cost = result:solve_base_cost()
    return result
end

-- these are the normal stats with math bounds
wand_util:make_wand_stat_definition(key_map.actions_per_round, config_types.gun)
wand_util:make_wand_stat_definition(key_map.shuffle_deck_when_empty, config_types.gun)
wand_util:make_wand_stat_definition(key_map.deck_capacity, config_types.gun)
wand_util:make_wand_stat_definition(key_map.reload_time, config_types.gun)
wand_util:make_wand_stat_definition(key_map.speed_multiplier, config_types.card)
wand_util:make_wand_stat_definition(key_map.spread_degrees, config_types.card)
wand_util:make_wand_stat_definition(key_map.fire_rate_wait, config_types.card)
wand_util:make_wand_stat_definition(key_map.gun_level)
wand_util:make_wand_stat_definition(key_map.mana_max)
wand_util:make_wand_stat_definition(key_map.mana_charge_speed)

return wand_util
