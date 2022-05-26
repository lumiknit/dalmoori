-- ltup: Lua Named Tuple

-- Usage:
-- NamedTuple = ltup('TagName', 'key1name', 'key2name', ...)
-- OtherTuple = ltup('TagName', 'key1name', 'key2name', ...)
-- tup_a = NamedTuple(3, 5, ...)
-- tup_b = NamedTuple(2, 1)
-- print(tup_a.key1name) #=> 3
-- print(tup_a[2]) #=> 5
-- print(tup_a.is(NamedTuple)) #=> True
-- print(tup_a.is(OtherTuple)) #=> False
-- print(tup_a.tag) #=> TagName
-- print(#tup_a) #=> number of elements of tup_a
-- print(tup_a == tup_a) #=> True
-- print(tup_a == tup_b) #=> False
-- print(tup_a) #=> TagName(3, 5, ...)

local ltup_cnt = 0

local ltup = function(name, ...)
  -- Default name is `#xxx`
  if name == nil then
    ltup_cnt = ltup_cnt + 1
    name = "#" .. tostring(ltup_cnt)
  end

  -- Metatable
  local meta = {}

  -- Make key table
  meta.keys = {}
  for i = 1, select('#', ...) do
    meta.keys[select(i, ...)] = i
  end

  -- Tuple Constructor
  meta.constructor = function(...)
    local n = select('#', ...)
    local t = {}
    for i = 1, n do
      t[i] = select(i, ...)
    end
    return setmetatable(t, meta)
  end

  -- Index table
  meta.index = {}

  meta.index.tag = name
  
  meta.index.is = function(self, constr)
    return meta.constructor == constr
  end
  
  meta.index.oneOf = function(self, constrs)
    for i, k in ipairs(constrs) do
      if meta.constructor == k then return true end
    end
    return false
  end

  -- Index metamethod
  meta.__index = function(self, key)
    local k = meta.keys[key]
    if k ~= nil then return self[k] end
    return meta.index[key]
  end

  -- # metamethod
  meta.__len = function(self)
    return rawlen(self)
  end

  -- == metamethod
  meta.__eq = function(self, other)
    if type(other) ~= 'table' then return false end
    if getmetatable(other) ~= meta then return false end
    if #self ~= #other then return false end
    if self._es then return nil end
    self._es = true
    for i = 1, #self do
      if self[i] ~= other[i] then
        self._es = false
        return false
      end
    end
    self._es = false
    return true
  end

  -- tostring metamethod
  meta.__tostring = function(self)
    local buf = name
    if self._ts then return buf .. '(..)' end
    self._ts = true
    local args = nil
    for i, v in ipairs(self) do
      if args == nil then args = tostring(v)
      else args = args .. ', ' .. tostring(v)
      end
    end
    self._ts = false
    return buf .. '(' .. args .. ')'
  end

  -- return constructor
  return meta.constructor
end

return ltup