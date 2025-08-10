local VSC = "VariableStorageComponent"
local originalStats = "original_stats_"

function componentsOfType(eid, ctype, tag)
  return EntityGetComponentIncludingDisabled(eid, ctype, tag) or {}
end

function componentsWhere(eid, ctype, tag, pred)
  local arr = {}  
  local function push(comp) arr[#arr+1] = comp end
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do
    if pred(comp) then push(comp) end
  end
  return arr
end

function componentsMatching(eid, ctype, tag, field, val)
  local function match(comp) return cMatch(comp, field, val) end
  return componentsWhere(eid, ctype, tag, match)
end

function componentsLike(eid, ctype, tag, field, val)
  local function like(comp) return cLike(comp, field, val) end
  return componentsWhere(eid, ctype, tag, like)
end

function eachEntityComponent(eid, ctype, tag, func)
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do func(eid, comp) end
end

function eachEntityComponentWhere(eid, ctype, tag, pred, func)
  for _, comp in componentsWhere(eid, ctype, tag, pred) do func(eid, comp) end
end

function eachEntityComponentMatching(eid, ctype, tag, field, val, func)
  local function pred(comp) return cMatch(comp, field, val) end
  eachEntityComponentWhere(eid, ctype, tag, pred, func)
end

function eachEntityComponentLike(eid, ctype, tag, field, val, func)
  local function pred(comp) return cLike(comp, field, val) end
  eachEntityComponentWhere(eid, ctype, tag, pred, func)
end

function removeAny(eid, ctype, tag)
  eachEntityComponent(eid, ctype, tag, EntityRemoveComponent)
end

function removeMatch(eid, ctype, tag, field, val)
  eachEntityComponentMatching(eid, ctype, tag, field, val, EntityRemoveComponent)
end

function removeLike(eid, ctype, tag, field, val)
  eachEntityComponentLike(eid, ctype, tag, field, val, EntityRemoveComponent)
end

function firstComponent(eid, ctype, tag)
  return EntityGetFirstComponentIncludingDisabled(eid, ctype, tag)
end

function firstComponentWhere(eid, ctype, tag, func)
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do if func(comp) then return comp end end
  return nil
end

function firstComponentMatching(eid, ctype, tag, field, value)
  local function valueMatches(comp) return cMatch(comp, field, value) end
  return firstComponentWhere(eid, ctype, tag, valueMatches)
end

function firstComponentLike(eid, ctype, tag, field, value)
  local function valueLike(comp) return cLike(comp, field, value) end
  return firstComponentWhere(eid, ctype, tag, valueLike)
end

function isAnyMatch(eid, ctype, tag, func)
  return firstComponentWhere(eid, ctype, tag, func) ~= nil
end

function hasCompLike(eid, ctype, tag, field, value)
  return firstComponentLike(eid, ctype, tag, field, value) ~= nil
end

function hasCompMatch(eid, ctype, tag, field, value)
  return firstComponentMatching(eid, ctype, tag, field, value) ~= nil
end

function cGet(comp, field)
  return comp and ComponentGetValue2(comp, field)
end

function cSet(comp, field, ...)
  ComponentSetValue2(comp, field, ...)
end

function cObjGet(comp, obj, field)
  return comp and obj and ComponentObjectGetValue2(comp, obj, field)
end

function cObjSet(comp, obj, field, ...)
  ComponentObjectSetValue2(comp, obj, field, ...)
end

function cMatch(comp, field, value)
  return cGet(comp, field) == value
end

function cLike(comp, field, value)
  return cGet(comp, field):find(value)
end

function setValue(comp, field, ...)
  if comp then ComponentSetValue2(comp, field, ...) end
end

function eachComponentSet(eid, ctype, tag, field, ...)
  local comps = componentsOfType(eid, ctype, tag)
  for _, comp in ipairs(comps) do setValue(comp, field, ...) end
end

function store(eid, name, ...)
  local vsc = { name = name }
  local i = 1
  while i <= select("#", ...) do
    local t = select(i, ...)
    local v = select(i + 1, ...)
    vsc[t] = v
    i = i + 2
  end
  EntityAddComponent2(eid, VSC, vsc)
end

function dropStoredMatch(eid, name, val) removeMatch(eid, VSC, nil, name, val) end

function dropStoredLike(eid, name, val) removeLike(eid, VSC, nil, name, val) end

-- vsc storage abstractions to make it kinda brainless
local vscFields = { "name", "value_int", "value_string", "value_bool", "value_float" }

function storedMatching(eid, name, specificField)
  local vscs = {}
  local function push(_, comp) vscs[#vscs+1] = unboxVsc(comp, specificField) end
  eachEntityComponentMatching(eid, VSC, nil, "name", name, push)
  return vscs
end

function unboxVsc(comp, specificField)
  local t = {}
  local function push(field) t[field] = cGet(comp, field) end
  for _, field in ipairs(vscFields) do
    if not specificField or field == specificField then push(field) end
  end
  return t
end

function firstStored(eid, name, specificField)
  return unboxVsc(firstComponentMatching(eid, VSC, nil, "name", name), specificField)
end

function storedsLike(eid, name, specificField)
  local vscs = {}
  local function push(_, comp) vscs[#vscs+1] = unboxVsc(comp, specificField) end
  eachEntityComponentLike(eid, VSC, nil, "name", name, push)
  return vscs
end

-- vsc storage abstractions with more specific in/out behaviors to reduce overhead
function storeInt(eid, name, val) store(eid, name, "value_int", val) end

function storeFloat(eid, name, val) store(eid, name, "value_float", val) end

function storedInt(eid, name) return storedMatching(eid, name, "value_int") end

function storedInts(eid, name)
  local vscs = storedMatching(eid, name, "value_int")
  local arr = {}
  for _, vsc in ipairs(vscs) do if vsc.value_int then arr[#arr+1] = vsc.value_int end end
  return arr
end

function clearOriginalStats(altar) removeLike(altar, VSC, nil, "name", originalStats) end

function valueOrDefault(eid, ctype, field, default)
  local comp = EntityGetFirstComponentIncludingDisabled(eid, ctype)
  if comp then return ComponentGetValue2(comp, field) end
  return default
end

function toggleComp(eid, comp, isEnabled) EntitySetComponentIsEnabled(eid, comp, isEnabled) end

function toggleComps(eid, comps, isEnabled)
  for _, comp in ipairs(comps) do toggleComp(eid, comp, isEnabled) end
end

function disableFirstCompLike(eid, ctype, tag, field, value)
  toggleComp(eid, firstComponentMatching(eid, ctype, tag, field, value), false)
end

function enableFirstCompLike(eid, ctype, tag, field, value)
  toggleComp(eid, firstComponentMatching(eid, ctype, tag, field, value), false)
end

function toggleCompsLike(eid, ctype, tag, isEnabled)
  toggleComps(eid, componentsOfType(eid, ctype, tag), isEnabled)
end

function disableAllComps(eid, ctype, tag) toggleCompsLike(eid, ctype, tag, false) end

function enableAllComps(eid, ctype, tag) toggleCompsLike(eid, ctype, tag, true) end