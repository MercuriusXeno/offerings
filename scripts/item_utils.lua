function Is_Flask(item_id) return EntityHasTag(item_id, "potion") or Is_Named(item_id, "$item_cocktail") end

function Is_Wand(item_id) return EntityHasTag(item_id, "wand") end

---Detects if an item is a tablet based on tags
---@param item_id integer
---@return integer
function Detect_Tablet(item_id)
    if not EntityHasTag(item_id, "tablet") then return 0 end
    -- stone tablets remove all reactive and add inert
    if EntityHasTag(item_id, "forged_tablet") then return 5 end
    if EntityHasTag(item_id, "normal_tablet") then return 1 end
    -- idk why not just default instead of normal tablet, but this is in case there is a fall through?
    return 1
end

---Detects if an item is a Book or Notes on Grand Alchemy based on tags and internal strings
---@param item_id integer
---@return integer
function Detect_Scroll(item_id)
    if not EntityHasTag(item_id, "scroll") then return 0 end

    local comps = EntityGetComponentIncludingDisabled(item_id, "ItemComponent") or {}
    for _, comp in ipairs(comps) do
        local name = ComponentGetValue2(comp, "item_name")
        if name:find("book_s_") then
            return 5 -- notes on grand alchemy max out reactivity
        end
    end
    return 1
end

---Detects if an item is a brimstone based on tags
---@param item_id integer
---@return integer
function Detect_Kiauskivi(item_id)
    if EntityHasTag(item_id, "brimstone") then return 1 end
    return 0
end

---Detects if an item is a thunderstone based on tags
---@param item_id integer
---@return integer
function Detect_Ukkoskivi(item_id)
    if EntityHasTag(item_id, "thunderstone") then return 1 end
    return 0
end

---Detects if an item is a potion mimic based on item name
---@param item_id integer
---@return integer
function Detect_Potion_Mimic(item_id)
    if Is_Named(item_id, "$item_potion_mimic") then return 1 end
    return 0
end

---Detects if an item is a vuoksikivi based on tags
---@param item_id integer
---@return integer
function Detect_Vuoksikivi(item_id)
    if EntityHasTag(item_id, "waterstone") then return 1 end
    return 0
end

---Returns true if the item entity has an item component which matches
---the name input provided. This is the localization name eg. $item_brimstone
---@param entity_id any
---@param which_item any
---@return boolean
function Is_Named(entity_id, which_item)
    local item_comp = EntityGetFirstComponent(entity_id, "ItemComponent")
    if item_comp then return ComponentGetValue2(item_comp, "item_name") == which_item end
    return false
end
