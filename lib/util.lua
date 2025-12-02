local M = {} ---@class offering_util

function M.round(d, p) return math.floor(d * 10 ^ p + 0.5) / 10 ^ p end

---Sum an array of numeric types
---@param arr number[]
---@return number
function M.sum(arr)
  local r = 0
  for _, n in ipairs(arr) do r = r + n end
  return r
end

function M.increment(t, f, v) t[f] = (t[f] or 0) + v end

-- symmetric when s (shallowness) is 1
function M.asymmetric_merge(s, l, a, b) return l - (l - a) * (l - s * b) / l end

function M.symmetricMerge(l, a, b) return M.asymmetric_merge(1, l, a, b) end

function M.complimentaryProduct(s, l, vs)
  local r = 0
  for _, v in ipairs(vs) do
    if r == 0 then r = v else r = M.asymmetric_merge(s, l, r, v) end
  end
  return r
end

function M.each(t, func) for _, v in ipairs(t) do func(v) end end

function M.arrayEquals(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  local na, nb = #a, #b
  if na ~= nb then return false end
  for i = 1, na do if a[i] ~= b[i] then return false end end
  return true
end

---Return an appended desription using standardized line break logic.
---@param result string
---@param description_line string
---@return string
function M.append_description(result, description_line)
  if result then
    result = result .. "\n" .. description_line
  else
    result = description_line
  end
  return result
end

return M
