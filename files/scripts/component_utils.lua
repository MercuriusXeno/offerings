function EntityGetFirstComponentWithVariable(entity_id, component_type_name, variable_name, variable_value, tags)
  local components = nil
  if tags ~= nil then
    components = EntityGetComponentIncludingDisabled(entity_id, component_type_name, tags)
  else
    components = EntityGetComponentIncludingDisabled(entity_id, component_type_name)
  end
  if components == nil then
    return nil
  end
  for i,component_id in ipairs(components) do
    local val = ComponentGetValue2(component_id, variable_name)
    if variable_value == val or (variable_value == nil and val ~= nil) then
      return component_id
    end
  end
  return nil
end
