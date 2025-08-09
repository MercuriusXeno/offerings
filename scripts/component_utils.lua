-- shorthand because i get tired of the verbose nolla names
local cget = ComponentGetValue2
local ecomps = EntityGetComponentIncludingDisabled

function ecomp_byvar(entity_id, comp_type, var_name, value, tags)
  local comps = ecomps(entity_id, comp_type, tags) or {}
  for _, comp_id in ipairs(comps) do
    if value == cget(comp_id, var_name) then return comp_id end
  end
  return nil
end