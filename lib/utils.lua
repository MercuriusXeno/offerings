local M = {} ---@class offering_util

function M.round(d, p) return math.floor(d * 10 ^ p + 0.5) / 10 ^ p end

function M.increment(t, f, v) t[f] = (t[f] or 0) + v end

-- symmetric when s (shallowness) is 1
function M.asymmetricMerge(s, l, a, b) return l - (l - a) * (l - s * b) / l end

function M.symmetricMerge(l, a, b) return M.asymmetricMerge(1, l, a, b) end

function M.complimentaryProduct(s, l, vs)
  local r = 0
  for _, v in ipairs(vs) do
    if r == 0 then r = v else r = M.asymmetricMerge(s, l, r, v) end
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
function M.appendDescription(result, description_line)
    if result then
        result = result .. "\n" .. description_line
    else
        result = description_line
    end
    return result
end