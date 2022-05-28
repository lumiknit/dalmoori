-- lg: Lua Code Generation Helper

local lg = {}

-- Create Expr and pass it into `lg.generate`

-- Expr/Stmt List:
-- hashbang(str) => #!...
-- comment(Str) => -- ...
-- raw(Str)
-- literal(nil | true | false | Num | Str)
-- op(operator: Str, val: Expr)            # Unary
-- op(lhs: Expr, operator: Str, rhs: Expr) # Binary
-- index(val: Expr, idx: Expr) => val[idx]
-- app(fn: Expr, args: [Expr]) => fn(args)
-- access(val: Expr, key: Str) => val.key
-- method(val: Expr, key: Str) => val:key
-- comma([Expr]) => e1, e2, ...
-- wrap(Expr) => (e)
-- table({nil | true | false | Num | Str => Expr})
-- block([Expr], indent: Maybe Int)
-- top([Expr])
-- fn(params: [Str], body: Block, name: Maybe Str)
-- do_(Block)
-- set(lhs: Expr, rhs: Expr)
-- local_(lhs: Expr, rhs:Expr)
-- if_([cond1, block1, cond2, block2, ..., condn, blockn(, blockelse)])
-- while_(cond: Expr, block: Block)
-- for_(v: Str, e1: Expr, e2: Expr, e3: Maybe Expr, body: Block)
-- for_in(v: Str, r: Expr, body: Block)
-- return_(v: Expr)
-- break_()

--- Constant and Helper

local prec_table = {
  ['app'] = 45, ['idx'] = 45, ['acc'] = 45,
  ['lit'] = 42,
  ['^'] = 38,
  ['unary'] = 36,
  ['*'] = 34, ['/'] = 34, ['%'] = 34,
  ['+'] = 31, ['-'] = 31,
  ['..'] = 26,
  ['<<'] = 22, ['>>'] = 22,
  ['&'] = 19,
  ['~'] = 16,
  ['|'] = 13,
  ['<'] = 10, ['>'] = 10, ['<='] = 10, ['>='] = 10, ['~='] = 10, ['=='] = 10,
  ['and'] = 7,
  ['or'] = 4,
  [','] = 0,
}

local escapeString = function(s)
  local t = ("%q"):format(s)
  return t:gsub('\\\n', '\\n')
end

-- Expr/Stmt Constructor

lg.hashbang = function(line)
  return { '#!', line:gsub('\n.+', ''), sep = 0 }
end

lg.comment = function(line)
  return { '--', line:gsub('\n.+', ''), sep = 1 }
end

lg.raw = function(v)
  return { v }
end

lg.literal = function(v)
  if type(v) == 'string' then
    return { escapeString(v), prec = prec_table.lit }
  else return { tostring(v) }
  end
end

lg.op = function(a, b, c)
  if c == nil then -- Unary
    return { a, b, prec = prec_table.unary }
  else -- Binary
    return { a, b, c, sep = 1, prec = prec_table[b] }
  end
end

lg.idx = function(v, i)
  return { v, '[', {i}, ']', prec = prec_table.idx }
end

lg.app = function(fn, args)
  local a = {}
  for i, v in ipairs(args) do
    if i > 1 then a[1 + #a] = ', ' end
    a[1 + #a] = v
  end
  return { fn, '(', a, ')', prec = prec_table.app }
end

lg.access = function(v, k)
  return { v, '.', k, prec = prec_table.acc }
end

lg.method = function(v, k)
  return { v, ':', k, prec = prec_table.acc }
end

lg.comma = function(lst)
  local t = {}
  for i, v in ipairs(lst) do
    if i > 1 then t[1 + #t] = ', ' end
    t[1 + #t] = v
  end
  return t
end

lg.wrap = function(v)
  return { '(', v, ')' }
end

lg.table = function(tbl)
  local t = { '{' }
  local i = 1
  for k, v in pairs(tbl) do
    local z
    if i == k then
      i = i + 1
      z = { v, ',' }
    else
      z = { '[', lg.lit(k), '] = ', v, ',' }
    end
    z.indent = 1
    t[1 + #t] = z
  end
  t[1 + #t] = '}'
  t.sep = 1
  return t
end

lg.block = function(lines, indent)
  if indent == nil then indent = 1 end
  local t = { indent = indent, sep = 2 }
  for i, v in ipairs(lines) do t[i] = v end
  return t
end

lg.top = function(lines)
  return lg.block(lines, false)
end

lg.fn = function(params, body, name)
  local p = {}
  for i, v in ipairs(params) do
    if i > 1 then p[1 + #p] = ', ' end
    p[1 + #p] = v
  end
  local head
  if name == nil then
    head = {'function(', p, ')'}
  else
    head = {'function ', name, '(', p, ')'}
  end
  return {head, {body}, 'end', sep = 2, prec = prec_table.lit}
end

lg.do_ = function(block)
  return { 'do', block, 'end', sep = 2 }
end

lg.set = function(lhs, rhs)
  return { lhs, '=', rhs, sep = 1 }
end

lg.local_ = function(lhs, rhs)
  return { 'local', lhs, '=', rhs, sep = 1 }
end

lg.if_ = function(lst)
  local t = { sep = 2 }
  for i = 1, #lst, 2 do
    if lst[i + 1] == nil then -- else branch
      t[1 + #t] = 'else'
      t[1 + #t] = lst[i]
    else
      local l = (#t <= 0) and "if" or "elseif"
      t[1 + #t] = { l, lst[i], "then", sep = 1 }
      t[1 + #t] = lst[i + 1]
    end
  end
  t[1 + #t] = 'end'
  return t
end

lg.while_ = function(cond, body)
  local c = { "while", cond, "do", sep = 1 }
  return { c, body, 'end', sep = 2 }
end

lg.for_ = function(v, e1, e2, e3, body)
  local c = { "for ", v, " = ", e1, ", ", e2 }
  if e3 ~= nil then
    c[1 + #c] = ', '
    c[1 + #c] = e3
  end
  c[1 + #c] = " do"
  return { c, body, 'end', sep = 2 }
end

lg.for_in = function(v, r, body)
  local c = { 'for', v, 'in', r, 'do', sep = 1 }
  return { c, body, 'end', sep = 2 }
end

lg.return_ = function(v)
  return { 'return', v, sep = 1 }
end

lg.break_ = function()
  return { 'break' }
end

--- Flatten

local newBuffer = function()
  local b = { locs = {}, lines = {}, buf = nil }
  b.add = function(self, text)
    self.buf = (self.buf or '') .. text
  end
  b.ln = function(self, indent, loc)
    if self.buf == nil then return end
    if loc == nil then loc = self.locs[#self.locs] or 0 end
    self.locs[1 + #self.locs] = loc
    self.lines[1 + #self.lines] = ('  '):rep(indent) .. self.buf
    self.buf = nil
  end
  b.addLn = function(self, text, indent, loc)
    self:add(text)
    self:ln(indent, loc)
  end
  return b
end

lg.flatten = function(b, idx, src, indent, loc, prec)
  -- Set indent
  if src.indent == false then indent = 0
  elseif src.indent ~= nil then indent = indent + src.indent
  end
  local next_indent = indent
  -- Set location
  if src.loc ~= nil then loc = src.loc end
  -- Check precedence
  local wrap = false
  if prec ~= nil and src.prec ~= nil then
    local p3 = prec % 3
    local pcond = p3 ~= 0 and (p3 == 2) ~= (idx == 1)
    if prec > src.prec or (prec == src.prec and pcond) then
      wrap = true
      if src.sep == 2 then
        b:add('( ')
        next_indent = indent + 1
      else
        b:add('(')
      end
    end
  end
  -- Traverse
  for i, v in ipairs(src) do
    if i > 1 then
      if src.sep == 1 then b:add(' ')
      elseif src.sep == 2 then b:ln(indent, loc)
      end
      indent = next_indent
    end
    if type(v) == 'string' then b:add(v)
    else lg.flatten(b, i, v, indent, loc, src.prec)
    end
  end
  -- Close paren
  if src.sep == 2 then b:ln(indent, loc) end
  if wrap then b:add(')') end
end

lg.reduceLocTable = function(loc)
  if #loc == 0 then return { 0 } end
  local t = { 1, loc[1], 1 }
  for i, v in ipairs(loc) do
    t[#t] = i
    if t[#t - 1] ~= v then
      t[#t + 1] = v
      t[#t + 1] = i
    end
  end
  t[#t] = t[#t] + 1
  return t
end

lg.generate = function(src)
  -- Make an indented flatten table
  local b = newBuffer()
  -- Flatten
  lg.flatten(b, 0, src, 0, nil, nil)
  -- Then, flush
  b:ln(0, nil)
  return table.concat(b.lines, '\n'), lg.reduceLocTable(b.locs)
end

return lg