---@class FlaskStats
---@

dofile_once("mods/offerings/lib/components.lua")

function holderFlaskAbilities(altar)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for _, child in ipairs(children) do
        local ability = firstComponent(child, "AbilityComponent", nil)
        result[#result + 1] = ability
    end
    return result
end
