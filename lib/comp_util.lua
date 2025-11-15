local util = dofile_once("mods/offerings/lib/util.lua") ---@type offering_util
local logger = dofile_once("mods/offerings/lib/log_util.lua") ---@type log_util
local VSC = "VariableStorageComponent"

---@class Vsc
---@field name? string|nil
---@field value_int? integer|nil
---@field value_bool? boolean|nil
---@field value_float? number|nil
---@field value_string? string|nil

-- vsc storage abstractions to make it kinda brainless - excludes name on purpose
local VSC_FIELDS = { "value_int", "value_string", "value_bool", "value_float" }

local M = {} ---@class offering_component_util

---Return all components matching the type and tag provided
---@param eid entity_id
---@param ctype string
---@param tag? string
---@return component_id[]
function M.get_components_by_type_and_tag(eid, ctype, tag)
  if tag ~= nil then
    return EntityGetComponentIncludingDisabled(eid, ctype, tag) or {}
  else
    return EntityGetComponentIncludingDisabled(eid, ctype) or {}
  end
end

---Return all components matching the predicate supplied in arguments.
---@param eid entity_id
---@param ctype string
---@param tag? string
---@param pred fun(comp: component_id):boolean The predicate to match the components with
---@return table
function M.get_components_matching_predicate(eid, ctype, tag, pred)
  local arr = {}
  local function push(comp) arr[#arr + 1] = comp end
  for _, comp in ipairs(M.get_components_by_type_and_tag(eid, ctype, tag)) do
    if pred(comp) then push(comp) end
  end
  return arr
end

---Return an object's property in a comp
---@param comp? component_id
---@param field string the field name
---@return any
function M.get_component_value(comp, field)
  if not comp then return nil end
  local v = { ComponentGetValue2(comp, field) }
  if #v == 1 then return v[1] end
  return v
end

---@class vector2
---@field x number
---@field y number

---Return an object's property in a comp
---@param comp? component_id
---@param field string the field name
---@return vector2
function M.get_component_value_vector(comp, field)
  ---@type number[]
  local v = M.get_component_value(comp, field)
  logger.peek("vectors look like", v)
  ---@type vector2
  return { x = v[1], y = v[2] }
end

---Set the value of a component field, can take table arguments
---@param comp? component_id
---@param field string
---@param x number
---@param y number
function M.set_component_value_vector(comp, field, x, y)
  if comp then ComponentSetValue2(comp, field, x, y) end
end

---Set the value of a component field, can take table arguments
---@param comp? component_id
---@param field string
---@param ... any|table
function M.set_component_value(comp, field, ...)
  if comp then ComponentSetValue2(comp, field, ...) end
end

---Return the object property defined in a comp that is nested in an object
---@param comp component_id
---@param obj string the object name
---@param field string the field name
---@return any
function M.get_component_object_value(comp, obj, field)
  return comp and obj and ComponentObjectGetValue2(comp, obj, field)
end

function M.set_component_object_value(comp, obj, field, ...)
  ComponentObjectSetValue2(comp, obj, field, ...)
end

function M.is_component_field_value_equal(comp, field, val)
  local compVal = M.get_component_value(comp, field)
  if type(val) == "table" and type(compVal) == "table" then return util.arrayEquals(val, compVal) end
  return val == compVal
end

function M.is_component_field_value_like(comp, field, value)
  return M.get_component_value(comp, field):find(value)
end

---Iterate over each component and execute a delegate on it
---@param eid entity_id the entity whose components we're iterating
---@param ctype string the component type to iterate
---@param tag? string a tag to filter the component by if applicable
---@param func fun(entity_id: entity_id, comp: component_id) the function to execute
function M.each_component(eid, ctype, tag, func)
  for _, comp in ipairs(M.get_components_by_type_and_tag(eid, ctype, tag)) do func(eid, comp) end
end

function M.each_component_where(eid, ctype, tag, pred, func)
  for _, comp in ipairs(M.get_components_matching_predicate(eid, ctype, tag, pred)) do func(eid, comp) end
end

function M.each_component_of_type_with_field_matching(eid, ctype, tag, field, val, func)
  local function is_value_match(comp) return M.is_component_field_value_equal(comp, field, val) end
  M.each_component_where(eid, ctype, tag, is_value_match, func)
end

function M.each_component_of_type_with_field_like(eid, ctype, tag, field, val, func)
  local function is_value_like(comp) return M.is_component_field_value_like(comp, field, val) end
  M.each_component_where(eid, ctype, tag, is_value_like, func)
end

function M.get_or_create_comp(eid, ctype, tag)
  local default = {}
  if tag ~= nil then default._tags = tag end
  return M.first_component(eid, ctype, tag) or EntityAddComponent2(eid, ctype, default)
end

---Return the first component matching the type and tag provided.
---@param eid entity_id
---@param ctype string
---@param tag? string
---@return component_id?
function M.first_component(eid, ctype, tag)
  if tag == nil then
    return EntityGetFirstComponentIncludingDisabled(eid, ctype) or nil
  else
    return EntityGetFirstComponentIncludingDisabled(eid, ctype, tag) or nil
  end
end

function M.first_component_where(eid, ctype, tag, func)
  local result = nil
  for _, comp in ipairs(M.get_components_by_type_and_tag(eid, ctype, tag)) do
    if func(comp) then
      result = comp
      break
    end
  end
  return result
end

function M.first_component_of_type_with_field_equal(eid, ctype, tag, field, value)
  local function is_value_equal(comp) return M.is_component_field_value_equal(comp, field, value) end
  return M.first_component_where(eid, ctype, tag, is_value_equal)
end

function M.first_component_of_type_with_field_like(eid, ctype, tag, field, value)
  local function is_value_like(comp) return M.is_component_field_value_like(comp, field, value) end
  return M.first_component_where(eid, ctype, tag, is_value_like)
end

---Return a component whose field *resembles* the field value provided.
---@param eid entity_id
---@param ctype string
---@param tag string|nil
---@param field string
---@param value any
---@return boolean
function M.has_component_field_value_like(eid, ctype, tag, field, value)
  return M.first_component_of_type_with_field_like(eid, ctype, tag, field, value) ~= nil
end

---Return a component whose field exactly equals the field value provided.
---@param eid entity_id
---@param ctype string
---@param tag string|nil
---@param field string
---@param value any
---@return boolean
function M.has_component_of_type_with_field_equal(eid, ctype, tag, field, value)
  return M.first_component_of_type_with_field_equal(eid, ctype, tag, field, value) ~= nil
end

---Enable or disable a component (from argument, explicitly)
---@param eid entity_id
---@param comp? component_id the component being disabled. if nil, this aborts eagerly.
---@param is_enabled boolean
function M.toggle_component(eid, comp, is_enabled)
  if comp then EntitySetComponentIsEnabled(eid, comp, is_enabled) end
end

---Enable or disable the first component (from argument, explicitly) matching the arguments provided.
---@param eid entity_id
---@param ctype string
---@param tag? string
---@param field string
---@param value any
---@param is_enabled boolean
function M.toggle_first_comp_matching(eid, ctype, tag, field, value, is_enabled)
  M.toggle_component(eid, M.first_component_of_type_with_field_equal(eid, ctype, tag, field, value), is_enabled)
end

---Enable or disable all components (from argument, explicitly) matching the arguments provided.
---@param eid entity_id
---@param ctype string
---@param tag? string
---@param is_enabled boolean
function M.toggle_components_by_type_and_tag(eid, ctype, tag, is_enabled)
  local function flip(e, comp) M.toggle_component(e, comp, is_enabled) end
  M.each_component(eid, ctype, tag, flip)
end

---Iterate over all components of a type and tag and set their field to a provided value.
---@param eid entity_id
---@param ctype string
---@param tag? any
---@param field string
---@param ... any|table
function M.set_each_component_type_field(eid, ctype, tag, field, ...)
  local comps = M.get_components_by_type_and_tag(eid, ctype, tag)
  for _, comp in ipairs(comps) do M.set_component_value(comp, field, ...) end
end

---Remove all components from an entity of a given type and tag
---@param eid any
---@param ctype any
---@param tag any
function M.remove_all_components_of_type(eid, ctype, tag)
  M.each_component(eid, ctype, tag, EntityRemoveComponent)
end

function M.remove_components_of_type_with_field(eid, ctype, tag, field, val)
  M.each_component_of_type_with_field_matching(eid, ctype, tag, field, val, EntityRemoveComponent)
end

-- VSC storage helpers
function M.store(eid, name, ...)
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

function M.unbox_vsc(comp, specificField)
  if not comp then return nil end
  return M.get_component_value(comp, specificField)
end

function M.box_vsc(comp)
  if not comp then return nil end
  local t = {}
  local function push(field) t[field] = M.get_component_value(comp, field) end
  push("name") -- always push name!
  for _, field in ipairs(VSC_FIELDS) do push(field) end
  return t
end

function M.get_first_value(eid, name, specificField) ---@return any
  return M.unbox_vsc(M.first_component_of_type_with_field_equal(eid, VSC, nil, "name", name), specificField)
end

function M.get_unboxed_like(eid, name, specificField, isSkippingZero)
  local vscs = {}
  local function push(_, comp)
    local vsc = M.unbox_vsc(comp, specificField)
    if not isSkippingZero or (specificField ~= nil and vsc and vsc[specificField] ~= 0) then
      vscs[#vscs + 1] = vsc
    end
  end
  M.each_component_of_type_with_field_like(eid, VSC, nil, "name", name, push)
  return vscs
end

function M.get_boxes_like(eid, name, specificField, isSkippingZero)
  local vscs = {}
  local function push(_, comp)
    local vsc = M.box_vsc(comp)
    if not isSkippingZero or (specificField ~= nil and vsc and vsc[specificField] ~= 0) then
      vscs[#vscs + 1] = vsc
    end
  end
  M.each_component_of_type_with_field_like(eid, VSC, nil, "name", name, push)
  return vscs
end

---Set the value_int of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're modifying
---@param name string the name of the vsc we want to set the value of
---@param val integer the value of the field we're supplying to the vsc
function M.set_int(eid, name, val) M.store(eid, name, "value_int", val) end

---Set the value_int [cast as entity] of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're modifying
---@param name string the name of the vsc we want to set the value of
---@param val entity_id the value of the field we're supplying to the vsc
function M.set_entity_id(eid, name, val) M.store(eid, name, "value_int", val) end

---Set the value_float of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're modifying
---@param name string the name of the vsc we want to set the value of
---@param val number the value of the field we're supplying to the vsc
function M.set_float(eid, name, val) M.store(eid, name, "value_float", val) end

---Set the value_string of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're modifying
---@param name string the name of the vsc we want to set the value of
---@param val string the value of the field we're supplying to the vsc
function M.set_string(eid, name, val) M.store(eid, name, "value_string", val) end

---Get the value-field of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're probing
---@param name string the name of the vsc we want to get the value of
---@return integer result the value of the field we're getting from the vsc
function M.get_int(eid, name)
  return M.get_first_value(eid, name, "value_int") ---@return integer
end

---Get the value-field of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're probing
---@param name string the name of the vsc we want to get the value of
---@return entity_id result the value of the field we're getting from the vsc
function M.get_entity_id(eid, name)
  return M.get_first_value(eid, name, "value_int") ---@return entity_id
end

---Get the value-field of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're probing
---@param name string the name of the vsc we want to get the value of
---@return number result the value of the field we're getting from the vsc
function M.get_float(eid, name)
  return M.get_first_value(eid, name, "value_float") ---@return number
end

---Get the value-field of a vsc whose name matches the name provided in a given entity
---@param eid entity_id the entity with the vsc we're probing
---@param name string the name of the vsc we want to get the value of
---@return string result the value of the field we're getting from the vsc
function M.get_string(eid, name)
  return M.get_first_value(eid, name, "value_string") ---@return string
end

---Returns the value of a field from a component on a given entity, or
---substitute a default value (from arguments) if nothing is found.
---@param eid entity_id
---@param ctype string
---@param field string
---@param default any
---@return any
function M.value_or_default(eid, ctype, field, default)
  local comp = EntityGetFirstComponentIncludingDisabled(eid, ctype)
  if comp then return ComponentGetValue2(comp, field) end
  return default
end

return M
