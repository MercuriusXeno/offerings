local comp_util = dofile_once("mods/offerings/lib/comp_util.lua") ---@type offering_component_util
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util
dofile_once("data/scripts/gun/procedural/wands.lua") 

---@class wand_stats:{[wand_stat_key]: number}

---@class permanent_action_ids:string[]

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
---| "always_casts" -- special thingy

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
    gun_level = "gun_level",
    always_casts = "always_casts"
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
    key_map.shuffle_deck_when_empty,
    key_map.always_casts
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

---@class sprite_info
---@field is_disabled? boolean  used when the holder is storing image data but shouldn't display
---@field file? string
---@field grip_x? number
---@field grip_y? number
---@field tip_x? number
---@field tip_y? number

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

---Returns an empty wand stat table to work on
---@return wand_stats
function wand_util:make_stats()
    local stats = {} ---@type wand_stats
    for _, key in ipairs(key_array) do
        if key ~= key_map.always_casts then
            local d = self[key]
            stats[key] = d.base
        end
    end
    return stats
end

---Scrape the ability component for wand stats.
---@param eid entity_id Any wand or holder with ability component(s)
---@return wand_stats, permanent_action_ids, sprite_info
function wand_util:convert_to_wand_stats(eid)
    local comp = comp_util.first_component(eid, "AbilityComponent", nil)
    local sprite_info = wand_util:get_wand_sprite(eid)
    ---@type wand_stats, permanent_action_ids, sprite_info
    local result, always_casts = self:make_stats(), {}
    if not comp then return result, always_casts, sprite_info end
    -- get always casts earlier, we need to ensure that the capacity value "acts like"
    -- it's reduced by the always casts count. They get added back in later.
    always_casts = self:get_always_casts_from_wand_or_holder(eid)
    for _, key in ipairs(key_array) do
        if key ~= key_map.always_casts then
            local def = self[key]
            local value = def:pull(comp)
            local reduction = (key == key_map.deck_capacity and #always_casts or 0)
            if type(value) == "boolean" then value = value and 1 or 0 end
            result[key] = value - reduction
        end
    end
    return result, always_casts, sprite_info
end

---For a given wand, scrape its internal inventory components and return
---an array of action ids which are attached permanently (always-casts)
---@param wand_id entity_id the wand we're scraping for permanents
---@return permanent_action_ids action_ids an array of spell action ids, usually uppercase strings.
function wand_util:get_always_casts_from_wand_or_holder(wand_id)
    local out = {} ---@type permanent_action_ids
    for _, spell in ipairs(EntityGetAllChildren(wand_id) or {}) do
        local ic = comp_util.first_component(spell, "ItemComponent")
        local iac = comp_util.first_component(spell, "ItemActionComponent")
        if ic and iac and comp_util.get_component_value(ic, "permanently_attached") then
            local aid = comp_util.get_component_value(iac, "action_id")
            if aid and aid ~= "" then out[#out + 1] = aid end
        end
    end
    return out
end

---Purge permanent actions from a wand. This is done prior to rewriting the action_ids
---to the wand so it doesn't retain action_id permanence after offerings are removed.
---@param wand_id entity_id The wand we're purging the permanent action_ids from
function wand_util:remove_all_always_casts(wand_id)
    local spells = EntityGetAllChildren(wand_id) or {}
    for _, spell in ipairs(spells) do
        local item = EntityGetFirstComponentIncludingDisabled(spell, "ItemComponent")
        if item and ComponentGetValue2(item, "permanently_attached") then
            EntityRemoveFromParent(spell)
            EntityKill(spell)
        end
    end
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
    local sign = (signed_steps < 0) and -1 or 1
    local steps = signed_steps * sign
    local linear_growth = 1.0 - 0.5 * self.growth
    return (linear_growth * steps + 0.5 * self.growth * steps * steps) * sign
end

function stat_def_mt:area_under_curve_of_value(value)
    return self:area_under_curve_of_steps(self:steps_from_value(value))
end

---Solves the base_cost of a wand stat by computing the area under the curve
---marching from self.base toward self.perfect, with a cost of total_perfection_cost
---which gets divided by the number of steps, accounting for growth, in the stat def.
---@return number
function stat_def_mt:solve_base_cost()
    if self.base_cost then return self.base_cost end
    local steps_to_perfect =
        (self.inverted and (self.base - self.perfect) or (self.perfect - self.base))
        / self.step_size -- should be > 0 by construction
    local linear_growth = 1.0 - 0.5 * self.growth
    local area_to_perfect =
        linear_growth * steps_to_perfect + 0.5 * self.growth * steps_to_perfect ^ 2
    self.base_cost = self.total_perfection_cost / area_to_perfect
    return self.base_cost
end

---Solves the cost-worth of the stat value based on the math of a stat-def.
---@param val number The stat value we want the worth of
---@return number the worth of the stat based on config factors.
function stat_def_mt:worth_from_value(val)
    return self.base_cost * self:area_under_curve_of_value(val)
end

function stat_def_mt:value_from_worth(worth)
    local unsigned_worth = math.abs(worth)
    local linear_growth = 1.0 - 0.5 * self.growth
    local area = unsigned_worth / self:solve_base_cost()
    local steps_from_perfect = (-linear_growth + math.sqrt(linear_growth ^ 2 + 2.0 * self.growth * area)) / self.growth
    local distance = steps_from_perfect * self.step_size
    local sign = (self.inverted == (worth < 0)) and 1 or -1
    local unclamped_result = self.base + sign * distance
    return self:clamp(unclamped_result)
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
---@param always_casts permanent_action_ids an existing always_cast array we fill from nothing
---@param offering_always_casts_arrays permanent_action_ids[] All wands stats as an array of stats holders.
---@param sprite_info sprite_info
---@return wand_stats, permanent_action_ids, sprite_info
function wand_util:collapse_wand_abilities_and_always_casts(stats, offerings, always_casts,
                                                            offering_always_casts_arrays, sprite_info)
    local has_any_offering = false
    for _, key in ipairs(key_array) do
        if key ~= key_map.always_casts then
            local worth = self[key]:worth_from_value(stats[key])
            for _, offer in ipairs(offerings) do
                has_any_offering = true
                local offer_worth = self[key]:worth_from_value(offer[key])
                worth = worth + offer_worth
            end
            stats[key] = self[key]:value_from_worth(worth)
        end
    end
    local seen_always_cast = {}
    for _, always_cast in ipairs(always_casts) do
        seen_always_cast[always_cast] = true
    end
    for _, offering_always_casts in ipairs(offering_always_casts_arrays) do
        for _, always_cast in ipairs(offering_always_casts) do
            if not seen_always_cast[always_cast] then
                seen_always_cast[always_cast] = true
                always_casts[#always_casts + 1] = always_cast
            end
        end
    end

    -- transmute the sprite. this is an optional config you can disable.
    -- the wand stats we work with are indexed identically to a normal wand
    -- which winds up being vanilla-compatible with how nolla grabs their wands
    if has_any_offering then
        logger.out("offerings were detected so the sprite info is being mutated")
        local new_form = wand_util:get_wand_form_from_stats(stats)
        if new_form then sprite_info = new_form end
    end
    return stats, always_casts, sprite_info
end

---Gather all the wand stats belonging to holder children of the altar.
---These are the holder stats, NOT the wands they represent.
---@param altar entity_id the altar we want the stats of wands on
---@return wand_stats[] result, permanent_action_ids[] action_ids, sprite_info
function wand_util:holder_wand_stats_from_altar(altar)
    local holders = EntityGetAllChildren(altar) or {}
    logger.peek("combining holders", holders, "from altar", altar)
    local result, action_ids = {}, {}
    local sprite_info_first = nil
    for _, child in ipairs(holders) do
        local child_stats, child_action_ids, sprite_info = self:convert_to_wand_stats(child)
        result[#result + 1] = child_stats
        action_ids[#action_ids + 1] = child_action_ids
        if not sprite_info_first then sprite_info_first = sprite_info end
    end
    return result, action_ids, sprite_info_first
end

---Take the sum of the holder entities components, whatever they may be
---This can be used to restore the target item to its original values
---by passing a 0 for the lower altar, which causes no lower items to
---be factored in the formula. The result will be a combined WandStats
---@param upper_altar entity_id
---@param lower_altar entity_id|nil
---@return wand_stats? stats, permanent_action_ids action_ids, sprite_info? sprite_info
function wand_util:combine_altar_item_stats(upper_altar, lower_altar)
    local upper_wand_stats, upper_wand_action_ids, sprite_info = self:holder_wand_stats_from_altar(upper_altar)
    if #upper_wand_stats == 0 then return nil, {}, nil end
    if not lower_altar then return upper_wand_stats[1], upper_wand_action_ids[1], sprite_info end

    local offerings, always_cast_arrays = self:holder_wand_stats_from_altar(lower_altar)
    local blended_stats, blended_always_casts, form = self:collapse_wand_abilities_and_always_casts(upper_wand_stats[1],
        offerings, upper_wand_action_ids[1], always_cast_arrays, sprite_info)

    logger.peek("blended stats", blended_stats, "blended always casts", blended_always_casts,
        "blended form", form)
    return blended_stats, blended_always_casts, form -- don't bother setting sprite info, we reroll it if it's blended
end

function wand_util:add_gun_action_permanent(entity_id, action_id)
    if (action_id == "") then return 0 end
    local action_entity_id = CreateItemActionEntity(action_id)
    if action_entity_id ~= nil then
        EntityAddChild(entity_id, action_entity_id)
    end

    -- we need to add a slot to the ability_comp
    local ability_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "AbilityComponent")
    if (ability_comp ~= nil) then
        local deck_capacity = tonumber(comp_util.get_component_object_value(ability_comp, "gun_config", "deck_capacity"))
        deck_capacity = deck_capacity + 1
        comp_util.set_component_object_value(ability_comp, "gun_config", "deck_capacity", deck_capacity)
    end

    if action_entity_id ~= nil then
        local item_component = comp_util.first_component(action_entity_id, "ItemComponent", nil)
        if (item_component ~= nil) then
            comp_util.set_component_value(item_component, "permanently_attached", true)
        end

        EntitySetComponentsWithTagEnabled(action_entity_id, "enabled_in_world", false)
    end
end

---Store a wand's stats in a holder linking to the item.
---@param eid entity_id the wand being added to the altar
---@param hid entity_id the holder of the wand representative
function wand_util:set_holder_wand_stats(eid, hid)
    logger.out("setting holder " .. hid .. " stats from wand " .. eid)
    -- if the holder doesn't align DO NOT overwrite its stats
    if comp_util.get_entity_id(hid, "eid") ~= eid then return end
    local ability = comp_util.first_component(hid, "AbilityComponent", nil)
    -- if the holder already has a stat block ALSO don't overwrite it.
    if not ability then
        EntityAddComponent2(hid, "AbilityComponent", {}) -- create empty ability component
    end
    local stats, action_ids, sprite_info = self:convert_to_wand_stats(eid)
    sprite_info.is_disabled = true -- hide holders so they're invisible
    logger.peek("stats", stats, "action ids", action_ids)
    -- set the empty ability component stats to be stored ones
    self:set_wand_result(hid, stats, action_ids, sprite_info)
end

---Sets the stats (ability component) of the
---entity provided to be the stats passed in.
---@param wand_id entity_id
---@param stats_to_store? wand_stats
---@param action_ids? permanent_action_ids
---@param form? sprite_info
function wand_util:set_wand_result(wand_id, stats_to_store, action_ids, form)
    logger.peek("setting wand stats", stats_to_store, "  of wand", wand_id)
    if not stats_to_store then return end
    local ability = comp_util.first_component(wand_id, "AbilityComponent", nil)
    if not ability then return end
    for _, key in ipairs(key_array) do
        if key ~= key_map.always_casts then
            local stat = stats_to_store[key]
            self[key]:push(ability, stat)
        end
    end
    logger.peek("clearing and resetting wand always casts", action_ids, "  of wand", wand_id)
    wand_util:remove_all_always_casts(wand_id)
    -- this is deferred because the wand should have an ability component before it is called
    for _, action_id in ipairs(action_ids or {}) do
        logger.peek("adding gun action permanent", action_id)
        if type(action_id) ~= "string" then
            logger.peek("action id isn't a string, it's a ", tostring(type(action_id)))
        else
            wand_util:add_gun_action_permanent(wand_id, action_id)
        end
    end

    if form then
        logger.peek("changing form of ", wand_id, " to ", form)
        wand_util:set_wand_sprite(wand_id, ability, form.file, form.grip_x, form.grip_y, form.tip_x, form.tip_y,
            form.is_disabled)
    end
end

function wand_util:wand_diff(gun, wand)
    local score = 0
    score = score + (math.abs(gun.fire_rate_wait - wand.fire_rate_wait) * 2)
    score = score + (math.abs(gun.actions_per_round - wand.actions_per_round) * 20)
    score = score + (math.abs(gun.shuffle_deck_when_empty - wand.shuffle_deck_when_empty) * 30)
    score = score + (math.abs(gun.deck_capacity - wand.deck_capacity) * 5)
    score = score + math.abs(gun.spread_degrees - wand.spread_degrees)
    score = score + math.abs(gun.reload_time - wand.reload_time)
    return score
end


function wand_util.clamp(val, lower, upper)
	assert(val and lower and upper, "not very useful error message here")
	if lower > upper then lower, upper = upper, lower end -- swap if boundaries supplied the wrong way
	return math.max(lower, math.min(upper, val))
end

---Convert a wand table from the wands lua in the procgen scripts to a sprite_info
---for easier use locally. Gets the wand nearest to the stats provided using Nolla's method.
---@param wand_stats wand_stats
---@return sprite_info? sprite_info
function wand_util:get_wand_form_from_stats(wand_stats)
    local closest_match = nil
    local nearest_score = 1000
    local wand_comparable = {}
    wand_comparable.fire_rate_wait = wand_util.clamp(((wand_stats["fire_rate_wait"] + 5) / 7) - 1, 0, 4)
    wand_comparable.actions_per_round = wand_util.clamp(wand_stats["actions_per_round"] - 1, 0, 2)
    wand_comparable.shuffle_deck_when_empty = wand_util.clamp(wand_stats["shuffle_deck_when_empty"], 0, 1)
    wand_comparable.deck_capacity = wand_util.clamp((wand_stats["deck_capacity"] - 3) / 3, 0, 7)
    wand_comparable.spread_degrees = wand_util.clamp(((wand_stats["spread_degrees"] + 5) / 5) - 1, 0, 2)
    wand_comparable.reload_time = wand_util.clamp(((wand_stats["reload_time"] + 5) / 25) - 1, 0, 2)

    for _, wand_from_library in pairs(wands) do
        local score = wand_util:wand_diff(wand_comparable, wand_from_library)
        if (score <= nearest_score) then
            closest_match = wand_from_library
            nearest_score = score
            -- just randomly return one of them...
            if (score == 0 and Random(0, 100) < 33) then
                break
            end
        end
    end

    local result = nil ---@type sprite_info?
    if closest_match ~= nil then
        result = {}
        result.file = closest_match.file
        result.grip_x = closest_match.grip_x
        result.grip_y = closest_match.grip_y
        result.tip_x = closest_match.tip_x
        result.tip_y = closest_match.tip_y
    end
    return result
end

function wand_util:get_wand_sprite(eid)
    local result = {} ---@type sprite_info
    local ability_comp = comp_util.first_component(eid, "AbilityComponent", nil)
    if (ability_comp ~= nil) then
        result.file = comp_util.get_component_value(ability_comp, "sprite_file")
    end

    local sprite_comp = comp_util.first_component(eid, "SpriteComponent", "item")
    -- fallback if we can't find a sprite comp
    sprite_comp = sprite_comp or comp_util.first_component(eid, "SpriteComponent", nil)
    if (sprite_comp ~= nil) then
        result.file = comp_util.get_component_value(sprite_comp, "image_file")
        result.grip_x = comp_util.get_component_value(sprite_comp, "offset_x")
        result.grip_y = comp_util.get_component_value(sprite_comp, "offset_y")
    end

    local hotspot_comp = comp_util.first_component(eid, "HotspotComponent", "shoot_pos")
    if (hotspot_comp ~= nil) then
        local tip_vector = comp_util.get_component_value_vector(hotspot_comp, "offset") ---@returns vector2
        logger.peek("tip vector object", tip_vector)
        result.tip_x = tip_vector.x
        result.tip_y = tip_vector.y
    end
    return result
end

function wand_util:set_wand_sprite(wand_id, ability_comp, item_file, grip_x, grip_y, tip_x, tip_y, is_disabled)
    if (ability_comp ~= nil) then
        logger.peek("setting sprite file in ability comp", item_file)
        comp_util.set_component_value(ability_comp, "sprite_file", item_file)
    end

    local offset_x, offset_y = 0, 0
    if (tip_x and tip_y and grip_x and grip_y) then
        offset_x, offset_y = (tip_x or 0) - (grip_x or 0), (tip_y or 0) - (grip_y or 0)        
    end


    if (grip_x ~= nil and grip_y ~= nil) then
        --local sprite_comp = nil
        local sprite_comp = comp_util.get_or_create_comp(wand_id, "SpriteComponent", "item")
        -- fallback if we can't find a sprite comp
        sprite_comp = sprite_comp or comp_util.first_component(wand_id, "SpriteComponent", nil)
        if (sprite_comp ~= nil) then
            logger.peek("scraping offsets into sprite comp", item_file, "x", grip_x, "y", grip_y)
            comp_util.set_component_value(sprite_comp, "image_file", item_file)
            comp_util.set_component_value(sprite_comp, "offset_x", grip_x)
            comp_util.set_component_value(sprite_comp, "offset_y", grip_y)
            comp_util.set_component_value(sprite_comp, "rect_animation", "default")
            if not is_disabled then
                EntityRefreshSprite(wand_id, sprite_comp)
            else
                comp_util.toggle_components_by_type_and_tag(wand_id, "SpriteComponent", "item", false)
            end
        end
    end
    if (tip_x ~= nil and tip_y ~= nil) then
        local hotspot_comp = comp_util.get_or_create_comp(wand_id, "HotspotComponent", "shoot_pos")
        if (hotspot_comp ~= nil) then
            logger.peek("scraping offsets into hotspot comp", hotspot_comp, "x", offset_x, "y", offset_y)
            --local v = { x = shoot_x, y = shoot_y }
            comp_util.set_component_value_vector(hotspot_comp, "offset", tip_x or 0, tip_y or 0)
        end
    end
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
        min = 0,
        max = 20,
        base = 0,
        inverted = false,
        delta = 1.0,
        growth = 8.0,
        perfect = 20,
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
        base = 16.0,
        inverted = true,
        delta = 1.0,
        growth = 1.4,
        perfect = -240.0,
        total_cost_of_perfection = 12000.0
    },
    speed_multiplier = {
        name = "speed_multiplier",
        min = 0.8,
        max = 10.0,
        base = 0.8,
        inverted = false,
        delta = 0.01,
        growth = 1.2,
        perfect = 10.0,
        total_cost_of_perfection = 18400.0
    },
    spread_degrees = {
        name = "spread_degrees",
        min = -1440.0,
        max = 1440.0,
        base = 0.0,
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
