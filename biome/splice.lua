dofile_once("data/scripts/lib/utilities.lua")

-- cursed biome splice for altar_left which hates me and wants me to be unhappy.
if ModImageMakeEditable then
    local splice = function(original, splice, x_origin, y_origin)
        local id, _, _ = ModImageMakeEditable(original, 0, 0)
        local splice_id, width, height = ModImageMakeEditable(splice, 0, 0)
        for y = y_origin, y_origin + height - 1 do
            for x = x_origin, x_origin + width - 1 do
                local c = ModImageGetPixel(splice_id, x - x_origin, y - y_origin)
                local r, g, b, a = color_abgr_split(c)
                -- clear or black [material] gets ignored - don't splice negative spaces
                if a > 0 and r + g + b > 0 then ModImageSetPixel(id, x, y, c) end
            end
        end
    end
    -- the material splice is a bit wider than the visual splice
    splice("data/biome_impl/temple/altar_left.png",
        "mods/offerings/biome/temple/altar_left.png", 305, 86)
    splice("data/biome_impl/temple/altar_left_visual.png",
        "mods/offerings/biome/temple/altar_left_visual.png", 314, 86)
end
