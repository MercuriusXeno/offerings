
--== WAND MERGING ==--


local wandStatDefs = {
    {
        property = "fire_rate_wait",
        object = "gunaction_config",
        var_field = "value_int",
        formula = "min"
    },
    {
        property = "reload_time",
        object = "gun_config",
        var_field = "value_int",
        formula = "min"
    },
    {
        property = "mana_max",
        object = nil,
        var_field = "value_int",
        formula = "loop"
    },
    {
        property = "mana_charge_speed",
        object = nil,
        var_field = "value_int",
        formula = "loop"
    },
    {
        property = "spread_degrees",
        object = "gunaction_config",
        var_field = "value_int",
        formula = "min"
    },
    {
        property = "deck_capacity",
        object = "gun_config",
        var_field = "value_int",
        formula = "max"
    }
}

---Return the stats of all wands on offer combined with the reserve wand stats.
---@param target_altar_id any
---@param offer_altar_id any
---@return table
function combinedWands(target_altar_id, offer_altar_id)
    local target_stats = Get_Reserved_Wand_Stats(target_altar_id)
    local offering_stats_list = offeringWandStats(offer_altar_id)
    return Combine_Wand_Stats(target_stats, offering_stats_list)
end

---Get and humanely display the combined stats of the result wand for debugging.
---@param target_altar_id any
---@param offer_altar_id any
function printWandStats(target_altar_id, offer_altar_id)
    local combined_stats = combinedWands(target_altar_id, offer_altar_id)
    --STUB
end

---Combine the stats from target + offerings into a new stat table
---@param target_stats table
---@param offering_stats_list table[]
---@return table
function Combine_Wand_Stats(target_stats, offering_stats_list)
    local combined_stats = {}
    local all_stats_by_name = {}

    -- Step 1: flatten all stats into stat_name → list of values
    for _, stat in ipairs(target_stats) do
        all_stats_by_name[stat.name] = { stat.value_int }
    end

    for _, stats in ipairs(offering_stats_list) do
        for _, stat in ipairs(stats) do
            local list = all_stats_by_name[stat.name]
            if list then
                list[#list + 1] = stat.value_int
            end
        end
    end

    -- Step 2: apply combination logic based on stat kind
    for _, def in ipairs(wandStatDefs) do
        local name = def.property
        local values = all_stats_by_name[name] or {}

        local final = nil
        if #values > 0 then
            if def.formula == "min" then
                final = math.huge
                for _, v in ipairs(values) do
                    final = math.min(final, v)
                end
            elseif def.formula == "max" then
                final = -math.huge
                for _, v in ipairs(values) do
                    final = math.max(final, v)
                end
            elseif def.formula == "loop" then
                final = Blend_Stat_Loop(values)
            end

            if final then
                combined_stats[#combined_stats + 1] = {
                    name = name,
                    value_int = math.floor(final + 0.5), -- round
                    _tags = target_stat_buffer
                }
            end
        end
    end

    return combined_stats
end

---Blends mana/regen using recursive loop algorithm
---@param values number[]
---@return number
function Blend_Stat_Loop(values)
    local unpack = unpack or table.unpack -- 5.1 v 5.2ism
    local pool = { unpack(values) }

    -- Sort ascending (worst to best)
    table.sort(pool)

    while #pool > 1 do
        local worst = table.remove(pool, 1)
        local next_worst = table.remove(pool, 1)
        local result = next_worst + ((worst / next_worst) ^ 0.5) * worst

        -- insert result back into sorted position
        local inserted = false
        for i = 1, #pool do
            if result < pool[i] then
                table.insert(pool, i, result)
                inserted = true
                break
            end
        end
        if not inserted then
            pool[#pool + 1] = result
        end
    end

    return pool[1] -- final result
end

function setWandResult(wand_id, stats_table)
    local abilities = abilityComponent(wand_id)

    for _, entry in ipairs(stats_table) do
        local name = entry.name
        local value = entry.value_int

        -- Match stat against wand_stats definition
        for _, def in ipairs(wandStatDefs) do
            if def.property == name then
                if def.object then
                    ComponentObjectSetValue2(abilities, def.object, name, value)
                else
                    ComponentSetValue2(abilities, name, value)
                end
                break
            end
        end
    end
end

---Reserves the wand stats of a target wand. Used when the player first puts it on the target altar.
---@param altar_id integer
---@param wand_id integer
function storeWandStats(altar_id, wand_id)
    clearOriginalStats(altar_id)

    local stats = wandStats(wand_id)
    if not stats then return end

    for _, stat in ipairs(stats) do
        EntityAddComponent2(altar_id, "VariableStorageComponent", stat)
    end
end

---Retrieve the reserved stats previously stored on the altar
---@param altar_id integer
---@return table
function Get_Reserved_Wand_Stats(altar_id)
    local result = {}
    local comps = EntityGetComponent(altar_id, "VariableStorageComponent") or {}
    for _, comp in ipairs(comps) do
        if ComponentHasTag(comp, target_stat_buffer) then
            result[#result + 1] = {
                name = ComponentGetValue2(comp, "name"),
                value_int = ComponentGetValue2(comp, "value_int"),
                _tags = target_stat_buffer
            }
        end
    end
    return result
end

function wandStats(wand)
    local ability = firstComponent(wand, "AbilityComponent")
    local result = {}
    for _, statDef in ipairs(wandStatDefs) do
        local value = statDef.object and cObj(ability, statDef.object, statDef.property)
            or cGet(ability, statDef.property)
        result[#result + 1] = { name = originalStats .. statDef.property, value_int = value }
    end
    return result
end

function offeringWandStats(lowerAltar)
    local stats = {}
    for _, wand in ipairs(wands(lowerAltar)) do stats[#stats + 1] = wandStats(wand) end
    return stats
end