dofile_once("data/scripts/lib/utilities.lua")
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util

ModMaterialsFileAdd("mods/offerings/misc/materials.xml")

dofile_once("mods/offerings/translation/append.lua")
dofile_once("mods/offerings/biome/append.lua")
dofile_once("mods/offerings/biome/splice.lua")
function OnPlayerSpawned( player_entity ) -- This runs when player entity has been created
	--local potionGlass = 258
	--local mat = CellFactory_GetName(potionGlass)
	--logger.log("whatever 258 is", mat)
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

function OnWorldInitialized()
	print("Mod - OnWorldInit()") -- when the world is first loaded
end



function OnWorldPreUpdate() -- This is called every time the game is about to start updating the world
	GamePrint( "Pre-update hook " .. tostring(GameGetFrameNum()) )
end

function OnWorldPostUpdate() -- This is called every time the game has finished updating the world
	GamePrint( "Post-update hook " .. tostring(GameGetFrameNum()) )
end
]] --
