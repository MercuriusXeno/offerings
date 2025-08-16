dofile_once("mods/offerings/lib/math.lua")
dofile_once("mods/offerings/lib/logging.lua")

local thonk = dofile("mods/offerings/lib/thonk.lua") ---@type Thonk

local VSC = "VariableStorageComponent"
local originalStats = "original_stats_"

---For each entity component, execute a function
---@param eid integer the entity we are looping components of
---@param ctype string which components to find
---@param tag string|nil the tag of the component to filter by or nil
function componentsOfType(eid, ctype, tag)
  if tag ~= nil then
    return EntityGetComponentIncludingDisabled(eid, ctype, tag) or {}
  else
    return EntityGetComponentIncludingDisabled(eid, ctype) or {}
  end
end

---For each entity component, execute a function
---@param eid integer the entity we are looping components of
---@param ctype string which components to find
---@param tag string|nil the tag of the component to filter by or nil
---@param pred fun(comp: integer) the predicate against each component
function componentsWhere(eid, ctype, tag, pred)
  local arr = {}
  local function push(comp) arr[#arr + 1] = comp end
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do
    if pred(comp) then push(comp) end
  end
  return arr
end

---Return a collection of components of a type whose field matches a value
---@param eid integer the entity we are looping components of
---@param ctype string which components to find
---@param tag string|nil the tag of the component to filter by or nil
---@param field string the field name to test a match for
---@param val any the value to compare to the field value
function componentsMatching(eid, ctype, tag, field, val)
  local function match(comp) return cMatch(comp, field, val) end
  return componentsWhere(eid, ctype, tag, match)
end

---Return a collection of components of a type whose field contains a value
---@param eid integer the entity we are looping components of
---@param ctype string which components to find
---@param tag string|nil the tag of the component to filter by or nil
---@param field string the field name to test a match for
---@param val any the value to compare to the field value
function componentsLike(eid, ctype, tag, field, val)
  local function like(comp) return cLike(comp, field, val) end
  return componentsWhere(eid, ctype, tag, like)
end

---For each entity component, execute a function
---@param eid integer the entity we are looping components of
---@param ctype string which components to find
---@param tag string|nil the tag of the component to filter by or nil
---@param func fun(eid: integer, comp: integer) the function to execute on each component
function eachEntityComponent(eid, ctype, tag, func)
  for _, comp in ipairs(componentsOfType(eid, ctype, tag)) do func(eid, comp) end
end

function eachEntityComponentWhere(eid, ctype, tag, pred, func)
  for _, comp in ipairs(componentsWhere(eid, ctype, tag, pred)) do func(eid, comp) end
end

function eachEntityComponentMatching(eid, ctype, tag, field, val, func)
  local function pred(comp) return cMatch(comp, field, val) end
  eachEntityComponentWhere(eid, ctype, tag, pred, func)
end

function eachEntityComponentLike(eid, ctype, tag, field, val, func)
  local function pred(comp) return cLike(comp, field, val) end
  eachEntityComponentWhere(eid, ctype, tag, pred, func)
end

function removeAll(eid, ctype, tag)
  eachEntityComponent(eid, ctype, tag, EntityRemoveComponent)
end

function removeEntityComponentWhere(eid, ctype, tag, pred)
  eachEntityComponentWhere(eid, ctype, tag, pred, EntityRemoveComponent)
end

function removeMatch(eid, ctype, tag, field, val)
  eachEntityComponentMatching(eid, ctype, tag, field, val, EntityRemoveComponent)
end

function removeLike(eid, ctype, tag, field, val)
  eachEntityComponentLike(eid, ctype, tag, field, val, EntityRemoveComponent)
end

---Returns the first component matching ctype with tag, optional
---@param eid integer
---@param ctype string
---@param tag? string|nil
---@return number|nil componentId or nil if no component found
function firstComponent(eid, ctype, tag)
  if tag == nil then
    return EntityGetFirstComponentIncludingDisabled(eid, ctype) or nil
  else
    return EntityGetFirstComponentIncludingDisabled(eid, ctype, tag) or nil
  end
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

function toggleComp(eid, comp, isEnabled)
  if comp then EntitySetComponentIsEnabled(eid, comp, isEnabled) end
end

function toggleFirstCompMatching(eid, ctype, tag, field, value, isEnabled)
  toggleComp(eid, firstComponentMatching(eid, ctype, tag, field, value), isEnabled)
end

function toggleComps(eid, ctype, tag, isEnabled)
  local function flip(e, comp)
    toggleComp(e, comp, isEnabled)
  end
  eachEntityComponent(eid, ctype, tag, flip)
end

---Return a collection of components of a type whose field matches a value
---@param eid integer the entity we are looping components of
---@param ctype string which components to find
---@param tag string|nil the tag of the component to filter by or nil
---@param func fun(comp: integer): boolean the function to determine each component is enabled
function toggleCompsWhere(eid, ctype, tag, func)
  local function flip(e, comp)
    toggleComp(e, comp, func(comp))
  end
  eachEntityComponent(eid, ctype, tag, flip)
end

function disableAllComps(eid, ctype, tag) toggleComps(eid, ctype, tag, false) end

function enableAllComps(eid, ctype, tag) toggleComps(eid, ctype, tag, true) end

function cSum(t, comp, field) increment(t, field, cGet(comp, field)) end

function cMerge(t, comp, field, l, s)
  increment(t, field, asymmetricMerge(s, l, t[field], cGet(comp, field)))
end

---Return the results of a component get which can be multipart (varargs)
---or a table or a single value. We render varargs into a table.+
---@param comp nil|integer the component we're scraping
---@param field string what field we're scraping, by name
---@return nil|table|any result the field result, can be a variety of things
function cGet(comp, field)
  if not comp then return nil end
  -- pack multi-returns into an array for easier closures
  local n, vals = capture(ComponentGetValue2, comp, field)
  if n == 1 then return vals[1] end
  return vals
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

function cMatch(comp, field, val)
  local compVal = cGet(comp, field)
  if type(val) == "table" and type(compVal) == "table" then return arrayEquals(val, compVal) end
  return val == compVal
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

function dropStoredLike(eid, field, val) removeLike(eid, VSC, nil, field, val) end

-- vsc storage abstractions to make it kinda brainless - excludes name on purpose
local vscFields = { "value_int", "value_string", "value_bool", "value_float" }

---Returns value of vsc table, unboxed
---@param comp number|nil
---@param specificField string
---@return any|nil
function unboxVsc(comp, specificField)
  if not comp then return nil end
  return cGet(comp, specificField)
end

---Returns value in vsc table, still boxed
---@param comp number|nil
---@param specificField string
---@return nil|any|table
function boxVsc(comp, specificField)
  if not comp then return nil end
  local t = {}
  local function push(field) t[field] = cGet(comp, field) end
  push("name") -- always push name!
  for _, field in ipairs(vscFields) do push(field) end
  return t
end

function storedMatching(eid, name, specificField)
  local vscs = {}
  local function push(_, comp)
    local v = unboxVsc(comp, specificField)
    vscs[#vscs + 1] = v
  end
  eachEntityComponentMatching(eid, VSC, nil, "name", name, push)
  return vscs
end

function storedBoxedMatching(eid, name, specificField)
  local vscs = {}
  local function push(_, comp)
    local v = boxVsc(comp, specificField)
    vscs[#vscs + 1] = v
  end
  eachEntityComponentMatching(eid, VSC, nil, "name", name, push)
  return vscs
end

function storedUnboxedMatching(eid, name, specificField)
  local vscs = {}
  local function push(_, comp)
    local v = unboxVsc(comp, specificField)
    vscs[#vscs + 1] = v
  end
  eachEntityComponentMatching(eid, VSC, nil, "name", name, push)
  return vscs
end

---Return the first vsc which is a map for this name
---@param eid integer The entity we're getting the vsc from
---@param name string the name of the vsc to match by
---@param specificField string which vsc field to scrape out
---@return any value The value the vsc field specified returns
function firstStored(eid, name, specificField)
  return unboxVsc(firstComponentMatching(eid, VSC, nil, "name", name), specificField)
end

---Return the first vsc which is a map for this name
---@param eid integer The entity we're getting the vsc from
---@param name string the name of the vsc to match by
---@param specificField string which vsc field to scrape out
---@return table value The value the vsc field specified returns
function firstStoredBoxed(eid, name, specificField)
  return boxVsc(firstComponentMatching(eid, VSC, nil, "name", name), specificField)
end

---Stored vsc VALUES on the entity matching a likeness of a name
---@param eid integer The entity we're looking for vscs in
---@param name string the name of the vsc we are comparing to our match likeness
---@param specificField string the field we want to pull from the vsc
---@param isSkippingZero boolean whether to omit vsc values of 0
---@return any[] sequence of values belonging to (scraped from) the vscs requested
function storedsLike(eid, name, specificField, isSkippingZero)
  local vscs = {}
  local function push(_, comp)
    local vsc = unboxVsc(comp, specificField)
    if not isSkippingZero or (specificField ~= nil and vsc[specificField] ~= 0) then
      vscs[#vscs + 1] = vsc
    end
  end
  eachEntityComponentLike(eid, VSC, nil, "name", name, push)
  return vscs
end

---Stored vscs on the entity matching a likeness of a name
---@param eid integer The entity we're looking for vscs in
---@param name string the name of the vsc we are comparing to our match likeness
---@param specificField string the field we want to pull from the vsc
---@param isSkippingZero boolean whether to omit vsc values of 0
---@return table table of vsc-like objects containing the values
function storedsBoxedLike(eid, name, specificField, isSkippingZero)
  local vscs = {}
  local function push(_, comp)
    local vsc = boxVsc(comp, specificField)
    if not isSkippingZero or (specificField ~= nil and vsc[specificField] ~= 0) then
      vscs[#vscs + 1] = vsc
    end
  end
  eachEntityComponentLike(eid, VSC, nil, "name", name, push)
  return vscs
end

-- vsc storage abstractions with more specific in/out behaviors to reduce overhead
function storeInt(eid, name, val) store(eid, name, "value_int", val) end

function storeFloat(eid, name, val) store(eid, name, "value_float", val) end

---Returns the stored integer of a component (VSC) as an unboxed vsc
---@param eid integer the entity we want the int from
---@param name string the name of the vsc we're after
---@return nil|table tableOrNil the vsc table of the match for this int or nil
function storedIntBoxed(eid, name) return firstStoredBoxed(eid, name, "value_int") end

---Returns the stored integer of a component (VSC) as a value only
---@param eid integer the entity we want the int from
---@param name string the name of the vsc we're after
---@return nil|integer intOrNil return an int value or nil
function storedInt(eid, name) return firstStored(eid, name, "value_int") end

function storedFloat(eid, name) return firstStored(eid, name, "value_float") end

function storedIntsArray(eid, name) return storedMatching(eid, name, "value_int") end

function clearOriginalStats(altar) removeLike(altar, VSC, nil, "name", originalStats) end

function valueOrDefault(eid, ctype, field, default)
  local comp = EntityGetFirstComponentIncludingDisabled(eid, ctype)
  if comp then return ComponentGetValue2(comp, field) end
  return default
end
