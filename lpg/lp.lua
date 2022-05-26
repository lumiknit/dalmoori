-- lp.lua
-- Parser Helper in Lua

local saved_ctxt = {}
local ctxt = nil

local lp = {}

--- Open / Close

lp.open = function(contents, name)
  if name == nil then
    name = '<unnamed>'
  end
  if ctxt ~= nil then
    saved_ctxt[1 + #saved_ctxt] = ctxt
  end
  ctxt = {
    c = contents,
    name = name,
    p = 1, ln = 1, col = 1,
    saved = {},
  }
  return #saved_ctxt
end

lp.close = function()
  if #saved_ctxt >= 1 then
    ctxt = saved_ctxt[#saved_ctxt]
    saved_ctxt[#saved_ctxt] = nil
    return #saved_ctxt
  else
    ctxt = nil
    return -1
  end
end

-- Safe parse
lp.parse = function(p, contents, name)
  lp.open(contents, name)
  local status, result = pcall(p)
  lp.close()
  return status, result
end

-- Current position string
lp.getCurrPos = function()
  return string.format('%s:%d:%d', ctxt.name, ctxt.ln, ctxt.col)
end

-- Raise error
lp.error = function(msg)
  local f = 'Parse Error in lp\n'
  local pos = lp.getCurrPos()
  error(f .. pos .. ': ' .. msg)
end

lp.orSeq = function(...)
  local n = select('#', ...)
  local res, val
  for i = 1, n do
    local f = select(i, ...)
    res, val = pcall(f)
    if res then return val
  end
  error(val)
end

--- Position save/load

-- Save current position
lp.save = function()
  local t = { p = ctxt.p, ln = ctxt.ln, col = ctxt.col }
  ctxt.saved[#ctxt.saved + 1] = t
  return #ctxt.saved
end

-- Restore last position
lp.restore = function()
  if #ctxt.stack >= 1 then
    local t = ctxt.saved[#ctxt.saved]
    ctxt.saved[#ctxt.saved] = nil
    ctxt.p = t.p
    ctxt.ln = t.ln
    ctxt.col = t.col
  end
  return #ctxt.saved
end

-- Remove last position
lp.commit = function()
  if #ctxt.saved >= 1 then
    ctxt.saved[#ctxt.saved] = nil
  end
  return #ctxt.saved
end

-- P

lp.pass = function(offset)
  if offset == nil then offset = 1 end
  while offset > 0 and ctxt.p <= #ctxt.c do
    if ctxt.c:sub(ctxt.p, ctxt.p) == '\n' then
      ctxt.ln, ctxt.col = ctxt.ln + 1, 1
    else
      ctxt.col = ctxt.col + 1
    end
    ctxt.p = ctxt.p + 1
    offset = offset - 1
  end
end

-- Sub

lp.sub = function(off, len)
  if len == nil then
    if off == nil then
      off, len = 0, 1
    else
      off, len = 0, off
    end
  end
  return ctxt.c:sub(ctxt.p + off, ctxt.p + off + len - 1)
end

lp.subAt = function(p, len)
  if len == nil then len = 0 end
  return ctxt.c:sub(p, p + len - 1)
end

-- commit and sub
lp.commitSub = function()
  if #ctxt.saved > 0 then
    local last_p = ctxt.saved[#ctxt.saved].p
    local s = ctxt.c:sub(last_p, ctxt.p - 1)
    ctxt.saved[#ctxt.saved] = nil
    return s
  else
    return nil
  end
end

-- look ahead
lp.isEOF = function(pat)
  return ctxt.p > #ctxt.c
end

lp.isStr = function(pat)
  return ctxt.c:sub(ctxt.p, ctxt.p + #pat - 1) == pat
end

lp.isOneOf = function(cs)
  local b = ctxt.c:byte(ctxt.p)
  for i = 1, #cs do
    local c = cs:byte(i)
    if b == c then
      return true
    end
  end
  return false
end

lp.isBetween = function(fr, to)
  local b_c = ctxt.c:byte()
  return fr:byte() <= b_c and b_c <= to:byte()
end

-- read and pass
lp.any = function(len)
  if len == nil then len = 1 end
  p = ctxt.p
  if #ctxt.c - ctxt.p < len then
    lp.error(string.format("expect %d characters", len))
  end
  lp.pass(len)
  return lp.subAt(p, len)
end

lp.str = function(pat)
  if not lp.isStr(pat) then
    lp.error(string.format("expect %q", pat))
  else
    return lp.pass(#pat)
  end
end

lp.oneOf = function(cs, many)
  if not lp.isOneOf(cs) then
    lp.error(string.format("expect one of %q", cs))
  else
    return lp.pass(1)
  end
end

lp.noneOf = function(cs)
  if lp.isOneOf(cs) then
    lp.error(string.format("expect none of %q", cs))
  else
    return lp.pass(1)
  end
end

lp.between = function(fr, to)
  if not lp.isBetween(fr, to) then
    lp.error(string.format("expect a char between %q and %q", fr, to))
  else
    return lp.pass(1)
  end
end

lp.outOf = function(fr, to)
  if lp.isBetween(fr, to) then
    lp.error(string.format("expect a char not between %q and %q", fr, to))
  else
    return lp.pass(1)
  end
end

-- Whitespace Handling

lp.passToLineEnd = function()
  while not (lp.isEOF() or lp.isStr('\n')) do
    lp.pass()
  end
end

lp.passWhiteSpaces = function()
  while not lp.isEOF() and not lp.isStr('\n') and lp.isBetween('\x00', ' ') do
    lp.pass()
  end
end

lp.passWhiteNL = function()
  while not lp.isEOF() and lp.isBetween('\x00', ' ') do
    lp.pass()
  end
end

-- HexNum

lp.hex2int = function(c, base)
  if base == nil then base = 16 end
  local v = 0
  for i = 1, #c do
    local b = c:byte()
    local t = nil 
    if ("0"):byte() <= b and b <= ("9"):byte() then
      t = b - ("0"):byte()
    elseif ("a"):byte() <= b and b <= ("z"):byte() then
      t = 10 + b - ("a"):byte()
    elseif ("A"):byte() <= b and b <= ("Z"):byte() then
      t = 10 + b - ("A"):byte()
    else
      return nil
    end
    if t >= base then
      return nil
    end
    v = v * base + t
  end
  return v
end

lp.getHexNum = function(base, off, len)
  if len == nil then
    if off == nil then
      off, len = 0, 1
    else
      off, len = 0, off
    end
  end
  local c = ctxt.c:sub(ctxt.p + off, ctxt.p + off + len - 1)
  if #c <= 0 then return nil end
  return lp.hex2int(c, base)
end


-- Number

lp.number = function()
  local sign = 1
  local base = 10
  local v = 0
  if lp.isStr('+') then
    lp.pass()
  elseif lp.isStr('-') then
    lp.pass()
    sign = -1
  end
  if lp.isStr('0x') then
    base = 16
    lp.pass(2)
  elseif lp.isStr('0o') then
    base = 8
    lp.pass(2)
  elseif lp.isStr('0q') then
    base = 4
    lp.pass(2)
  elseif lp.isStr('0b') then
    base = 2
    lp.pass(2)
  end
  local d = 0
  while 1 do
    local n = lp.getHexNum(base)
    if n == nil then break end
    d = d + 1
    v = v * base + n
    lp.pass()
  end
  if d == 0 then
    lp.error("wrong number format")
  end
  if lp.isStr('.') then
    lp.pass()
    local dp = 1 / base
    while 1 do
      local n = lp.getHexNum(base)
      if n == nil then break end
      v = v + dp * n
      dp = dp / base
      lp.pass()
    end
    return sign * v, 'flt'
  end
  return sign * v, 'int'
end

-- String

lp.quote = function(mark)
  lp.str(mark)
  lp.save()
  while not (lp.isEOF() or lp.isStr(mark)) do
    lp.pass()
  end
  local s = lp.commitSub()
  lp.str(mark)
  return s
end

lp.unescape_table = {
  a = '\a', b = '\b', f = '\f', n = '\n',
  r = '\r', t = '\t', v = '\v' }

lp.quoteWithEscape = function(mark)
  lp.str(mark)
  local buf = ''
  while not (lp.isEOF() or lp.isStr(mark)) do
    if lp.isStr('\\') then
      lp.pass()
      if lp.isEOF() then
        lp.error("unexpected EOF (unclosed quote)")
      end
      if lp.isStr('x') then
        lp.pass()
        local s = lp.sub(2)
        local n = lp.hex2int(s)
        if n == nil then
          lp.error("wrong format for \\x in quote")
        end
        lp.pass(2)
        buf = buf .. string.char(n)
      elseif lp.unescape_table[lp.sub()] ~= nil then
        buf = buf .. lp.unescape_table[lp.sub()]
        lp.pass()
      else
        buf = buf .. lp.sub()
        lp.pass()
      end
    else
      buf = buf .. lp.sub()
      lp.pass()
    end
  end
  lp.str(mark)
  return buf
end

-- Paren

lp.pairOfParen = function(p)
  return {['('] = ')', [')'] = '(',
          ['{'] = '}', ['}'] = '{',
          ['['] = ']', [']'] = '[',
          ['<'] = '>', ['>'] = '<',}[p]
end


return lp