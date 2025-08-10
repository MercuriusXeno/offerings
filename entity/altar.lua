---@diagnostic disable: lowercase-global, missing-global-doc, deprecated
dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/lib/components.lua")
dofile_once("mods/offerings/lib/entities.lua")
dofile_once("mods/offerings/lib/flasks.lua")
dofile_once("mods/offerings/lib/wands.lua")
dofile_once("mods/offerings/lib/logging.lua")

local VSC = "VariableStorageComponent"

function take(_, altar, eid)
    local isUpper = isUpperAltar(altar)
    if isUpper then
        local lowerAltar = getLowerAltar(altar)
        if isFlask(eid) then
            setFlaskReactivity(altar, eid, lowerAltar)
            setFlaskDamageModelsAndPhysicsBodyDamage(altar, eid, lowerAltar)
        end

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

function updateResult(altar)
    -- find the offering altar
    local upperAltar = getUpperAltar(altar)
    local target = target(upperAltar)

    if not target then return end

    -- determine if the recipe is a wand or flask
    local lowerAltar = getLowerAltar(altar)
    if isWand(target) then
        local combined = combinedWands(upperAltar, lowerAltar)
        setWandResult(target, combined)
    elseif isFlask(target) then
        setFlaskResult(target, upperAltar, lowerAltar)
    end
    printItemStats(target, upperAltar, lowerAltar)
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
    debugOut("Setting description of result to " .. description)
    -- Try to find an existing UIInfoComponent
    local comp = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
    if comp then
        ComponentSetValue2(comp, "ui_description", description)
    end
end
