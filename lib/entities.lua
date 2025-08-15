--- Items and Entities Utils
dofile_once("mods/offerings/lib/components.lua")
local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

function itemNameContains(eid, s) return hasCompLike(eid, "ItemComponent", nil, "item_name", s) end

function itemNamed(eid, name) return hasCompMatch(eid, "ItemComponent", nil, "item_name", name) end

function entityName(eid) return EntityGetName(eid) end

function isEntityNamed(eid, s) return entityName(eid) == s end

function isInventory(eid) return isEntityNamed(EntityGetParent(eid), "inventory_quick") end

function closest(tag, x, y) return EntityGetClosestWithTag(x, y, tag) end

function closestToEntity(eid, tag) return closest(tag, EntityGetTransform(eid)) end

function eachEntityWhere(eids, pred, func)
    for _, eid in ipairs(eids) do if pred(eid) then func(eid) end end
end