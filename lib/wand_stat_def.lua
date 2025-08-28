local comp_util = dofile_once("mods/offerings/lib/component_utils.lua") ---@type offering_component_util
local util = dofile_once("mods/offerings/lib/utils.lua") ---@type offering_util

---@class offering_wand_stats
---@field gun_level number
---@field cost number
---@field actions_per_round number
---@field shuffle_deck_when_empty number
---@field deck_capacity number
---@field speed_multiplier number
---@field spread_degrees number
---@field fire_rate_wait number
---@field reload_time number
---@field mana_max number
---@field mana_charge_speed number

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
---| "cost"

---@class wand_stat_meta
---@field key wand_stat_key
---@field cObj? gun_object
---@field cost number
---@field min fun(gunLevel: number):number
---@field max fun(gunLevel: number):number
---@field base fun(gunLevel: number):number
---@field pull fun(self: wand_stat_meta, abilityComp: component_id):number
---@field push fun(self: wand_stat_meta, abilityComp: component_id, amount: number)
---@field clamp fun(self: wand_stat_meta, gunLevel: number, amount: number):number
---@field mix fun(self: wand_stat_meta, gunLevel: number, weights: number[]): (costOverflow: number, result: number)
---@field eval fun(self: wand_stat_meta, amount: number):number

---@class wand_stat_definition:wand_stat_meta
local meta = {}

---Insert a new wandStatDefinition into the table.
---@param t wand_stat_definition
---@return wand_stat_definition
function meta:new(t)
    local statDef = {
        key = assert(t.key, "Wand stat definition needs a key (component field)"),
        cost = assert(t.cost, "Wand stat definition needs a cost ratio"),
        cObj = t.cObj -- optional
    } ---@type wand_stat_definition
    meta[statDef.key] = statDef
    return setmetatable(statDef, self)
end

---Default method to obtain an object or unnested property of an ability comp in a wand.
---@param abilityComp component_id the ability component of the stat
---@return number
function meta:pull(abilityComp)
    return self.cObj and comp_util.cObjGet(abilityComp, self.cObj, self.key)
        or comp_util.cGet(abilityComp, self.key)
end

---Default method to obtain an object or unnested property of an ability comp in a wand.
---@param abilityComp component_id the ability component of the stat
---@param amount number the amount to set the value of the comp field to
function meta:push(abilityComp, amount)
    if self.cObj then
        comp_util.cObjSet(abilityComp, self.cObj, self.key, amount)
    else
        comp_util.cSet(abilityComp, self.key, amount)
    end
end

function meta:mix(gunLevel, weights)
    if self.cost == 0 then return 0, 0 end
    local overflow = 0
    local result = 0
    for _, weight in ipairs(weights) do
        result = result + weight / self.cost
    end
    local clamped = self.clamp(self, gunLevel, result)
    local delta = clamped - result
    if delta ~= 0 then overflow = delta * self.cost end
    return overflow, result
end

function meta:eval(amount) return amount / self.cost end

function meta:clamp(gunLevel, amount) return math.max(self.min(gunLevel), math.min(self.max(gunLevel), amount)) end

---@alias gun_object
---| "gunaction_config"
---| "gun_config"

---Create a wand stat definition with no min, max or functions
---@param key wand_stat_key The field of the stat, which is also it's key for lookups
---@param cost number The cost ratio of the stat, which represents its numeric weight
---@param min fun(gunLevel: number):number
---@param max fun(gunLevel: number):number
---@param base fun(gunLevel: number):number
---@param cObj? gun_object The object the key resides in, if it resides in gunaction_config|gun_config
function meta:makeDef(key, cost, min, max, base, cObj)
    return self:new({ key = key, cObj = cObj, cost = cost, min = min, max = max, base = base })
end

-- reminders
-- ---| "actions_per_round"
-- ---| "reload_time"
-- ---| "deck_capacity"
-- ---| "shuffle_deck_when_empty"
-- ---| "fire_rate_wait"
-- ---| "spread_degrees"
-- ---| "speed_multiplier"
-- ---| "mana_charge_speed"
-- ---| "mana_max"
-- ---| "gun_level"
-- ---| "cost"

local function ramp(startLevel, factor, offset)
    local function rampFunction(gunLevel)
        if gunLevel >= startLevel then return gunLevel * factor + offset end
        return offset
    end
    return rampFunction
end

meta:makeDef("gun_level", 100, ramp(0, 0))