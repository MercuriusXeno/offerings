function round(d, p) return math.floor(d * 10 ^ p + 0.5) / 10 ^ p end

function increment(t, f, v) t[f] = (t[f] or 0) + v end

-- symmetric when s (shallowness) is 1
function asymmetricMerge(s, l, a, b) return l - (l - a) * (l - s * b) / l end

function symmetricMerge(l, a, b) return asymmetricMerge(1, l, a, b) end

function complimentaryProduct(s, l, vs)
  local r = 0
  for _, v in ipairs(vs) do
    if r == 0 then r = v else r = asymmetricMerge(s, l, r, v) end
  end
  return r
end

function each(t, func) for _, v in ipairs(t) do func(v) end end