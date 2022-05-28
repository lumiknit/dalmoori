-- lg: Lua Code Generation Helper

local lg = {}

--- Lua grammar

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

lg.lit = function(v)
  if type(v) == 'string' then
    return { escapeString(v),
             prec = prec_table['lit'] }
  else
    return tostring(v)
  end
end

lg.unop = function(op, v)
  return { op, v, prec = prec_table['unary']}
end

lg.binop = function(lhs, op, rhs)
  return { lhs, op, rhs,
           sep = 1, prec = prec_table[op] }
end

lg.idx = function(v, i)
  return { v, '[', {i}, ']',
           prec = prec_table.idx }
end

lg.app = function(fn, args)
  local a = { }
  for i, v in ipairs(args) do
    if i > 1 then a[1 + #a] = ', ' end
    a[1 + #a] = v
  end
  return { fn, '(', a, ')', prec = prec_table.app }
end

lg.acc = function(v, k)
  return { v, '.', k, prec = prec_table.acc }
end

lg.method = function(v, k)
  return { v, ':', k, prec = prec_table.acc }
end

lg.tbl = function(tbl)
  local t = {'{'}
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

lg.block = function(lines)
  local t = {indent = 1, sep = 2}
  for i, v in ipairs(lines) do
    t[i] = v
  end
  return t
end

lg.top = function(lines)
  local t = {sep = 2}
  for i, v in ipairs(lines) do
    t[i] = v
  end
  return t
end

lg.do_ = function(block)
  return {'do', block, 'end', sep = 2}
end

lg.comma = function(lst)
  local t = {}
  for i, v in ipairs(lst) do
    if i > 1 then t[1 + #t] = ', ' end
    t[1 + #t] = v
  end
  return t
end

lg.set = function(lhs, rhs)
  return {lhs, '=', rhs, sep = 1}
end

lg.local_ = function(lhs, rhs)
  return {'local', lhs, '=', rhs, sep = 1}
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

lg.if_ = function(lst)
  local t = {sep = 2, lines = true}
  for i = 1, #lst, 2 do
    if lst[i + 1] == nil then -- Else branch
      t[1 + #t] = lst[i]
    elseif #t == 0 then -- If branch
      local cond = {"if", lst[i], "then", sep = 1}
      t[1 + #t] = cond
      t[1 + #t] = lst[i + 1]
    else
      local cond = {"elseif", lst[i], "then", sep = 1}
      t[1 + #t] = cond
      t[1 + #t] = lst[i + 1]
    end
  end
  t[1 + #t] = 'end'
  return t
end

lg.while_ = function(cond, body)
  local c = {"while", cond, "do", sep = 1}
  return {c, body, 'end', sep = 2}
end

lg.for_ = function(v, e1, e2, e3, body)
  local c = {"for ", v, " = ", e1, ", ", e2 }
  if e3 ~= nil then
    c[1 + #c] = ', '
    c[1 + #c] = e3
  end
  c[1 + #c] = " do"
  return {c, body, 'end', sep = 2}
end

lg.for_in = function(v, r, body)
  local c = {'for', v, 'in', r, 'do', sep = 1}
  return {c, body, 'end', sep = 2}
end

lg.return_ = function(v)
  return {'return', v, sep = 1}
end

lg.break_ = function(v)
  return {'break'}
end

--- Flatten

local newBuffer = function()
  local b = {locs={}, lines={}, buf=nil}
  b.add = function(self, text)
    if self.buf == nil then
      self.buf = text
    else
      self.buf = self.buf .. text
    end
  end
  b.ln = function(self, indent, loc)
    if self.buf == nil then return end
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
    local iz = idx == 1
    local pcond = (p3 == 1 and not iz) or (p3 == 2 and iz)
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
      if src.sep == 1 then
        b:add(' ')
      elseif src.sep == 2 then
        b:ln(indent, loc)
      end
      indent = next_indent
    end
    if type(v) == 'string' then
      b:add(v)
    else
      lg.flatten(b, i, v, indent, loc, src.prec)
    end
  end
  -- Close paren
  if src.sep == 2 then
    b:ln(indent, loc)
  end
  if wrap then
    b:add(')')
  end
end

lg.generate = function(src)
  -- Make an indented flatten table
  local b = newBuffer()
  lg.flatten(b, 0, src, 0, 0, nil)
  b:ln(0, 0)
  return table.concat(b.lines, '\n'), b.loc
end

return lg