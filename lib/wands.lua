dofile_once("mods/offerings/lib/math.lua")

--== WAND MERGING ==--
local wandStatDefs = {
    { prop = "fire_rate_wait",    obj = "gunaction_config", formula = "min" },
    { property = "reload_time",       object = "gun_config",       formula = "min" },
    { property = "spread_degrees",    object = "gunaction_config", formula = "min" },
    { property = "deck_capacity",     object = "gun_config",       formula = "max" },
    { property = "mana_max",          object = nil,                formula = "loop" },
    { property = "mana_charge_speed", object = nil,                formula = "loop" }
}
local VSC = "VariableStorageComponent"
local originalStats = "original_stats_"
function og(def) return originalStats .. def.property end

function combinedWands(upperAltar, lowerAltar)
    local original = originalWand(upperAltar)
    local offeredWandsStats = offeringWandStats(lowerAltar)

    local combined = {}  -- final result
    local clustered = {} -- clustered by name for loop formulas
    for _, stat in ipairs(original) do clustered[stat.name] = { stat.value_int } end

    for _, wandStats in ipairs(offeredWandsStats) do
        for _, stat in ipairs(wandStats) do
            clustered[stat.name][#clustered[stat.name] + 1] = stat.value_int
        end
    end

    for _, def in ipairs(wandStatDefs) do
        local values = clustered[def.prop] or {}
        local final = def.formula == "min" and math.huge or -math.huge
        if def.formula == "min" then
            for _, v in ipairs(values) do final = math.min(final, v) end
        elseif def.formula == "max" then
            for _, v in ipairs(values) do final = math.max(final, v) end
        elseif def.formula == "loop" then
            final = loopBlend(values)
        end
        combined[#combined + 1] = { def = def, value = round(final, 0) }
    end
    return combined
end

function loopBlend(values)
    local pool = { unpack(values) }
    table.sort(pool)
    while #pool > 1 do
        local worst = table.remove(pool, 1)
        local next_worst = table.remove(pool, 1)
        local result = next_worst + ((worst / next_worst) ^ 0.5) * worst
        local inserted = false
        for i = 1, #pool do
            if result < pool[i] then
                table.insert(pool, i, result)
                inserted = true
                break
            end
        end
        if not inserted then pool[#pool + 1] = result end
    end
    return pool[1]
end

function abilityComponent(wand) return firstComponent(wand, "AbilityComponent") end

function setWandResult(wand, combined)
    local ability = abilityComponent(wand)
    for _, entry in ipairs(combined) do
        for _, def in ipairs(wandStatDefs) do
            if def.prop == entry.name then
                if def.obj then cObjSet(ability, def.obj, entry.name, entry.value)
                else cSet(ability, entry.name, entry.value) end
                break
            end
        end
    end
end

function memorizeWand(altar, wand)
    clearOriginalStats(altar)
    for _, stat in ipairs(wandStats(wand)) do
        storeInt(altar, stat.name, stat.value_int)
    end
end

function originalWand(altar)
    local result = {}
    local function push(comp) result[#result+1] = { name = cGet(comp, "name"), value = cGet(comp, "value_int")} end
    eachEntityComponentLike(altar, VSC, nil, "name", originalStats, push)
    return result
end

function wandStats(wand)
    local ability = abilityComponent(wand)
    local result = {}
    for _, def in ipairs(wandStatDefs) do
        local value = def.obj and cObjGet(ability, def.obj, def.prop) or cGet(ability, def.prop)
        result[#result + 1] = { def = def, val = value }
    end
    return result
end

function offeringWandStats(lowerAltar)
    local stats = {}
    for _, wand in ipairs(wands(lowerAltar)) do stats[#stats + 1] = wandStats(wand) end
    return stats
end
