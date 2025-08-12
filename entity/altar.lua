---@diagnostic disable: lowercase-global, missing-global-doc, deprecated
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/flasks.lua")
dofile_once("mods/offerings/lib/wands.lua")
dofile_once("mods/offerings/lib/logging.lua")

function take(_, altar, eid)
    local isUpper = isUpperAltar(altar)
    if isUpper then
        local lowerAltar = getLowerAltar(altar)
        local upperAltar = isUpper and altar or lowerAltar
        local target = target(upperAltar)
        local function destroyLowerAltarItems()
            local function destroyPredicate(offer)
                if isWand(target) then return isWandEnhancer(offer) end
                if isFlask(target) then return isFlaskEnhancer(offer) end
            end
            local function destroyFunction(offer)
                if isFlask(offer) then RemoveMaterialInventoryMaterial(offer) end
                local x, y = EntityGetTransform(offer)
                EntityLoad("data/entities/particles/destruction.xml", x, y)
                GamePlaySound("data/audio/Desktop/projectiles.bank", "magic/common_destroy", x, y)
                EntityKill(offer)
            end
            eachEntityWhere(linkedItems(lowerAltar), destroyPredicate, destroyFunction)
        end
        destroyLowerAltarItems()
        clearOriginalStats(altar)
    end
    handleAltarLink(altar, eid, false)
    if not isUpper then updateResult(altar) end
end

function updateResult(altar, isRestore)
    local upperAltar = getUpperAltar(altar)
    local target = target(upperAltar)
    if not target then return end
    local lowerAltar = getLowerAltar(altar)
    if isWand(target) then
        setWandResult(target, combineWands(upperAltar, lowerAltar, isRestore))
    elseif isFlask(target) then
        setFlaskResult(target, combineFlasks(upperAltar, lowerAltar, isRestore))
    end
end

function appendDescription(result, description_line)
    if result then
        result = result .. "\n" .. description_line
    else
        result = description_line
    end
    return result
end

function setDescription(eid, description)
    if description == "" then return end    
    local comp = firstComponent(eid, "ItemComponent")
    cSet(comp, "ui_description", description)
end
