---@class WandStats
---@field fire_rate_wait integer[] -- gunaction_config
---@field reload_time integer[] -- gun_config
---@field spread_degrees integer[] -- gunaction_config
---@field deck_capacity integer[] -- gun_config
---@field mana_max integer[] -- no obj
---@field mana_charge_speed integer[] -- no obj

---@class WandStatDef
---@field prop string
---@field obj string|nil
---@field formula string

---@type WandStatDef[]
local wandStatDefs = {
    { prop = "fire_rate_wait",    obj = "gunaction_config", formula = "min" },
    { prop = "reload_time",       obj = "gun_config",       formula = "min" },
    { prop = "spread_degrees",    obj = "gunaction_config", formula = "min" },
    { prop = "deck_capacity",     obj = "gun_config",       formula = "max" },
    { prop = "mana_max",          obj = nil,                formula = "loop" },
    { prop = "mana_charge_speed", obj = nil,                formula = "loop" }
}

function setWandResult(wand, wandStats)
    local ability = firstComponent(wand, "AbilityComponent", nil)
    for i = 1, #wandStatDefs do
        local def = wandStatDefs[i]
        local pool = wandStats[def.prop]
        local value = pool[1]
        if def.obj then
            cObjSet(ability, def.obj, def.prop, value)
        else
            cSet(ability, def.prop, value)
        end
    end
end

---Returns an empty wand stat table to work on
---@return WandStats
function newWandStats()
    return {
        fire_rate_wait = {},
        deck_capacity = {},
        mana_charge_speed = {},
        mana_max = {},
        reload_time = {},
        spread_degrees = {}
    }
end

---Scrape the ability component for wand stats.
---@param wandStats WandStats|nil An existing wand stats or nil to create a new one.
---@param comp number An ability component id
function scrapeAbility(wandStats, comp)
    if wandStats == nil then wandStats = newWandStats() end
    for _, def in ipairs(wandStatDefs) do
        local innerObj = def.obj ~= nil and def.obj or "root"
        local value = innerObj ~= "root" and cObjGet(comp, def.obj, def.prop) or cGet(comp, def.prop)
        table.insert(wandStats[def.prop], value)
    end
    return wandStats
end

---Scrape the stats out of a wand or holder's ability component(s)
---@param wandStats WandStats|nil an existing wandstats, or nil to create one.
---@param eid integer Any wand or holder with ability component(s)
---@return WandStats
function injectAbilityIntoWandStats(wandStats, eid)
    if wandStats == nil then wandStats = newWandStats() end
    local function scrape(_, comp) scrapeAbility(wandStats, comp) end
    eachEntityComponent(eid, "AbilityComponent", nil, scrape)
    return wandStats
end

---Scrape the stats out of a wand or holder's ability component(s)
---@param wandStats WandStats an existing wandstats
---@param injectedStats WandStats Any wand or holder with ability component(s)
---@return WandStats
function injectWandStatsIntoWandStats(wandStats, injectedStats)
    for key, _ in pairs(wandStatDefs) do
        for i = 1, #injectedStats[key] do
            table.insert(wandStats[key], injectedStats[key][i])
        end
    end
    return wandStats
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a 0 for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined WandStats
---@param upperAltar number
---@param lowerAltar number
---@return WandStats
function mergeWandStats(upperAltar, lowerAltar)
    local result = holderWandStats(upperAltar)[1]
    if lowerAltar == 0 then return result end

    local offerings = holderWandStats(lowerAltar)
    injectWandStatsIntoWandStats(result, offerings)
    return blend(result)
end

---Take WandStats and blend each based on "formula"
---@param stats WandStats
---@return WandStats
function blend(stats)
    local result = newWandStats()
    for i = 1, #wandStatDefs do
        local def = wandStatDefs[i]
        local values = stats[def.prop]
        local pool = { unpack(values) }
        -- really only necessary for asymmetric merging, but the impact is low
        -- as long as this isn't called excessively.
        table.sort(pool)
        while #pool > 1 do
            local worst = table.remove(pool, 1)
            local next_worst = table.remove(pool, 1)
            if def == "loop" then
                poolInject(pool, next_worst + ((worst / next_worst) ^ 0.5) * worst)
            elseif def == "min" then
                poolInject(pool, math.min(worst, next_worst))
            elseif def == "max" then
                poolInject(pool, math.max(worst, next_worst))
            end
        end
        -- at this point only one result should be in each pool
        table.insert(result[def.prop], pool[1])
    end
    return result
end

---Given the result of some blend formula, inject the result back in the pool
---in ascending order (used exclusively by mana/charge which uses ascending asymmetric blending)
---@param pool table a table of result values left to be merged, when it has 1 value it's finished
---@param merged integer the last result we formulated, which we are injecting in ascending order
function poolInject(pool, merged)
    for i = 1, #pool do
        if merged < pool[i] then
            table.insert(pool, i, merged)
            return
        end
    end
    -- if we reach this point we didn't insert
    pool[#pool + 1] = merged
end

---Store a wand's stats in a holder linking to the item.
---@param altar number the altar holding the item
---@param eid number the wand being added to the altar
function storeWandStats(altar, eid)
    local stats = injectAbilityIntoWandStats(nil, eid)
    local holder = link(altar, eid)
    EntityAddComponent2(holder, "AbilityComponent", {})
    setWandResult(holder, stats)
end

---Gather all the wand stats belonging to holder children of the altar.
---@param altar number the altar we want the stats of wands on
---@return number[] result an array of ability components
function holderWandAbilities(altar)
    local holders = EntityGetAllChildren(altar) or {}
    local result = {}
    for i = 1, #holders do
        local child = holders[i]
        local ability = firstComponent(child, "AbilityComponent", nil)
        result[#result + 1] = ability
    end
    return result
end

---Gather all the wand stats belonging to holder children of the altar.
---@param altar number the altar we want the stats of wands on
---@return WandStats[] result an array of wand stats
function holderWandStats(altar)
    local abilities = holderWandAbilities(altar)
    local result = {}
    for i = 1, #abilities do
        local ability = abilities[i]
        result[#result + 1] = scrapeAbility(nil, ability)
    end
    return result
end
