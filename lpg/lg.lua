-- lg: Lua Code Generation Helper

--[[
  For types 
  T := Int -> Str
  M a := a -> T
  ,
  L.raw :: M (Str)                                      -- Raw String
  L.lit :: M (Any)                                      -- Literal
  L.un :: M (op: Str, expr: T)                          -- Unary operator
  L.bin :: M (lhs: T, op: Str, rhs: T)                  -- Binary Operator
  L.com :: M ([T])                                      -- Comma
  L.idx :: M (val: T, index: T)                         -- Indexing/Access
  L.app :: M (fn: T, args: [T])                         -- Function App
  L.tbl :: M (tbl: {Any |=> T})                         -- Table
  L.block :: M ([T])                                    -- Indented blocks
  L.do_ :: M ([T])                                      -- Do block
  L.ln :: M (T)                                         -- Line
  L.set :: M (lhs: T, rhs: T, is_local: bool)           -- Assignment
  L.fn :: M (params: [Str], body: [T])                  -- Function
  L.if_ :: M ([(cond: T, body: [T]) | elsebody: T])     -- If-elseif-else
  L.whl :: M (cond: T, body: [T])                       -- while loop
  L.for_ :: M (v: Str, e1-2: T, e3: Maybe T, body: [T]) -- for v=e1,e2,e3
  L.for_in :: M (v: T, rng: T, body: [T])               -- for v in rng
  L.ret :: M (T)                                        -- return
  L.brk :: M ()                                         -- break
  L.comment :: M (Str)                                  -- comment
]]

local _lg = function()
  local L = {}
  local expectType = function(context, var_name, var, expected)
    local t = type(var)
    if expected[t] == nil then
      local msg = "LGen Error: Unexpected type "
      msg = msg .. t .. " for " .. var_name .. " in " .. context
      msg = msg .. ",\n expected one of ["
      local e = ''
      for k, v in pairs(expected) do
        if #e > 0 then e = e .. ' | ' end
        e = e .. k
      end
      msg = msg .. e .. ']'
      error(msg)
    end
    return true
  end
  local expectTableOf = function(context, var_name, var, expected)
    local passed = true
    if type(var) == 'table' then
      for k, v in pairs(var) do
        if type(v) ~= 'function' then
          passed = false
          break
        end
      end
    else
      passed = false
    end
    if not passed then
      local msg = "LGen Error: Expect table for "
      msg = msg .. var_name .. ' in ' .. context
      msg = msg .. ",\n containing one of ["
      local e = ''
      for k, v in pairs(expected) do
        if #e > 0 then e = e .. ' | ' end
        e = e .. k
      end
      msg = msg .. e .. ']'
      error(msg)
    end
    return true
  end
  local expectFnList = function(context, var_name, var)
    local passed = true
    if type(var) == 'table' then
      for k, v in pairs(var) do
        if type(v) ~= 'function' then
          passed = false
          break
        end
      end
    else
      passed = false
    end
    if not passed then
      local msg = "LGen Error: Expect table of generators for "
      msg = msg .. var_name .. ' in ' .. context
      error(msg)
    end
    return true
  end
  local indent = function(n)
    if n == nil then return ''
    else return string.rep(' ', 2 * n)
    end
  end
  L.raw = function(s)
    expectType('raw', 's', s, {string=1})
    return function()
      return s
    end
  end
  L.lit = function(value)
    expectType('lit', 'value', value,
      {['nil']=1, boolean=1, number=1, string=1})
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
    expectType('un', 'op', op, {string=1})
    expectType('un', 'expr', ex, {['function']=1})
    return function(x)
      return op .. "(" .. ex(x) .. ")"
    end
  end
  L.bin = function(lhs, op, rhs)
    expectType('bin', 'op', op, {string=1})
    expectType('bin', 'lhs', lhs, {['function']=1})
    expectType('bin', 'rhs', rhs, {['function']=1})
    return function(x)
      return "(" .. lhs(x) .. ")" .. op .. "(" .. rhs(x) .. ")"
    end
  end
  L.com = function(vs)
    expectFnList('com', 'vs', vs)
    if #vs <= 0 then
      error("LGen Error: Expect non-empty list for vs in com")
    end
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
    expectType('idx', 'val', val, {['function']=1})
    expectType('idx', 'idx', idx, {['function']=1})
    return function(x)
      return "(" .. val(x) .. ")[" .. idx(x) .. "]"
    end
  end
  L.app = function(fn, args)
    expectType('app', 'fn', fn, {['function']=1})
    expectFnList('app', 'args', args)
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
    expectFnList('tbl', 't', t)
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
    expectFnList('block', 'bodies', bodies)
    return function(x)
      if x == nil then x = -1 end
      local ind = indent(x + 1)
      local a = ''
      for i, v in ipairs(bodies) do
        if i > 1 then a = a .. '\n' end
        a = a .. ind .. v(x + 1)
      end
      return a
    end
  end
  L.do_ = function(body)
    expectFnList('do', 'body', body)
    return function(x)
      local n_ind = '\n' .. indent(x)
      return 'do\n' .. L.block(body)(x) .. n_ind .. 'end'
    end
  end
  L.ln = function(line)
    expectType('ln', 'line', line, {['function']=1})
    return function(x)
      return line(x) .. ';'
    end
  end
  L.set = function(lhs, rhs, is_local)
    expectType('set', 'lhs', lhs, {['nil']=1, ['function']=1})
    expectType('set', 'rhs', rhs, {['function']=1})
    expectType('set', 'is_local', is_local, {['nil']=1, boolean=1})
    local h = ''
    if is_local then h = 'local ' end
    return function(x)
      if lhs == nil then
        return rhs(x) .. ';'
      else
        return h .. lhs(x) .. ' = ' .. rhs(x) .. ';'
      end
    end
  end
  L.fn = function(params, body)
    expectTableOf('fn', 'params', params, {string=1})
    expectFnList('fn', 'body', body)
    return function(x)
      local p = ''
      for i, v in ipairs(params) do
        if i > 1 then p = p .. ', ' end
        p = p .. v
      end
      local b = L.block(body)(x)
      return '(function(' .. p .. ')\n' .. b .. '\n' .. indent(x) .. 'end)'
    end
  end
  L.if_ = function(lst)
    expectType('if', 'lst', lst, {table=1})
    for i, v in ipairs(lst) do
      n = 'lst[' .. tostring(i) .. ']'
      expectType('if', n, v, {table=1})
      if #v <= 0 or #v > 2 then
        error("LGen Error: # of gens for " .. n .. " in if must be in 1..2")
      end
      expectType('if', n .. "[1]", v[1], {['function']=1})
      if v[2] ~= nil then
        expectFnList('if', n .. "[2]", v[2])
      end
    end
    return function(x)
      local a = ''
      local n_ind = '\n' .. indent(x)
      for i, v in ipairs(lst) do
        if v[2] == nil then
          a = a .. 'else\n' .. v[1](x) .. n_ind
        else
          t = 'if ' .. v[1](x) .. ' then\n' .. L.block(v[2])(x) .. n_ind
          if i > 1 then a = a .. 'else' end
          a = a .. t
        end
      end
      return a .. 'end'
    end
  end
  L.whl = function(cond, body)
    expectType('whl', 'cond', cond, {['function']=1})
    expectFnList('whl', 'body', body)
    return function(x)
      local a = 'while ' .. cond(x) .. ' do\n'
      local n_ind = '\n' .. indent(x)
      return a .. L.block(body)(x) .. n_ind .. 'end'
    end
  end
  L.for_ = function(v, e1, e2, e3, body)
    expectType('for', 'v', v, {['function']=1})
    expectType('for', 'e1', e1, {['function']=1})
    expectType('for', 'e2', e2, {['function']=1})
    expectType('for', 'e3', e3, {['nil']=1, ['function']=1})
    expectFnList('for', 'body', body)
    return function(x)
      local rng = e1(x) .. ', ' .. e2(x)
      if e3 ~= nil then
        rng = rng .. ', ' .. e3(x)
      end
      local a = 'for ' .. v .. ' = ' .. rng .. ' do\n'
      local n_ind = '\n' .. indent(x)
      return a .. L.block(body)(x) .. n_ind .. 'end'
    end
  end
  L.for_in = function(v, rng, body)
    expectType('for_in', 'v', v, {['function']=1})
    expectType('for_in', 'rng', rng, {['function']=1})
    expectFnList('for_in', 'body', body)
    return function(x)
      local a = 'for ' .. v(x) .. ' in ' .. rng(x) .. ' do\n'
      local n_ind = '\n' .. indent(x)
      return a .. L.block(body)(x) .. n_ind .. 'end'
    end
  end
  L.ret = function(e)
    expectType('ret', 'expr', e, {['function']=1})
    return function(x)
      return 'return ' .. e(x) .. ';'
    end
  end
  L.brk = L.raw('break')
  L.comment = function(comment)
    expectType('comment', 'comment', comment, {string=1})
    local s, e = string.find(comment, '\n')
    if s ~= nil then
      h, t = '--[[ ', ']]'
    else
      h, t = '-- ', ''
    end
    return function(x)
      return h .. comment .. t
    end
  end
  return L
end

return _lg()
