dofile_once("mods/offerings/lib/math.lua")

--== WAND MERGING ==--
local wandStatDefs = {
    { prop = "fire_rate_wait",    obj = "gunaction_config", formula = "min" },
    { prop = "reload_time",       obj = "gun_config",       formula = "min" },
    { prop = "spread_degrees",    obj = "gunaction_config", formula = "min" },
    { prop = "deck_capacity",     obj = "gun_config",       formula = "max" },
    { prop = "mana_max",          obj = nil,                formula = "loop" },
    { prop = "mana_charge_speed", obj = nil,                formula = "loop" }
}
local VSC = "VariableStorageComponent"
local originalStats = "original_stats_"
function og(def) return originalStats .. def.prop end
local function prefOg(s) return originalStats .. s end
local OG = #prefOg("")
local function unprefix(s, n) return s:sub(n + 1) end
local function unprefOg(s) return unprefix(s, OG) end

function combineWands(upperAltar, lowerAltar, isRestore)
    debugOut("is restoring og wand? " .. tostring(isRestore))
    local original = originalWand(upperAltar)
    if not original then return {} end

    local offeredWandsStats = isRestore and {} or offeringWandStats(lowerAltar)

    local combined = {}  -- final result
    local clustered = {} -- clustered by name for loop formulas
    for _, stat in ipairs(original) do
        local unprefName = unprefOg(stat.name)
        if clustered[unprefName] == nil then clustered[unprefName] = {} end
        table.insert(clustered[unprefName], stat.value_int)
    end

    for key, value in pairs(clustered) do
        debugOut(key .. " of cluster values")
        if type(value) == "table" then
            for i, v in ipairs(value) do
                debugOut("item " .. i .. " " .. tostring(v))
            end
        else
            debugOut(key .. " is not a table?!")
        end
    end

    for _, wandStats in ipairs(offeredWandsStats) do
        for _, stat in ipairs(wandStats) do
            clustered[stat.name][#clustered[stat.name] + 1] = stat.value_int
        end
    end

    for _, def in ipairs(wandStatDefs) do
        local values = clustered[def.prop] or {}
        local final = def.formula == "min" and math.huge or -math.huge
        debugOut("wand stats in clustered props " .. def.prop)
        if def.formula == "min" then
            for i, v in ipairs(values) do
                final = math.min(final, v)
                debugOut(i .. ". " .. v)
            end
        elseif def.formula == "max" then
            for i, v in ipairs(values) do
                final = math.max(final, v)
                debugOut(i .. ". " .. v)
            end
        elseif def.formula == "loop" then
            final = loopBlend(values)
        end
        debugOut("Result: " .. final)
        combined[#combined + 1] = { name = def, value = round(final, 0) }
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

function abilityComponent(wand) return firstComponent(wand, "AbilityComponent", nil) end

function setWandResult(wand, combined)
    local ability = abilityComponent(wand)
    for _, entry in ipairs(combined) do
        for _, def in ipairs(wandStatDefs) do
            if def.prop == entry.name then
                if def.obj then
                    cObjSet(ability, def.obj, entry.name, entry.value)
                else
                    cSet(ability, entry.name, entry.value)
                end
                break
            end
        end
    end
end

function memorizeWand(altar, wand)
    clearOriginalStats(altar)
    for _, stat in ipairs(scrapeWandStats(wand)) do
        storeInt(altar, originalStats .. stat.name, stat.value_int)
    end
end

function originalWand(altar)
    return storedsLike(altar, originalStats, false, "value_int", false)
end

function scrapeWandStats(wand)
    local ability = abilityComponent(wand)
    local result = {}
    for _, def in ipairs(wandStatDefs) do
        local innerObj = def.obj ~= nil and def.obj or "root"
        local value = innerObj ~= "root" and cObjGet(ability, def.obj, def.prop) or cGet(ability, def.prop)
        result[#result + 1] = { name = def.prop, value_int = value }
    end
    return result
end

function offeringWandStats(lowerAltar)
    local stats = {}
    for _, wand in ipairs(wands(lowerAltar)) do stats[#stats + 1] = scrapeWandStats(wand) end
    return stats
end
