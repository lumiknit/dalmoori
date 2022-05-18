-- lgen.lua
-- Lua Code PP

--[[
  T := Int -> Str
  M a := a -> T
  L.raw :: M (Str) -- Raw String
  L.lit :: M (Any) -- Literal
  L.un :: M (op: Str, expr: T) -- Unary operator
  L.bin :: M (lhs: T, op: Str, rhs: T) -- Binary Operator
  L.com :: M ([T]) -- Comma
  L.idx :: M (val: T, index: T) -- Indexing/Access
  L.app :: M (fn: T, args: [T]) -- Function App
  L.tbl :: M (tbl: {Any |=> T}) -- Table
  L.block :: M ({T}) -- Indented blocks
  L.set :: M (lhs: T, rhs: T, is_local: bool) -- Assignment
  L.fn :: M (params: [Str], body: T) -- Function
  L.if_ :: M ([(cond: T, body: T) | elsebody: T]) -- If-elseif-else
  L.whl :: M (cond: T, body: T) -- while loop
  L.for_ :: M (v: Str, e1-2: T, e3: Maybe T, body: T) -- for v=e1,e2,e3
  L.for_in :: M (v: T, rng: T, body: T) -- for v in rng
  L.ret :: M (T) -- return
  L.brk :: M () -- break
  L.comment :: M (Str) -- comment
]]

local _lgen = function()
  local L = {}
  local indent = function(n)
    if n == nil then
      return ''
    else
      return string.rep(' ', 2 * n)
    end
  end
  L.raw = function(s)
    return function()
      return s
    end
  end
  local escape = function(s)
    local b = ''
    
  end
  L.lit = function(value)
    return function()
      local s
      if type(value) == 'string' then
        s = string.format('%q', value)
      else
        s = tostring(value)
      end
      return s
    end
  end
  L.un = function(op, ex)
    return function(x)
      return op .. "(" .. ex(x) .. ")"
    end
  end
  L.bin = function(lhs, op, rhs)
    return function(x)
      return "(" .. lhs(x) .. ")" .. op .. "(" .. rhs(x) .. ")"
    end
  end
  L.com = function(vs)
    return function(x)
      local a = ''
      for i, v in ipairs(vs) do
        if i > 1 then a = a .. ', ' end
        a = a .. v(x)
      end
      return a
    end
  end
  L.idx = function(val, idx)
    return function(x)
      return "(" .. val(x) .. ")[" .. idx(x) .. "]"
    end
  end
  L.app = function(fn, args)
    return function(x)
      local l = "(" .. fn(x) .. ")("
      local a = ''
      for i, v in ipairs(args) do
        if i > 1 then a = a .. ',' end
        a = a .. v(x)
      end
      return l .. a .. ")"
    end
  end
  L.tbl = function(t)
    return function(x)
      local a = ''
      local i = 1
      for k, v in pairs(t) do
        if #a > 0 then a = a .. ', ' end
        if k == i then
          a = a .. v(x)
          i = i + 1
        else
          local k_ = L.lit(k)(x)
          a = a .. '[' .. k_ .. ']=' .. v(x)
        end
      end
      return '{' .. a .. '}'
    end
  end
  L.block = function(bodies)
    return function(x)
      local ind = indent(x + 1)
      local a = ''
      for i, v in ipairs(bodies) do
        if i > 1 then a = a .. '\n' end
        a = a .. ind .. v(x + 1)
      end
      return a
    end
  end
  L.set = function(lhs, rhs, is_local)
    local h = ''
    if is_local then h = 'local ' end
    return function(x)
      return h .. lhs(x) .. ' = ' .. rhs(x)
    end
  end
  L.fn = function(params, body)
    return function(x)
      local p = ''
      for i, v in ipairs(params) do
        if i > 1 then p = p .. ', ' end
        p = p .. v
      end
      local b = body(x)
      return 'function(' .. p .. ')\n' .. b .. '\n' .. indent(x) .. 'end'
    end
  end
  L.if_ = function(lst)
    return function(x)
      local a = ''
      local n_ind = '\n' .. indent(x)
      for i, v in ipairs(lst) do
        if v[2] == nil then
          a = a .. 'else\n' .. v[1](x) .. n_ind
        elseif i == 1 then
          a = a .. 'if ' .. v[1](x) .. ' then\n' .. v[2](x) .. n_ind
        else
          a = a .. 'elseif ' .. v[1](x) .. ' then\n' .. v[2](x) .. n_ind
        end
      end
      return a .. 'end'
    end
  end
  L.whl = function(cond, body)
    return function(x)
      local a = 'while ' .. cond(x) .. ' do\n'
      local n_ind = '\n' .. indent(x)
      return a .. body(x) .. n_ind .. 'end'
    end
  end
  L.for_ = function(v, e1, e2, e3, body)
    return function(x)
      local rng = e1(x) .. ', ' .. e2(x)
      if e3 ~= nil then
        rng = rng .. ', ' .. e3(x)
      end
      local a = 'for ' .. v .. ' = ' .. rng .. ' do\n'
      local n_ind = '\n' .. indent(x)
      return a .. body(x) .. n_ind .. 'end'
    end
  end
  L.for_in = function(v, rng, body)
    return function(x)
      local a = 'for ' .. v(x) .. ' in ' .. rng(x) .. ' do\n'
      local n_ind = '\n' .. indent(x)
      return a .. body(x) .. n_ind .. 'end'
    end
  end
  L.ret = function(e)
    return function(x)
      return 'return ' .. e(x)
    end
  end
  L.brk = L.raw('break')
  L.comment = function(comment)
    return function(x)
      return '-- ' .. comment
    end
  end
  return L
end

return _lgen()
