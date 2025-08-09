---@diagnostic disable: lowercase-global, missing-global-doc, deprecated
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/scripts/component_utils.lua")
dofile_once("mods/offerings/scripts/debug.lua")

-- important constants used for consistency/cleanup
local align_offset_x = 0
local hover_offset_y = -5

-- various tags
local target_stat_buffer = "target_statbuffer"
local workshop_altar_tag = "workshop_altar"
local offer_altar_tag = "offer_altar"
local target_altar_tag = "target_altar"

-- potion stat clamps
local velocity_coeff_limit = 225
local velocity_norm_limit = 1.5
local velocity_limit_step_cap = 0.05

local tempered_localization = "$workshop_flask_tempered"
local reactive_localization = "$workshop_flask_reactive"
local inert_localization = "$workshop_flask_inert"
local remote_localization = "$workshop_flask_remote"
local reaction_chance_localization = "$workshop_flask_reaction_chance"
local reaction_speed_localization = "$workshop_flask_reaction_speed"
local barrel_size_localization = "$workshop_flask_barrel_size"
local fill_rate_localization = "$workshop_flask_fill_rate"

local flask_enchant_prefix = "offerings_flask_enchant_"

--- Make flask unbreakable by removing its DamageModelComponent(s)
function Apply_Tempered(flask_id, level)
    local comps = EntityGetComponentIncludingDisabled(flask_id, "DamageModelComponent") or {}
    for _, comp in ipairs(comps) do EntityRemoveComponent(flask_id, comp) end
end

--- Reduce reaction rate by 20 × level (defaults to 20 if not present)
function Apply_Inert(flask_id, level)
    local comps = EntityGetComponentIncludingDisabled(flask_id, "MaterialInventoryComponent") or {}
    for _, comp in ipairs(comps) do
        local default = 20
        local rate = default - (20 * level)
        ComponentSetValue2(comp, "reaction_rate", math.max(0, rate))
    end
end

function Apply_Transmuting(flask_id, level)
    local key = flask_enchant_prefix .. "transmuting"

    -- Remove any existing component with this key
    local comps = EntityGetComponentIncludingDisabled(flask_id, "VariableStorageComponent") or {}
    for _, comp in ipairs(comps) do
        if ComponentGetValue2(comp, "name") == key then EntityRemoveComponent(flask_id, comp) end
    end

    -- Add new component with level set
    EntityAddComponent2(flask_id, "VariableStorageComponent",
        { name = key, value_int = level, value_string = "Transmuting Flask", _tags = "flask_enchantment" })
end

function Apply_Instant(flask_id, level)
    local sucker_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent") or {}
    local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent") or {}
    local capacity = 1000
    if sucker_comp then
        capacity = ComponentGetValue2(sucker_comp, "barrel_size")
    end
    if potion_comp then
        ComponentSetValue2(potion_comp, "throw_bunch", true)
        ComponentSetValue2(potion_comp, "throw_how_many", capacity)
    end
end

--- Increase reaction rate from 20 to 100 in 5 steps (Reactive I-V)
function Apply_Reactive(flask_id, level)
    local comps = EntityGetComponentIncludingDisabled(flask_id, "MaterialInventoryComponent") or {}
    for _, comp in ipairs(comps) do ComponentSetValue2(comp, "reaction_rate", math.min(20 + (level * 20), 100)) end
end

--- Mark the flask as "Remote" using a VariableStorageComponent
---@param flask_id integer
---@param level integer
function Apply_Drawing(flask_id, level)
    local key = flask_enchant_prefix .. "drawing"

    -- Remove any existing component with this key
    local comps = EntityGetComponentIncludingDisabled(flask_id, "VariableStorageComponent") or {}
    for _, comp in ipairs(comps) do
        if ComponentGetValue2(comp, "name") == key then EntityRemoveComponent(flask_id, comp) end
    end

    -- Add new component with level set
    EntityAddComponent2(flask_id, "VariableStorageComponent",
        { name = key, value_int = level, value_string = "Drawing Flask", _tags = "flask_enchantment" })
end

function Describe_Inert(combined_stats, enchantment_key, enchantment_level)
    local localization = GameTextGet(inert_localization)
    if localization then Log("Describing inert: " .. localization) end
    return localization
end

function Describe_Tempered(combined_stats, enchantment_key, enchantment_level)
    local localization = GameTextGet(tempered_localization)
    if localization then Log("Describing tempered: " .. localization) end
    return localization
end

function Describe_Drawing(combined_stats, enchantment_key, enchantment_level)
    local localization = GameTextGet(remote_localization)
    if localization then Log("Describing drawing: " .. localization) end
    return localization
end

function Describe_Instant(combined_stats, enchantment_key, enchantment_level)
    local localization = GameTextGet(remote_localization)
    if localization then Log("Describing instant: " .. localization) end
    return localization
end

function Describe_Transmuting(combined_stats, enchantment_key, enchantment_level)
    local localization = GameTextGet(remote_localization)
    if localization then Log("Describing transmuting: " .. localization) end
    return localization
end

function Describe_Reactive(combined_stats, enchantment_key, enchantment_level)
    local localization = GameTextGet(reactive_localization) .. " "
        .. GameTextGet(reaction_chance_localization) .. ": " .. Get_Reaction_Chance(combined_stats) .. " "
        .. GameTextGet(reaction_speed_localization) .. ": " .. Get_Reaction_Speed(combined_stats)
    if localization then Log("Describing reactive: " .. localization) end
    return localization
end

-- list of enchantments of flasks and their detection item
local flask_enchantments = {
    tempered = {
        trigger_item_levels = Detect_Kiauskivi,
        max = 1,
        apply = Apply_Tempered,
        describe = Describe_Tempered
    },
    instant = {
        trigger_item_levels = Detect_Ukkoskivi,
        max = 1,
        apply = Apply_Instant,
        describe = Describe_Instant
    },
    inert = {
        trigger_item_levels = Detect_Tablet,
        max = 1,
        apply = Apply_Inert,
        negates = "reactive",
        describe = Describe_Inert
    },
    reactive = {
        trigger_item_levels = Detect_Scroll,
        max = 4,
        apply = Apply_Reactive,
        negates = "inert",
        describe = Describe_Reactive
    },
    drawing = {
        trigger_item_levels = Detect_Vuoksikivi,
        max = 1,
        apply = Apply_Drawing,
        describe = Describe_Drawing
    },
    transmuting = {
        trigger_item_levels = Detect_Potion_Mimic,
        max = 1,
        apply = Apply_Transmuting,
        describe = Describe_Transmuting
    }
}


function Get_Reaction_Chance(combined_stats)
    -- STUB
    return ""
end

function Get_Reaction_Speed(combined_stats)
    -- STUB
    return ""
end

function Set_Simple_Physics(item_id, is_static)
    if not Is_Wand(item_id) then return end
    local simple_phys_comp = EntityGetFirstComponentIncludingDisabled(item_id, "SimplePhysicsComponent")
    if simple_phys_comp then
        EntitySetComponentIsEnabled(item_id, simple_phys_comp, not is_static)
    end
end

function Set_Physics_Body_Stasis(item_id, is_static)
    if Is_Wand(item_id) then return end
    local phys_comp = EntityGetFirstComponentIncludingDisabled(item_id, "PhysicsBodyComponent")
    if phys_comp then
        ComponentSetValue2(phys_comp, "is_static", is_static)
        if not Is_Flask(item_id) then return end
        local damage_comp = EntityGetFirstComponentIncludingDisabled(item_id, "DamageModelComponent")
        if damage_comp then EntitySetComponentIsEnabled(item_id, damage_comp, not is_static) end
    end
end

---Detect if the inventory of a provided entity (presumed to be an item)
---is the quick inventory of the player. These are, weirdly, collidable. We don't want that.
---@param entity_id any
---@return boolean
function Is_Inventory(entity_id)
    local parent_id = EntityGetParent(entity_id)
    return parent_id ~= 0 and EntityGetName(parent_id) == "inventory_quick";
end

function Get_Linked_Altar(entity_id)
    local parent_id = EntityGetParent(entity_id)
    if parent_id ~= 0 and EntityHasTag(parent_id, workshop_altar_tag) then
        return parent_id
    end
    return 0
end

---Get the closest altar with the provided tag to another altar
---@param entity_id any
---@param tag any
---@return number
function Get_Closest_Altar(entity_id, tag)
    local x, y = EntityGetTransform(entity_id)
    return EntityGetClosestWithTag(x, y, tag)
end

---Get the target altar closest to a given entity
---@param entity_id any
---@return number
function Get_Target_Altar(entity_id)
    return Get_Closest_Altar(entity_id, target_altar_tag)
end

---Get the offering altar closest to a given entity
---@param entity_id any
---@return number
function Get_Offer_Altar(entity_id)
    return Get_Closest_Altar(entity_id, offer_altar_tag)
end

---Return the target item of the target altar
---@param target_altar_id any
function Get_Target(target_altar_id)
    -- start with wands, if any is bound, the first result is what we return
    local wand_targets = Get_Wands(target_altar_id)
    if #wand_targets > 0 then return wand_targets[1] end

    -- look for flasks if no wands are found
    local flask_targets = Get_Flasks(target_altar_id)
    if #flask_targets > 0 then return flask_targets[1] end

    return nil
end

---Returns true if the altar id provided has the target altar tag.
---@param altar_id any
---@return boolean
function Is_Target_Altar(altar_id)
    return EntityHasTag(altar_id, target_altar_tag)
end

---Return true if the item is a flask enhancer for the flask,
---irrespective of whether it is useful to the flask in question
---@param offer_item_id any
---@return boolean
function Is_Flask_Enhancer(offer_item_id)
    for _, ench in ipairs(flask_enchantments) do
        if ench.trigger_item_levels and ench.trigger_item_levels(offer_item_id) > 0 then return true end
    end
    return false
end

---Returns true if the given item_id is currently linked to the altar.
---@param altar_id integer
---@param item_id integer
---@return boolean
function Is_Attached_To_Altar(altar_id, item_id)
    return EntityGetParent(item_id) == altar_id
end

---Turn the glowy altar particles on
---@param altar_id any
---@param is_glowing any
function Set_Altar_Glowing(altar_id, is_glowing)
    EntitySetComponentsWithTagEnabled(altar_id, "item_effect", is_glowing)
end

---Links the item to the provided altar.
---@param altar_id any
---@param item_id any
function Add_Altar_Item(altar_id, item_id)
    local item_x, item_y = EntityGetTransform(item_id)
    local altar_x, altar_y = EntityGetTransform(altar_id)
    local x = (is_target_altar and altar_x or item_x) + align_offset_x
    local y = altar_y + hover_offset_y
    local upgright_rotation = EntityHasTag(item_id, "wand") and -math.pi * 0.5 or 0.0
    EntitySetTransform(item_id, item_x, item_y, upgright_rotation)
    local item_comp = EntityGetFirstComponentIncludingDisabled(item_id, "ItemComponent")
    if item_comp then
        local hx, hy = Get_Hover_Transform(item_id, altar_id, Is_Target_Altar(altar_id))
        ComponentSetValue2(item_comp, "spawn_pos", hx, hy)
    end
    local item_comp = EntityGetFirstComponentIncludingDisabled(item_id, "ItemComponent")
    if item_comp then
        ComponentSetValue2(item_comp, "has_been_picked_by_player", false)
        ComponentSetValue2(item_comp, "play_hover_animation", false)
        ComponentSetValue2(item_comp, "play_spinning_animation", false)
        ComponentSetValue2(item_comp, "spawn_pos", x, y)
    end
    Set_Simple_Physics(item_id, true) -- stops wands
    Set_Physics_Body_Stasis(item_id, true) -- stops everything else, potions shatter?!

    -- if the item is a wand we enable its snazzy wand-acquisition script
    if EntityHasTag(item_id, "wand") then 
        local luaComponent = ecomp_byvar(item_id, "LuaComponent", "script_item_picked_up",
            "data/scripts/particles/wand_pickup.lua")
        if luaComponent ~= nil then EntitySetComponentIsEnabled(item_id, luaComponent, true) end
     end

    -- required for logic to be the altar's child temporarily
    EntityAddChild(altar_id, item_id)

    -- make the item glow with "new item" smell
    Emit_New_Item_Glow(item_id)

    -- show the altar runes glowing to make it clear it is holding items by the altar
    Update_Altar_Glow(altar_id)

    -- refresh the result of the recipe, whatever that entails.
    Update_Result(altar_id)
end


-- Find the first enabled sprite; that’s what the player sees.
local function Get_Primary_Sprite_Offset(eid)
  local scs = EntityGetComponentIncludingDisabled(eid, "SpriteComponent") or {}
  for _, sc in ipairs(scs) do
    if ComponentGetIsEnabled(sc) then
      local ox = ComponentGetValue2(sc, "offset_x") or 0
      local oy = ComponentGetValue2(sc, "offset_y") or 0
      return ox, oy
    end
  end
  return 0, 0
end

-- Align *all* sprite particle emitters on this entity to that sprite’s offset.
local function Align_All_Sprite_Emitters_To_Primary_Sprite(eid)
  local ox, oy = Get_Primary_Sprite_Offset(eid)
  for _, pec in ipairs(EntityGetComponentIncludingDisabled(eid, "SpriteParticleEmitterComponent") or {}) do
    -- clamp spawn window to a point = sprite’s visual offset
    pcall(function()
      ComponentSetValue2(pec, "x_pos_offset_min", ox)
      ComponentSetValue2(pec, "x_pos_offset_max", ox)
      ComponentSetValue2(pec, "y_pos_offset_min", oy)
      ComponentSetValue2(pec, "y_pos_offset_max", oy)
    end)
  end
end

---Makes the wand have some particles like shop wands and wands you're seeing for the first time.
---@param item_id any
function Emit_New_Item_Glow(item_id)
    local particle_comp = ecomp_byvar(item_id, "SpriteParticleEmitterComponent",
        "velocity_always_away_from_center", nil)
    if particle_comp then
        EntitySetComponentIsEnabled(item_id, particle_comp, true)
        Align_All_Sprite_Emitters_To_Primary_Sprite(item_id)
    end
end

---Handle decoupling an altar from any of its held items.
---@param altar_id any
---@param item_id any
---@param is_update_needed boolean
function Remove_Altar_Item(altar_id, item_id, is_update_needed)
    -- kill any IOU shell linked to this item
    local shell_id = 0
    for _, c in ipairs(EntityGetComponentIncludingDisabled(item_id, "VariableStorageComponent") or {}) do
        if ComponentGetValue2(c, "name") == "display_shell_id" then
            shell_id = ComponentGetValue2(c, "value_int")
            EntityRemoveComponent(item_id, c)
            break
        end
    end
    if shell_id ~= 0 and EntityGetIsAlive(shell_id) then EntityKill(shell_id) end

    Decouple_Item_From_Altar(item_id)
    Set_Target_Altar_Collision(altar_id, true)
    Update_Altar_Glow(altar_id)
    Stop_New_Item_Glow(item_id)
    if is_update_needed then Update_Result(altar_id) end
end

function Undo_Stasis(item_id)
    Set_Simple_Physics(item_id, false)
    Set_Physics_Body_Stasis(item_id, false)
end

function Stop_New_Item_Glow(item_id)
    local particle_comp = ecomp_byvar(item_id, "SpriteParticleEmitterComponent",
        "velocity_always_away_from_center", nil)
    if particle_comp ~= nil then EntitySetComponentIsEnabled(item_id, particle_comp, false) end
end

function Update_Altar_Glow(altar_id)
    local linked_items = Get_Altar_Items(altar_id)
    local is_linked_item = #linked_items > 0
    Set_Altar_Glowing(altar_id, is_linked_item)
end

---Detaches an item from its altar "owner" so it is no
---longer considered in the pool for calculations/recipes
---@param item_id any
function Decouple_Item_From_Altar(item_id)
    EntityRemoveFromParent(item_id)
end

---Called when the player picks up the target result from the altar.
---@param player_id any
---@param altar_id any
---@param item_id any
function Take_Item(player_id, altar_id, item_id)
    if Is_Target_Altar(altar_id) then
        local offer_altar_id = Get_Offer_Altar(altar_id)

        -- special for flasks, several things to countermand bad behaviors while altar-linked
        if Is_Flask(item_id) then
            -- we make flasks inert as long as they're on the target to avoid accidental alchemy
            Apply_Inert_And_Reactive_To_Flask(altar_id, item_id, offer_altar_id)

            -- special for flasks part 2, restore the damage component if the flask lacks Tempered
            Apply_Damage_Models_And_Physics_Collision(altar_id, item_id, offer_altar_id)
        end

        -- if there are any linked offerings, destroy them
        Destroy_Recipe_Linked_Items(offer_altar_id)

        -- erase the statbuffer. While not strictly necessary it leaves less garbage behind
        Clear_Old_Reserve_Stats(altar_id)
    end

    -- clean up the reference to the item so it isn't still considered linked.
    Remove_Altar_Item(altar_id, item_id, false)

    GamePickUpInventoryItem(player_id, item_id)
end

function Apply_Damage_Models_And_Physics_Collision(target_altar_id, target_flask_id, offer_altar_id)
    local combined = Get_Combined_Flask_Stats(target_altar_id, offer_altar_id)
    -- tempered *leaves* the effect in play.
    if Get_Level_Of_Flask_Enchantment(target_flask_id, "tempered") > 0 then return end

    local phys_comps = EntityGetComponentIncludingDisabled(target_flask_id, "PhysicsBodyCollisionDamageComponent") or {}
    for _, phys_comp in ipairs(phys_comps) do
        -- default is 0.016667
        ComponentSetValue2(phys_comp, "damage_multiplier", 0.016667)
    end
end

---Prints the item stats provided the altars for both offering and target.
---Needs to dynamically calculate the items combined into a stat pool to
---print the expected result in a humanized format
---@param target_item_id any
---@param target_altar_id any
---@param offer_altar_id any
function Print_Item_Stats(target_item_id, target_altar_id, offer_altar_id)
    if Is_Wand(target_item_id) then Print_Wand_Stats(target_altar_id, offer_altar_id) end
    if Is_Flask(target_item_id) then Print_Flask_Stats(target_altar_id, offer_altar_id) end
end

---Destroy any items that are the same type as the target item.
---@param altar_id any
function Destroy_Recipe_Linked_Items(altar_id)
    local target_altar_id = Get_Target_Altar(altar_id)
    local target_id = Get_Target(target_altar_id)
    local offering_altar_id = Get_Offer_Altar(altar_id)
    local destroy_list = {}
    if Is_Wand(target_id) then
        destroy_list = Get_Wands(offering_altar_id)
    elseif Is_Flask(target_id) then
        destroy_list = Get_Flasks(offering_altar_id)
        local enhancers = Get_Flask_Enhancers(offering_altar_id) or {}
        for i = 1, #enhancers do destroy_list[#destroy_list + 1] = enhancers[i] end
    end

    for _, item_id in ipairs(destroy_list) do
        -- make sure we empty a flask before destroying it or there will be a mess
        if Is_Flask(item_id) then RemoveMaterialInventoryMaterial(item_id) end

        local x, y = EntityGetTransform(item_id)

        -- Optional: visual effect
        EntityLoad("data/entities/particles/destruction.xml", x, y)
        GamePlaySound("data/audio/Desktop/projectiles.bank", "magic/common_destroy", x, y)

        -- ensure it is unlinked from the altar
        Remove_Altar_Item(offering_altar_id, item_id, false)

        -- Kill the item
        EntityKill(item_id)
    end
end

---Enables the collision component of the altar if its tag is target_grab
---This is virtually the same as checking to see if the altar is the target altar
---before disabling the collision, so it could be replaced with something like that.
---@param altar_id any
---@param is_collision_enabled any
function Set_Target_Altar_Collision(altar_id, is_collision_enabled)
    EntitySetComponentsWithTagEnabled(altar_id, "workshop_altar_collision", is_collision_enabled)
end

---Get the wand ability component of the provided wand id
---@param wand_id any
---@return number|nil
function Get_Wand_Ability_Component(wand_id)
    return EntityGetFirstComponentIncludingDisabled(wand_id, "AbilityComponent")
end

---Cleans the decimal places of a number to the nearest 100th (2 points of precision)
---@param d any
---@return any
function Clean_Precision(d)
    if d ~= math.floor(d * 100 + 0.5) / 100 then -- make it not an ugly number...
        d = math.floor(d * 100 + 0.5) / 100
    end
    return d
end

---Gets any wands attached to the altar of the altar in question.
---@param altar_id any
---@return number[]
function Get_Wands(altar_id)
    local altar_items = Get_Altar_Items(altar_id)
    local result = {}
    if altar_items ~= nil then
        for i, item in ipairs(altar_items) do
            if EntityHasTag(item, "wand") then result[#result + 1] = item end
        end
    end
    return result
end

---Gets any flasks attached to the altar in question.
---@param altar_id any
---@return number[]
function Get_Flasks(altar_id)
    local altar_items = Get_Altar_Items(altar_id)
    local result = {}
    if altar_items ~= nil then
        for i, item in ipairs(altar_items) do
            if EntityHasTag(item, "potion") then result[#result + 1] = item end
        end
    end
    return result
end

---Gets any flask enhancing items attached to the altar in question.
---@param altar_id any
---@return number[]
function Get_Flask_Enhancers(altar_id)
    local altar_items = Get_Altar_Items(altar_id)
    local result = {}
    if altar_items == nil then return result end
    for i, item in ipairs(altar_items) do
        if Is_Flask_Enhancer(item) then result[#result + 1] = item end
    end
    return result
end

---Returns the item ids that are attached to the altar by VSC.
---@param altar_id any
---@return table
function Get_Altar_Items(altar_id)
    return EntityGetAllChildren(altar_id) or {}
end

---Recalculates the result of the inputs on the offering altar
---based on the target altar item, if one exists.
---@param altar_id any
function Update_Result(altar_id)
    -- find the offering altar
    local target_altar_id = Get_Target_Altar(altar_id)
    local target_item_id = Get_Target(target_altar_id)

    if not target_item_id then return end

    -- determine if the recipe is a wand or flask
    local offer_altar_id = Get_Offer_Altar(altar_id)
    if Is_Wand(target_item_id) then
        Calculate_Wand_Stats(target_item_id, target_altar_id, offer_altar_id)
    elseif Is_Flask(target_item_id) then
        Calculate_Flask_Stats(target_item_id, target_altar_id, offer_altar_id)
    end
    Print_Item_Stats(target_item_id, target_altar_id, offer_altar_id)
end

---Wipe out the old reserve stats of the variable storage component of the altar.
---This is called when reserving wand OR flask stats or when taking the result.
---@param altar_id any
function Clear_Old_Reserve_Stats(altar_id)
    local old_comps = EntityGetComponent(altar_id, "VariableStorageComponent") or {}
    for _, comp in ipairs(old_comps) do
        if ComponentHasTag(comp, target_stat_buffer) then
            EntityRemoveComponent(altar_id, comp)
        end
    end
end

--== WAND MERGING ==--


local wand_stats = {
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

---Calculate the stat buffer of the sacrifical
---wands and apply it to the target wand.
---@param target_wand_id any
---@param target_altar_id any
---@param offer_altar_id any
function Calculate_Wand_Stats(target_wand_id, target_altar_id, offer_altar_id)
    local combined_stats = Get_Combined_Wand_Stats(target_altar_id, offer_altar_id)
    Apply_Wand_Stats(target_wand_id, combined_stats)
end

---Return the stats of all wands on offer combined with the reserve wand stats.
---@param target_altar_id any
---@param offer_altar_id any
---@return table
function Get_Combined_Wand_Stats(target_altar_id, offer_altar_id)
    local target_stats = Get_Reserved_Wand_Stats(target_altar_id)
    local offering_stats_list = Get_Offering_Wand_Stats(offer_altar_id)
    return Combine_Wand_Stats(target_stats, offering_stats_list)
end

---Get and humanely display the combined stats of the result wand for debugging.
---@param target_altar_id any
---@param offer_altar_id any
function Print_Wand_Stats(target_altar_id, offer_altar_id)
    local combined_stats = Get_Combined_Wand_Stats(target_altar_id, offer_altar_id)

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
    for _, def in ipairs(wand_stats) do
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

---Apply a stat table back to a wand's AbilityComponent
---@param wand_id integer
---@param stats_table table[] list of { name, value_int }
function Apply_Wand_Stats(wand_id, stats_table)
    local ability_comp = Get_Wand_Ability_Component(wand_id)
    if not ability_comp then
        print("Apply_Wand_Stats: missing AbilityComponent")
        return
    end

    for _, entry in ipairs(stats_table) do
        local name = entry.name
        local value = entry.value_int

        -- Match stat against wand_stats definition
        for _, def in ipairs(wand_stats) do
            if def.property == name then
                if def.object then
                    ComponentObjectSetValue2(ability_comp, def.object, name, value)
                else
                    ComponentSetValue2(ability_comp, name, value)
                end
                break
            end
        end
    end
end

---Reserves the wand stats of a target wand. Used when the player first puts it on the target altar.
---@param altar_id integer
---@param wand_id integer
function Reserve_Wand_Stats(altar_id, wand_id)
    Clear_Old_Reserve_Stats(altar_id)

    local stats = Get_Wand_Stats(wand_id)
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

---Extracts wand stats into a flat table of { name, value_int, _tags } entries.
---@param wand_id integer
---@return table|nil
function Get_Wand_Stats(wand_id)
    local ability_comp = Get_Wand_Ability_Component(wand_id)
    if not ability_comp then return nil end

    local result = {}

    for _, stat in ipairs(wand_stats) do
        local value = Extract_Wand_Stat_Value(ability_comp, stat)

        if value ~= nil then
            result[#result + 1] = {
                name = stat.property,
                value_int = value,
                _tags = target_stat_buffer
            }
        end
    end

    return result
end

---Collect all wand stat tables from the offering altar's wands
---@param offer_altar_id integer
---@return table[] list_of_stat_tables
function Get_Offering_Wand_Stats(offer_altar_id)
    local wand_ids = Get_Wands(offer_altar_id)
    local stat_sets = {}

    for _, wand_id in ipairs(wand_ids) do
        local stats = Get_Wand_Stats(wand_id)
        if stats then
            stat_sets[#stat_sets + 1] = stats
        end
    end

    return stat_sets
end

---Extract a wand stat from the ability component using the stat definitions table.
---@param ability_comp any
---@param stat_def any
---@return any
function Extract_Wand_Stat_Value(ability_comp, stat_def)
    if stat_def.object then
        return ComponentObjectGetValue2(ability_comp, stat_def.object, stat_def.property)
    else
        return ComponentGetValue2(ability_comp, stat_def.property)
    end
end

--== FLASK MERGING ==--

---Check whether a flask has a specific enchantment.
---@param flask_id integer
---@param enchantment_key string
---@return number
function Get_Level_Of_Flask_Enchantment(flask_id, enchantment_key)
    local key = flask_enchant_prefix .. enchantment_key
    local comps = EntityGetComponentIncludingDisabled(flask_id, "VariableStorageComponent") or {}

    for _, comp in ipairs(comps) do
        if ComponentGetValue2(comp, "name") == key then
            return ComponentGetValue2(comp, "value_int")
        end
    end

    return 0
end

--- Reserve the current flask state (materials, enchantments) on the altar
---@param altar_id integer
---@param flask_id integer
function Reserve_Flask_State(altar_id, flask_id)
    -- clear old reservation
    Clear_Old_Reserve_Stats(altar_id)

    -- reserve material contents
    local materials = Get_Flask_Materials(flask_id)
    for mat_id, amount in pairs(materials) do
        EntityAddComponent2(altar_id, "VariableStorageComponent", {
            name = "reserved_material_" .. mat_id,
            value_string = mat_id,
            value_int = amount,
            _tags = target_stat_buffer
        })
    end

    -- reserve enchantments (and their levels)
    for key, _ in pairs(flask_enchantments) do
        local level = Get_Level_Of_Flask_Enchantment(flask_id, key)
        if level > 0 then
            EntityAddComponent2(altar_id, "VariableStorageComponent", {
                name = "reserved_enchant_" .. key,
                value_int = level,
                _tags = target_stat_buffer
            })
        end
    end

    -- reserve capacity of original
    local sucker_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent")
    if sucker_comp then
        local capacity = ComponentGetValue2(sucker_comp, "barrel_size")
        local fill_rate = ComponentGetValue2(sucker_comp, "num_cells_sucked_per_frame")
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_capacity", value_int = capacity, _tags = target_stat_buffer })
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_fill_rate", value_int = fill_rate, _tags = target_stat_buffer })
    end

    local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent")
    if potion_comp then
        local spray_velocity_coeff = ComponentGetValue2(potion_comp, "spray_velocity_coeff")
        local spray_velocity_norm = ComponentGetValue2(potion_comp, "spray_velocity_normalized_min")
        local throw_how_many = ComponentGetValue2(potion_comp, "throw_how_many")
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_spray_velocity_coeff", value_int = spray_velocity_coeff, _tags = target_stat_buffer })
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_spray_velocity_norm", value_int = spray_velocity_norm, _tags = target_stat_buffer })
        EntityAddComponent2(altar_id, "VariableStorageComponent",
            { name = "reserved_throw_how_many", value_int = throw_how_many, _tags = target_stat_buffer })
    end
end

--- Retrieve reserved flask state from the target altar
---@param altar_id integer
---@return table state { materials: {name, amount}, enchantments: {name, level}, capacity: integer }
function Get_Reserved_Flask_State(altar_id)
    local comps = EntityGetComponentIncludingDisabled(altar_id, "VariableStorageComponent") or {}
    local materials = {}
    local enchantments = {}
    local capacity = 0
    local fill_rate = 0
    local spray_velocity_coeff = 0
    local spray_velocity_norm = 0
    local throw_how_many = 0
    for _, comp in ipairs(comps) do
        if ComponentHasTag(comp, target_stat_buffer) then
            local name = ComponentGetValue2(comp, "name")
            if string.sub(name, 1, 18) == "reserved_material_" then
                local mat_id = tonumber(ComponentGetValue2(comp, "value_string")) or 0
                local amount = ComponentGetValue2(comp, "value_int")
                materials[mat_id] = amount
            elseif string.sub(name, 1, 17) == "reserved_enchant_" then
                local key = string.sub(name, 18)
                local level = ComponentGetValue2(comp, "value_int")
                enchantments[key] = level
            elseif name == "reserved_capacity" then
                capacity = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_fill_rate" then
                fill_rate = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_spray_velocity_coeff" then
                spray_velocity_coeff = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_spray_velocity_norm" then
                spray_velocity_norm = ComponentGetValue2(comp, "value_int")
            elseif name == "reserved_throw_how_many" then
                throw_how_many = ComponentGetValue2(comp, "value_int")
            end
        end
    end

    return {
        materials = materials,
        enchantments = enchantments,
        capacity = capacity,
        fill_rate = fill_rate,
        spray_velocity_coeff = spray_velocity_coeff,
        spray_velocity_norm = spray_velocity_norm,
        throw_how_many = throw_how_many
    }
end

---Get and humanely display the combined stats of the result wand for debugging.
---@param target_altar_id any
---@param offer_altar_id any
function Print_Flask_Stats(target_altar_id, offer_altar_id)
    local combined_stats = Get_Combined_Flask_Stats(target_altar_id, offer_altar_id)
    Log("Taking potion:")
    for key, stat in pairs(combined_stats) do
        if type(stat) == "table" then
            Log(key .. " ")
            for inner_key, item in pairs(stat) do
                local name = key == "materials" and CellFactory_GetName(inner_key) or inner_key
                Log(name .. " " .. tostring(item))
            end
        elseif type(stat) == "number" then
            Log(key .. " " .. tostring(stat))
        end
    end
end

---Combine reserved flask state with enchantment effects and merged flask contents.
---@param reserved table original attributes of the target flask
---@param offer_flasks integer[] the ids of the flasks being offered on the altar
---@return table { materials<mat_id,amount>, enchantments<key,level>, capacity, fill_rate,
---@    spray_velocity_coeff, spray_velocity_norm, throw_how_many}
function Combine_Flask_State(reserved, offer_flasks, offer_enhancers)
    local result = {
        materials = {},
        enchantments = {},
        capacity = reserved.capacity or 0,
        fill_rate = reserved.fill_rate or 0,
        spray_velocity_coeff = reserved.spray_velocity_coeff or 0,
        spray_velocity_norm = reserved.spray_velocity_norm or 0,
        throw_how_many = reserved.throw_how_many or 0
    }

    -- Clone reserved materials and enchantments
    local material_map = {}
    for mat_id, mat in pairs(reserved.materials or {}) do
        material_map[mat_id] = (material_map[mat_id] or 0) + mat
    end
    local enchantment_map = {}
    for key, level in pairs(reserved.enchantments or {}) do
        enchantment_map[key] = (enchantment_map[key] or 0) + level
    end

    -- combine offered flasks contents capacity and enchantments
    -- note we do not yet perform negations or limits. Total only.
    for _, flask_id in ipairs(offer_flasks) do
        -- merge contents
        local mat_list = Get_Flask_Materials(flask_id)

        for mat_id, mat in pairs(mat_list) do
            material_map[mat_id] = (material_map[mat_id] or 0) + mat
        end

        -- merge capacities and fill rates
        local suck_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent")
        if suck_comp then
            local merged_capacity = ComponentGetValue2(suck_comp, "barrel_size")
            result.capacity = result.capacity + merged_capacity
            local merged_fill_rate = ComponentGetValue2(suck_comp, "num_cells_sucked_per_frame")
            result.fill_rate = result.fill_rate + merged_fill_rate
        end

        -- merge enchants,
        for key, _ in pairs(flask_enchantments) do
            local flask_enchant_level = Get_Level_Of_Flask_Enchantment(flask_id, key)
            if flask_enchant_level > 0 then
                enchantment_map[key] = (enchantment_map[key] or 0) + flask_enchant_level
            end
        end

        local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent")
        if potion_comp then
            local spray_velocity_coeff = ComponentGetValue2(potion_comp, "spray_velocity_coeff")
            result.spray_velocity_coeff = Approach_Limit(result.spray_velocity_coeff,
                spray_velocity_coeff, velocity_coeff_limit, velocity_limit_step_cap)

            local spray_velocity_norm = ComponentGetValue2(potion_comp, "spray_velocity_normalized_min")
            result.spray_velocity_norm = Approach_Limit(result.spray_velocity_norm,
                spray_velocity_norm, velocity_norm_limit, velocity_limit_step_cap)
            local throw_how_many = ComponentGetValue2(potion_comp, "throw_how_many")
            result.throw_how_many = result.throw_how_many + throw_how_many
            -- at 10k capacity it gets progressively harder to empty flasks and this formula changes
            if result.capacity > 10000 then
                result.throw_how_many = math.floor(reserved.capacity ^ 0.75)
            end
        end
    end

    -- Collapse material map to array
    for key, amount in pairs(material_map) do
        result.materials[key] = amount
    end

    -- add enchantments from the items we've added on the altar.
    for key, def in pairs(flask_enchantments) do
        for _, item in ipairs(offer_enhancers) do
            if def.trigger_item_levels(item) > 0 then
                enchantment_map[key] = (enchantment_map[key] or 0) + def.trigger_item_levels(item)
            end
        end
    end

    -- Negation pass: cancel out conflicting enchantments
    for key, enchantment_level in pairs(enchantment_map) do
        local def = flask_enchantments[key]
        local inverse = def and def.negates
        if inverse and enchantment_map[inverse] then
            local other = enchantment_map[inverse]
            local delta = enchantment_level - other

            if delta > 0 then
                enchantment_map[key] = delta
                enchantment_map[inverse] = nil
            elseif delta < 0 then
                enchantment_map[inverse] = -delta
                enchantment_map[key] = nil
            else
                enchantment_map[key] = nil
                enchantment_map[inverse] = nil
            end
        end
    end

    -- throttle the max level
    for key, _ in pairs(enchantment_map) do
        local def = flask_enchantments[key]
        enchantment_map[key] = math.min(def.max, enchantment_map[key] or 0)
    end

    -- Add enchantments, respecting max level
    for key, _ in pairs(enchantment_map) do
        result.enchantments[key] = enchantment_map[key] or 0
    end

    return result
end

function Approach_Limit(result_stat, merge_stat, limit, step)
    if limit < result_stat then return limit end
    local step_max = (limit - result_stat) * step
    local actual_step = math.min(step_max, merge_stat)
    return math.min(limit, result_stat + actual_step)
end

---Apply the combined flask state to the given flask entity.
---@param flask_id integer
---@param combined table
function Apply_Flask_State(flask_id, combined)
    local comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialInventoryComponent")
    if not comp then return end
    Log("Applying combined state to flask on the target altar for updates")
    -- Apply enchantments
    for key, level in pairs(combined.enchantments or {}) do
        local enchant = flask_enchantments[key]
        Log("Enchant " .. key .. " " .. level)
        if enchant and enchant.apply then enchant.apply(flask_id, level) end
    end

    -- Set combined capacity, warning, it's on a different component
    local sucker_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialSuckerComponent")
    if sucker_comp then
        ComponentSetValue2(sucker_comp, "barrel_size", combined.capacity)
        ComponentSetValue2(sucker_comp, "num_cells_sucked_per_frame", combined.fill_rate)
    end

    -- Set combined capacity, warning, it's on a different component
    local potion_comp = EntityGetFirstComponentIncludingDisabled(flask_id, "PotionComponent")
    if potion_comp then
        ComponentSetValue2(potion_comp, "spray_velocity_coeff", combined.spray_velocity_coeff)
        ComponentSetValue2(potion_comp, "spray_velocity_normalized_min", combined.spray_velocity_norm)
        ComponentSetValue2(potion_comp, "throw_how_many", combined.throw_how_many)
        -- this automatically sets to true because leaking gas with a HUGE flask is super slow
        ComponentSetValue2(potion_comp, "dont_spray_just_leak_gas_materials", false)
        -- this kicks in once flasks are bigger than 10k and it becomes a hassle to empty them
        if combined.capacity > 10000 then
            ComponentSetValue2(potion_comp, "throw_bunch", true)
        end
    end

    -- ONLY FOR THE TARGET TEMPORARILY PART 1
    -- render the flask inert temporarily because this is a bad time to do accident alchemy
    ComponentSetValue2(comp, "do_reactions", 0)
    ComponentSetValue2(comp, "reaction_speed", 0)

    -- ONLY FOR THE TARGET TEMPORARILY PART 2
    -- make the flask immune to physics damage and other damage, is_static makes it shatter
    local phys_comps = EntityGetComponentIncludingDisabled(flask_id, "PhysicsBodyCollisionDamageComponent") or {}
    for _, phys_comp in ipairs(phys_comps) do
        -- default is 0.016667 , set it to 0
        ComponentSetValue2(phys_comp, "damage_multiplier", 0.0)
    end
    local damage_comps = EntityGetComponentIncludingDisabled(flask_id, "DamageModelComponent") or {}
    for _, damage_comp in ipairs(damage_comps) do
        EntitySetComponentIsEnabled(flask_id, damage_comp, false)
    end

    -- this removes all material from the flask by design (empty material_name does it)
    RemoveMaterialInventoryMaterial(flask_id)

    Log("building flask from reserved/combined state:")
    -- Add new materials
    for mat_id, amount in pairs(combined.materials or {}) do
        local material_type = CellFactory_GetName(mat_id)
        Log("Material: " .. material_type .. " x" .. amount)
        AddMaterialInventoryMaterial(flask_id, material_type, amount)
    end
end

---Returns a map of <mat_id,integer> materials inside the flask
---@param flask_id integer
---@return table
function Get_Flask_Materials(flask_id)
    --Log("Getting flask materials")
    local result = {}
    local comp = EntityGetFirstComponentIncludingDisabled(flask_id, "MaterialInventoryComponent")
    if not comp then return result end

    local mats = ComponentGetValue2(comp, "count_per_material_type")
    for mat_id, amount in pairs(mats) do
        -- the material id here is zero based, humorously
        -- offset it back by 1 so we don't *cycle* the materials
        if amount and amount > 0 then result[mat_id - 1] = amount end
    end

    return result
end

---@param target_flask_id integer
---@param target_altar_id integer
---@param offer_altar_id integer
function Calculate_Flask_Stats(target_flask_id, target_altar_id, offer_altar_id)
    local combined_stats = Get_Combined_Flask_Stats(target_altar_id, offer_altar_id)
    local description = Create_Description_From_Stats(combined_stats)
    Set_Custom_Description(target_flask_id, description)
    Apply_Flask_State(target_flask_id, combined_stats)
end

---Return the combined stats of flasks and offered flasks, and enhancers.
---@param target_altar_id any
---@param offer_altar_id any
---@return table
function Get_Combined_Flask_Stats(target_altar_id, offer_altar_id)
    local reserved = Get_Reserved_Flask_State(target_altar_id)
    local offer_flasks = Get_Flasks(offer_altar_id)
    local offer_enhancers = Get_Flask_Enhancers(offer_altar_id)
    return Combine_Flask_State(reserved, offer_flasks, offer_enhancers)
end

---Using the combined stats of the item, create a description for the user
---to give them a better idea of the power of their flask.
---@param combined any
function Create_Description_From_Stats(combined)
    local result = ""
    for key, def in pairs(flask_enchantments) do
        if combined.enchantments[key] and combined.enchantments[key] > 0 then
            local enchant_desc = def.describe(combined, key, combined.enchantments[key])
            result = Append_Description_Line(result, enchant_desc)
        end
    end
    if combined.capacity > 1000 then
        local capacity_description = GameTextGet(barrel_size_localization) .. ": " .. combined.capacity
        result = Append_Description_Line(result, capacity_description)
    end
    if result ~= "" then Log("Description assigned to result item: " .. result) end
    return result
end

---Stitch a line of the description onto the description unless it's the first line/entry.
---@param result any
---@param description_line string
function Append_Description_Line(result, description_line)
    if result then
        result = result .. "\n" .. description_line
    else
        result = description_line
    end
    return result
end

---Add custom verbiage to the name and description to improve QOL by giving important info.
---@param entity_id any
---@param description any
function Set_Custom_Description(entity_id, description)
    if description == "" then return end
    Log("Setting description of result to " .. description)
    -- Try to find an existing UIInfoComponent
    local comp = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
    if comp then
        ComponentSetValue2(comp, "ui_description", description)
    end
end

---Used to set the flask to reactive after being inert while on the target pedestal.
---This is mostly to stop the flask from reacting prematurely, but it can react as soon
---as it is lifted from the altar, so this may not help much.
---@param target_flask_id any
---@param target_altar_id any
---@param offer_altar_id any
function Apply_Inert_And_Reactive_To_Flask(target_altar_id, target_flask_id, offer_altar_id)
    local combined = Get_Combined_Flask_Stats(target_altar_id, offer_altar_id)
    local reactivity = Get_Reactivity_Stats(combined)
    local comp = EntityGetFirstComponentIncludingDisabled(target_flask_id, "MaterialInventoryComponent")
    if reactivity and comp then
        Log("Reactivity " .. reactivity.chance .. " and speed " .. reactivity.speed)
        ComponentSetValue2(comp, "do_reactions", reactivity.chance)
        ComponentSetValue2(comp, "reaction_speed", reactivity.speed)
    end
end

---Returns the reactivity stats based on the combined stats of the flask being output
---Used to fix the reactivity of the flask at the last possible moment, prior to which it is inert.
---Also used to get the reactivity stats for display on the item description.
---@param combined_stats table
---@return table
function Get_Reactivity_Stats(combined_stats)
    local base = 20
    local per = 20
    local level = 0

    local ench = combined_stats.enchantments or {}
    -- inert subtracts, reactive adds
    level = level + (tonumber(ench.reactive) or 0)
    level = level - (tonumber(ench.inert) or 0)

    local cap = tonumber(combined_stats.capacity) or 0
    local react_pixels_base = math.floor(cap / 200)

    local chance = math.min(100, math.max(0, base + per * level))
    local speed = level >= 0 and (react_pixels_base * (2 ^ level)) or react_pixels_base

    return { chance = chance, speed = speed }
end