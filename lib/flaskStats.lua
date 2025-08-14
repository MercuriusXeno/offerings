---@class FlaskStats
---@


function holderFlaskAbilities(altar)
    local result = {}
    local children = EntityGetAllChildren(altar) or {}
    for i = 1, #children do
        local child = children[i]
        local ability = firstComponent(child, "AbilityComponent", nil)
        result[#result+1] = ability
    end
    return result
end