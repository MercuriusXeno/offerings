local VSC = "VariableStorageComponent"

function allComponents(eid, ctype, tag)
  return EntityGetComponentIncludingDisabled(eid, ctype, tag) or {}
end

function firstComponentMatch(eid, ctype, tag, field, value)
  local function valueMatches(comp) return value == ComponentGetValue2(comp, field) end
  return firstComponentLike(eid, ctype, tag, valueMatches)
end

function hasCompMatch(eid, ctype, tag, field, value)
  return firstComponentMatch(eid, ctype, tag, field, value) ~= nil
end

function cGet(comp, field)
  return comp and ComponentGetValue2(comp, field)
end

function cObj(comp, obj, field)
  return comp and obj and ComponentObjectGetValue2(comp, obj, field)
end

function cMatch(comp, field, value)
  return cGet(comp, field) == value
end

function cLike(comp, field, value)
  return cGet(comp, field):find(value)
end

function hasCompLike(eid, ctype, tag, field, value)
  local function likeVal(comp) return cLike(comp, field, value) end
  return firstComponentLike(eid, ctype, tag, likeVal)
end

function firstComponentLike(eid, ctype, tag, func)
  for _, comp in ipairs(allComponents(eid, ctype, tag)) do if func(comp) then return comp end end
  return nil
end

function firstComponent(eid, ctype, tag)
  return EntityGetFirstComponentIncludingDisabled(eid, ctype, tag)
end

function isAnyMatch(eid, ctype, tag, func)
  return firstComponentLike(eid, ctype, tag, func) ~= nil
end

function eachEntityComponent(eid, ctype, tag, func)
  for _, comp in ipairs(allComponents(eid, ctype, tag)) do func(eid, comp) end
end

function eachEntityComponentMatch(eid, ctype, tag, field, val, func)
  for _, comp in ipairs(allComponents(eid, ctype, tag)) do
    if cMatch(comp, field, val) then func(eid, comp) end
  end
end

function eachEntityComponentLike(eid, ctype, tag, field, val, func)
  for _, comp in ipairs(allComponents(eid, ctype, tag)) do
    if cLike(comp, field, val) then func(eid, comp) end
  end
end

function removeAny(eid, ctype, tag)
  eachEntityComponent(eid, ctype, tag, EntityRemoveComponent)
end

function removeMatch(eid, ctype, tag, var, val)
  eachEntityComponentMatch(eid, ctype, tag, var, val, EntityRemoveComponent)
end

function removeLike(eid, ctype, tag, var, val)
  eachEntityComponentLike(eid, ctype, tag, var, val, EntityRemoveComponent)
end

function setValue(comp, var, ...)
  if comp then ComponentSetValue2(comp, var, ...) end
end

function eachComponentSet(eid, ctype, tag, var, ...)
  local comps = allComponents(eid, ctype, tag)
  for _, comp in ipairs(comps) do setValue(comp, var, ...) end
end

function storeInt(eid, name, val)
  EntityAddComponent2(eid, VSC, { name = name, value_int = val })
end

function dropInt(eid, name, val)
  removeMatch(eid, VSC, nil, name, val)
end

function storedInt(eid, name)
  return cGet(firstComponentMatch(eid, VSC, nil, "name", name), "value_int")
end

function storedInts(eid, name)
  local arr = {}
  local function push(_, comp) table.insert(arr, cGet(comp, "value_int")) end
  eachEntityComponentMatch(eid, VSC, nil, "name", name, push)
  return arr
end

function storeString(eid, name, val)
  EntityAddComponent2(eid, VSC, { name = name, value_string = val })
end

function storeFloat(eid, name, val)
  EntityAddComponent2(eid, VSC, { name = name, value_float = val })
end

function storeBool(eid, name, val)
  EntityAddComponent2(eid, VSC, { name = name, value_bool = val })
end

function valueOrDefault(eid, ctype, var, default)
  local comp = EntityGetFirstComponentIncludingDisabled(eid, ctype)
  if comp then return ComponentGetValue2(comp, var) end
  return default
end

function toggleComp(eid, comp, isEnabled)
  EntitySetComponentIsEnabled(eid, comp, isEnabled)
end

function toggleComps(eid, comps, isEnabled)
  for _, comp in ipairs(comps) do toggleComp(eid, comp, isEnabled) end
end

function disableFirstCompLike(eid, ctype, tag, field, value)
  toggleComp(eid, firstComponentMatch(eid, ctype, tag, field, value), false)
end

function enableFirstCompLike(eid, ctype, tag, field, value)
  toggleComp(eid, firstComponentMatch(eid, ctype, tag, field, value), false)
end

function toggleCompsLike(eid, ctype, tag, isEnabled)
  toggleComps(eid, allComponents(eid, ctype, tag), isEnabled)
end

function disableAllComps(eid, ctype, tag)
  toggleCompsLike(eid, ctype, tag, false)
end

function enableAllComps(eid, ctype, tag)
  toggleCompsLike(eid, ctype, tag, true)
end
