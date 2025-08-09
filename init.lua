dofile_once("data/scripts/lib/utilities.lua")
dofile_once("mods/offerings/scripts/debug.lua")
dofile_once("mods/offerings/scripts/setting_constants.lua")
dofile_once("mods/offerings/translations/append_localizations.lua")

-- cursed biome splice for altar_left which hates me and wants me to be unhappy.
if ModImageMakeEditable then
    local splice = function(original, splice, splice_x, splice_y)
        local id, _, _ = ModImageMakeEditable(original, 0, 0)
        local splice_id, end_x, end_y = ModImageMakeEditable(splice, 0, 0)
        for y = splice_y, splice_y + end_y - 1 do
            for x = splice_x, splice_x + end_x - 1 do
                local c = ModImageGetPixel(splice_id, x - splice_x, y - splice_y)
                local r, g, b, a = color_abgr_split(c)
                -- clear or black [material] gets ignored - don't splice negative spaces
                if a > 0 and r + g + b > 0 then ModImageSetPixel(id, x, y, c) end
            end
        end
    end
    -- the material splice is a bit wider than the visual splice
    splice("data/biome_impl/temple/altar_left.png", "mods/offerings/biomes/temple/altar_left.png", 305, 86)
    splice("data/biome_impl/temple/altar_left_visual.png", "mods/offerings/biomes/temple/altar_left_visual.png",
        314, 86)
end

dofile_once("mods/offerings/biomes/append_biomes.lua")

local emit_last_key = "offerings.emit_last"
function OnWorldInitialized()          -- This is called once the game world is initialized. Doesn't ensure any world chunks actually exist. Use OnPlayerSpawned to ensure the chunks around player have been loaded or created.	
    -- Some global stuff I do for debugs to make my brain hurt less
    GlobalsSetValue(emit_last_key, "-60") -- this is for particles for showing stuff works
end

--[[
function OnModPreInit()
	print("Mod - OnModPreInit()") -- First this is called for all mods
end

function OnModInit()
	print("Mod - OnModInit()") -- After that this is called for all mods
end

function OnModPostInit()
	print("Mod - OnModPostInit()") -- Then this is called for all mods
end

function OnPlayerSpawned( player_entity ) -- This runs when player entity has been created
	GamePrint( "OnPlayerSpawned() - Player entity id: " .. tostring(player_entity) )
end

function OnWorldPreUpdate() -- This is called every time the game is about to start updating the world
	GamePrint( "Pre-update hook " .. tostring(GameGetFrameNum()) )
end

function OnWorldPostUpdate() -- This is called every time the game has finished updating the world
	GamePrint( "Post-update hook " .. tostring(GameGetFrameNum()) )
end
]] --
