---@diagnostic disable: lowercase-global, missing-global-doc
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/scripts/item_utils.lua")
dofile_once("mods/offerings/scripts/altar.lua")
dofile_once("mods/offerings/scripts/debug.lua")


-- big chunk of setup is mostly to get the  and the entities within it
function Detect_Entities()
    local target_altar_tag = "target_altar"
    local altar_id = GetUpdatedEntityID()
    local is_target_altar = EntityHasTag(altar_id, target_altar_tag)
    local target_altar_width = 25
    local target_altar_radius = (target_altar_width + 1) / 2
    local offer_altar_width = 58
    local offer_altar_radius = (offer_altar_width + 1) / 2
    local radius = is_target_altar and target_altar_radius or offer_altar_radius
    local box_height = 10
    local altar_x, altar_y = EntityGetTransform(altar_id)
    local left_bound = altar_x - radius
    local right_bound = altar_x + radius
    local upper_bound = altar_y - box_height
    local lower_bound = altar_y + 1
    local near_entities = EntityGetInRadius(altar_x, altar_y, radius)

    -- get the target altar of this altar room if it isn't the target altar
    local target_altar_id = is_target_altar and altar_id or Get_Target_Altar(altar_id)

    -- get the target of the altar room, assuming it exists
    local target_id = Get_Target(target_altar_id)

    for _, entity_id in ipairs(near_entities) do
        local is_valid = is_target_altar and Is_Valid_Target(entity_id) or Is_Valid_Offer(target_id, entity_id)
        if is_valid and not Is_Attached_To_Altar(altar_id, entity_id) then
            local entity_x, entity_y = EntityGetTransform(entity_id)
            if entity_x >= left_bound and entity_x <= right_bound and entity_y >= upper_bound and entity_y <= lower_bound then
                Collide(altar_id, entity_id, is_target_altar, target_id)
            end
        end
    end
end

---Common logic shared by either altar for doing collisions with items.
---Attaches a pickup script to the item which will unlink it from the altar.
---Makes it hover as needed.
---@param item_id any
function Collide(altar_id, item_id, is_target_altar, target_id)
    -- either we are targeting a new item or offering to improve a target
    local is_new_target = is_target_altar and not target_id
    local is_valid_offering = not is_target_altar and not is_new_target and Is_Type_Matched(target_id, item_id)
    local is_adding_item = is_new_target or is_valid_offering
    
    if is_new_target then
        is_adding_item = true
        
        if Is_Wand(item_id) then Reserve_Wand_Stats(altar_id, item_id) end
        if Is_Flask(item_id) then Reserve_Flask_State(altar_id, item_id) end        
        
        -- target altar holds 1 at most, disable collision
        Set_Target_Altar_Collision(altar_id, false)
    end

    if is_adding_item then Add_Altar_Item(altar_id, item_id) end
end

Detect_Entities()


---Returns true if the item ids passed in are both wands, or both flasks, otherwise false.
---@param target_item_id any
---@param offer_item_id any
---@return boolean
function Is_Type_Matched(target_item_id, offer_item_id)
    -- wands can, for the moment, only consume other wands
    return (Is_Wand(target_item_id) and Is_Wand(offer_item_id))
        -- flasks merge with flasks but also have book/tablet enhancements that are specific to flasks
        or (Is_Flask(target_item_id) and (Is_Flask(offer_item_id) or Is_Flask_Enhancer(offer_item_id)))
end

---Returns true if the item passed in is a flask or wand
---@param entity_id any
---@return boolean
function Is_Valid_Target(entity_id)
    -- don't collide with the player's inventory
    if EntityHasTag(entity_id, workshop_altar_tag) or Is_Inventory(entity_id) then return false end
    return Is_Wand(entity_id) or Is_Flask(entity_id)
end

---Returns true if the item passed in is a flask or wand
---@param entity_id any
---@return boolean
function Is_Valid_Offer(target_id, entity_id)
    -- don't collide with the player's inventory
    if EntityHasTag(entity_id, workshop_altar_tag) or Is_Inventory(entity_id) then return false end
    return Is_Type_Matched(target_id, entity_id)
        and (Is_Wand(entity_id) or Is_Flask(entity_id) or Is_Flask_Enhancer(entity_id))
end