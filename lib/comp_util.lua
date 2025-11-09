local util = dofile_once("mods/offerings/lib/util.lua") ---@type offering_util

local VSC = "VariableStorageComponent"

---@class Vsc
---@field name? string|nil
---@field value_int? integer|nil
---@field value_bool? boolean|nil
---@field value_float? number|nil
---@field value_string? string|nil

-- vsc storage abstractions to make it kinda brainless - excludes name on purpose
local vscFields = { "value_int", "value_string", "value_bool", "value_float" }

local function componentsOfType(eid, ctype, tag)
  if tag ~= nil then
    return EntityGetComponentIncludingDisabled(eid, ctype, tag) or {}
  else
    return EntityGetComponentIncludingDisabled(eid, ctype) or {}
  end
end

local function componentsWhere(eid, ctype, tag, pred)
  local arr = {}
  local function push(comp) arr[#arr + 1] = comp end
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do
    if pred(comp) then push(comp) end
  end
  return arr
end

---Return an object's property in a comp
---@param comp component_id?
---@param field string the field name
---@return any
local function component_get(comp, field)
  if not comp then return nil end
  local v = { ComponentGetValue2(comp, field) }
  if #v == 1 then return v[1] end
  return v
end

local function component_set(comp, field, ...)
  ComponentSetValue2(comp, field, ...)
end

---Return the object property defined in a comp that is nested in an object
---@param comp component_id
---@param obj string the object name
---@param field string the field name
---@return any
local function cObjGet(comp, obj, field)
  return comp and obj and ComponentObjectGetValue2(comp, obj, field)
end

local function cObjSet(comp, obj, field, ...)
  ComponentObjectSetValue2(comp, obj, field, ...)
end

local function cMatch(comp, field, val)
  local compVal = component_get(comp, field)
  if type(val) == "table" and type(compVal) == "table" then return util.arrayEquals(val, compVal) end
  return val == compVal
end

local function cLike(comp, field, value)
  return component_get(comp, field):find(value)
end

-- Iteration helpers
local function eachEntityComponent(eid, ctype, tag, func)
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do func(eid, comp) end
end

local function eachEntityComponentWhere(eid, ctype, tag, pred, func)
  for _, comp in ipairs(componentsWhere(eid, ctype, tag, pred)) do func(eid, comp) end
end

local function eachEntityComponentMatching(eid, ctype, tag, field, val, func)
  local function pred(comp) return cMatch(comp, field, val) end
  eachEntityComponentWhere(eid, ctype, tag, pred, func)
end

local function eachEntityComponentLike(eid, ctype, tag, field, val, func)
  local function pred(comp) return cLike(comp, field, val) end
  eachEntityComponentWhere(eid, ctype, tag, pred, func)
end

-- First/getters
local function first_component(eid, ctype, tag)
  if tag == nil then
    return EntityGetFirstComponentIncludingDisabled(eid, ctype) or nil
  else
    return EntityGetFirstComponentIncludingDisabled(eid, ctype, tag) or nil
  end
end

local function firstComponentWhere(eid, ctype, tag, func)
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do if func(comp) then return comp end end
  return nil
end

local function firstComponentMatching(eid, ctype, tag, field, value)
  local function valueMatches(comp) return cMatch(comp, field, value) end
  return firstComponentWhere(eid, ctype, tag, valueMatches)
end

local function firstComponentLike(eid, ctype, tag, field, value)
  local function valueLike(comp) return cLike(comp, field, value) end
  return firstComponentWhere(eid, ctype, tag, valueLike)
end

-- Predicates (these are exported, but defined local then re-exported)
local function hasCompLike(eid, ctype, tag, field, value)
  return firstComponentLike(eid, ctype, tag, field, value) ~= nil
end

local function hasCompMatch(eid, ctype, tag, field, value)
  return firstComponentMatching(eid, ctype, tag, field, value) ~= nil
end

-- Toggle/enable/disable
local function toggleComp(eid, comp, isEnabled)
  if comp then EntitySetComponentIsEnabled(eid, comp, isEnabled) end
end

local function toggle_first_comp_matching(eid, ctype, tag, field, value, isEnabled)
  toggleComp(eid, firstComponentMatching(eid, ctype, tag, field, value), isEnabled)
end

local function toggleComps(eid, ctype, tag, isEnabled)
  local function flip(e, comp) toggleComp(e, comp, isEnabled) end
  eachEntityComponent(eid, ctype, tag, flip)
end

-- Bulk setters
local function eachComponentSet(eid, ctype, tag, field, ...)
  local comps = componentsOfType(eid, ctype, tag)
  for _, comp in ipairs(comps) do component_set(comp, field, ...) end
end

-- Removal helpers
local function removeAll(eid, ctype, tag)
  eachEntityComponent(eid, ctype, tag, EntityRemoveComponent)
end

local function removeMatch(eid, ctype, tag, field, val)
  eachEntityComponentMatching(eid, ctype, tag, field, val, EntityRemoveComponent)
end

-- VSC storage helpers
local function store(eid, name, ...)
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

local function unboxVsc(comp, specificField)
  if not comp then return nil end
  return component_get(comp, specificField)
end

local function boxVsc(comp)
  if not comp then return nil end
  local t = {}
  local function push(field) t[field] = component_get(comp, field) end
  push("name") -- always push name!
  for _, field in ipairs(vscFields) do push(field) end
  return t
end

local function firstStored(eid, name, specificField) ---@return any
  return unboxVsc(firstComponentMatching(eid, VSC, nil, "name", name), specificField)
end

local function storedsLike(eid, name, specificField, isSkippingZero)
  local vscs = {}
  local function push(_, comp)
    local vsc = unboxVsc(comp, specificField)
    if not isSkippingZero or (specificField ~= nil and vsc and vsc[specificField] ~= 0) then
      vscs[#vscs + 1] = vsc
    end
  end
  eachEntityComponentLike(eid, VSC, nil, "name", name, push)
  return vscs
end

local function storedBoxesLike(eid, name, specificField, isSkippingZero)
  local vscs = {}
  local function push(_, comp)
    local vsc = boxVsc(comp)
    if not isSkippingZero or (specificField ~= nil and vsc and vsc[specificField] ~= 0) then
      vscs[#vscs + 1] = vsc
    end
  end
  eachEntityComponentLike(eid, VSC, nil, "name", name, push)
  return vscs
end

local function storeInt(eid, name, val) store(eid, name, "value_int", val) end
local function storeFloat(eid, name, val) store(eid, name, "value_float", val) end
local function storedInt(eid, name) return firstStored(eid, name, "value_int") end ---@return integer
local function storedFloat(eid, name) return firstStored(eid, name, "value_float") end

local function valueOrDefault(eid, ctype, field, default)
  local comp = EntityGetFirstComponentIncludingDisabled(eid, ctype)
  if comp then return ComponentGetValue2(comp, field) end
  return default
end

local M = {}---@class offering_component_util

M.component_get = component_get
M.component_object_get = cObjGet
M.component_object_set = cObjSet
M.component_set = component_set

M.each_component_set = eachComponentSet
M.eachEntityComponent = eachEntityComponent

M.first_component = first_component
M.firstComponentMatching = firstComponentMatching

M.hasCompLike = hasCompLike
M.has_comp_match = hasCompMatch

M.remove_all_comps = removeAll
M.removeMatch = removeMatch

M.storeFloat = storeFloat
M.store_int = storeInt

M.storedFloat = storedFloat
M.get_int = storedInt

M.storedBoxesLike = storedBoxesLike
M.storedsLike = storedsLike
M.toggleComp = toggleComp
M.toggle_comps = toggleComps
M.toggle_first_comp_matching = toggle_first_comp_matching

M.valueOrDefault = valueOrDefault

return M
