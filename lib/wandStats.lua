local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

---@class WandStats
---@field fire_rate_wait integer[] -- gunaction_config
---@field reload_time integer[] -- gun_config
---@field spread_degrees integer[] -- gunaction_config
---@field deck_capacity integer[] -- gun_config
---@field mana_max integer[] -- no obj
---@field mana_charge_speed integer[] -- no obj
---@field shuffle_deck_when_empty integer[] -- gun_config abused boolean lol

---@class WandStatDef
---@field prop string
---@field obj string|nil
---@field formula string

---@type WandStatDef[]
local wandStatDefs = {
    { prop = "fire_rate_wait",          obj = "gunaction_config", formula = "min" },
    { prop = "reload_time",             obj = "gun_config",       formula = "min" },
    { prop = "spread_degrees",          obj = "gunaction_config", formula = "min" },
    { prop = "deck_capacity",           obj = "gun_config",       formula = "max" },
    { prop = "mana_max",                obj = nil,                formula = "loop" },
    { prop = "mana_charge_speed",       obj = nil,                formula = "loop" },
    { prop = "shuffle_deck_when_empty", obj = "gun_config",       formula = "min" },
}

function isWand(eid) return EntityHasTag(eid, "wand") end

function isWandEnhancer(eid) return isWand(eid) end

---Sets the result of the flask item in scope to the stats provided.
---@param wand entity_id
---@param wandStats WandStats|nil
function setWandResult(wand, wandStats)
    if not wandStats then return end
    local ability = firstComponent(wand, "AbilityComponent", nil)
    if not ability then return end
    for _, def in ipairs(wandStatDefs) do
        local pool = wandStats[def.prop]
        local value = pool[1]
        if def.prop == "shuffle_deck_when_empty" then value = (value == 1) end
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
        spread_degrees = {},
        shuffle_deck_when_empty = {}
    } ---@type WandStats
end

---Scrape the ability component for wand stats.
---@param wandStats WandStats|nil An existing wand stats or nil to create a new one.
---@param comp component_id An ability component id
function scrapeAbility(wandStats, comp)
    if wandStats == nil then wandStats = newWandStats() end
    for _, def in ipairs(wandStatDefs) do
        local innerObj = def.obj ~= nil and def.obj or "root"
        local value = nil
        if innerObj ~= "root" then
            value = cObjGet(comp, def.obj, def.prop)
        else
            value = cGet(comp, def.prop)
        end
        --thonk.about("def prop", def.prop, "value", value)
        if type(value) == "boolean" then value = value and 1 or 0 end
        table.insert(wandStats[def.prop], value)
    end
    return wandStats
end

---Scrape the stats out of a wand or holder's ability component(s)
---@param wandStats WandStats|nil an existing wandstats, or nil to create one.
---@param eid entity_id Any wand or holder with ability component(s)
---@return WandStats
function injectAbilityIntoWandStats(wandStats, eid)
    if wandStats == nil then wandStats = newWandStats() end
    local function scrape(_, comp) scrapeAbility(wandStats, comp) end
    eachEntityComponent(eid, "AbilityComponent", nil, scrape)
    return wandStats
end

---Scrape the stats out of a wand or holder's ability component(s)
---@param wandStats WandStats an existing wandstats
---@param allOfferingsStats WandStats[] All wands stats as an array of stats holders.
---@return WandStats
function injectWandStatsIntoWandStats(wandStats, allOfferingsStats)
    -- thonk.about("left wand", wandStats, "right wand(s)", allOfferingsStats)
    for _, def in ipairs(wandStatDefs) do
        for i, offeringStats in ipairs(allOfferingsStats) do
            local statPool = offeringStats[def.prop]
            if statPool then
                for _, stat in ipairs(statPool) do
                    table.insert(wandStats[def.prop], stat)
                end
            end
        end
    end
    return wandStats
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a 0 for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined WandStats
---@param upperAltar entity_id
---@param lowerAltar entity_id|nil
---@return WandStats|nil
function mergeWandStats(upperAltar, lowerAltar)
    local upperWandStats = holderWandStats(upperAltar)
    --thonk.about("upper altar wand holder stats", upperWandStats)
    if #upperWandStats == 0 then return nil end
    if not lowerAltar then return upperWandStats[1] end

    local offerings = holderWandStats(lowerAltar)
    --thonk.about("lower altar (offerings) wand holder stats", offerings)
    injectWandStatsIntoWandStats(upperWandStats[1], offerings)
    --thonk.about("results before blend", upperWandStats[1], "offerings before blend", offerings)

    local blended = blendWandStats(upperWandStats[1])

    --thonk.about("blended wand result", blended)
    return blended
end

---Take WandStats and blend each based on "formula"
---@param stats WandStats|nil
---@return WandStats|nil
function blendWandStats(stats)
    if not stats then return nil end
    local result = newWandStats()
    for _, def in ipairs(wandStatDefs) do
        local pool = stats[def.prop]
        -- really only necessary for asymmetric merging, but the impact is low
        -- as long as this isn't called excessively.
        table.sort(pool)
        -- thonk.about("pool of stats", pool, "merge strategy", def.formula)
        while #pool > 1 do
            local worst = table.remove(pool, 1)
            local next_worst = table.remove(pool, 1)
            if def.formula == "loop" then
                poolInject(pool, math.ceil(next_worst + ((worst / next_worst) ^ 0.5) * worst))
            elseif def.formula == "min" then
                poolInject(pool, math.min(worst, next_worst))
            elseif def.formula == "max" then
                poolInject(pool, math.max(worst, next_worst))
            end
        end
        -- thonk.about("stat", def.prop, "final stat value", pool[1])
        -- at this point only one result should be in each pool
        table.insert(result[def.prop], pool[1])
    end
    --thonk.about("blended stats", result)
    return result
end

---Given the result of some blend formula, inject the result back in the pool
---in ascending order (used exclusively by mana/charge which uses ascending asymmetric blending)
---@param pool table a table of result values left to be merged, when it has 1 value it's finished
---@param merged integer the last result we formulated, which we are injecting in ascending order
function poolInject(pool, merged)
    for i = 1, #pool do
        if merged < pool[i] then
            table.insert(pool, i, math.floor(merged))
            return
        end
    end
    -- if we reach this point we didn't insert
    pool[#pool + 1] = merged
end

---Store a wand's stats in a holder linking to the item.
---@param eid entity_id the wand being added to the altar
---@param hid entity_id the holder of the wand representative
function storeWandStats(eid, hid)
    --thonk.about("storing wand stats of", eid, "on holder", hid)
    --thonk.about("holder stored eid", storedInt(hid, "eid"))
    -- if the holder doesn't align DO NOT overwrite its stats
    if storedInt(hid, "eid") ~= eid then return end
    local ability = firstComponent(hid, "AbilityComponent", nil)
    --thonk.about("holder ability component exists?", ability ~= nil, "ability", ability)
    -- if the holder already has a stat block ALSO don't overwrite it.
    if ability then return end

    --thonk.about("storing wand stats from", eid, "on holder", holder)
    local stats = injectAbilityIntoWandStats(nil, eid)
    EntityAddComponent2(hid, "AbilityComponent", {}) -- create empty ability component
    setWandResult(hid, stats)                        -- set the empty ability component stats to be stored ones
end

---Gather all the wand stats belonging to holder children of the altar.
---These are the holder stats, NOT the wands they represent.
---@param altar entity_id the altar we want the stats of wands on
---@return WandStats[] result an array of ability components
function holderWandStats(altar)
    local holders = EntityGetAllChildren(altar) or {}
    local result = {}
    for _, child in ipairs(holders) do
        local ability = firstComponent(child, "AbilityComponent", nil)
        if ability then result[#result + 1] = scrapeAbility(nil, ability) end
    end
    return result
end
