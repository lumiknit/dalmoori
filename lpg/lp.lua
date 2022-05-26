-- lp: Lua Parsing Helper

-- Notes:
-- * lp put current text to parse in the global variable `ctxt`.
-- * `lp.open` make new context, pushing the last context into `saved_ctxt`
-- * `lp.close` close current context and pop the last one from `saved_ctxt`
-- * The context do not need to passed to each functions.
--   They just refer global context `ctxt`
-- * `lp.parse` perform `open`, `close`, and error handling for the given
--   parser function!
-- * If you want to move cursor forward, you must use `lp.pass`.
-- * If you want to move cursor backward, you can't directly.
--   Instead, there is `lp.save` to make a savepoint
--   and `lp.restore` to resume to the last savepoint
--   Since savepoint is managed by a stack, when the last savepoint is
--   no longer used, you should discard it manually using `lp.commit`.
-- * Many functions taking characters and produce some value may raise error
--   using lua builtin `error` function.
--   You can catch the error using `pcall`, but it may corrupt savepoint
--   stack.
--   Therefore, please use `lp.catch` to handle error. (The behaviour is
--   same to `pcall`)

--- Global Context Variables

local saved_ctxt = {}
local ctxt = nil

-- Package

local lp = {}

--- Open / Close Functions

-- lp.open: (Maybe Str, Maybe Str) -> Int
-- Make a new context.
-- If name is nil, set name as '<unnamed>'
-- If contents is nil, it reads a file named `name`
-- It returns the number of saved contexts
lp.open = function(contents, name)
  if contents == nil then
    file = io.open(name, 'r')
    if file == nil then
      error(string.format("Cannot open file %q", name))
    end
    contents = file:read('a')
    file:close()
  elseif name == nil then
    name = '<unnamed>'
  end
  -- If there is a current context, save it in the stack.
  if ctxt ~= nil then
    saved_ctxt[1 + #saved_ctxt] = ctxt
  end
  ctxt = {
    c = contents, -- text
    name = name,  -- name
    p = 1, ln = 1, col = 1, -- current position, line number, column number
    saved = {}, -- savepoints
  }
  return #saved_ctxt
end

-- lp.close: () -> Int
-- If a context is opened, close it.
-- It returns the number of saved context if some context is opened,
-- and returns -1 if no contexts are opened.
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

--- Open-Catch-Close Helper

-- lp.parse: (() -> a, Maybe Str, Maybe Str) -> (Bool, a)
-- Open (contents, name), run parser function `p`, and close a context.
-- The return is `status`, `result`
-- where `status` represents there was an error (false) or not (true)
-- and `result` is result value if `status == true` or error message otherwise
lp.parse = function(p, contents, name)
  lp.open(contents, name)
  local status, result = pcall(p)
  lp.close()
  return status, result
end

--- Error handling

-- lp.getCurrPos: () -> Str
-- Return the indicator of cursor in the current context.
-- The format is `<FILENAME>:<LINE>:<COLUMN>`.
-- Line numbers and column numbers start from 1.
lp.getCurrPos = function()
  return string.format('%s:%d:%d', ctxt.name, ctxt.ln, ctxt.col)
end

-- lp.error: (Str) -> ERR
-- Create an error with message as below form:
-- > Parse Error in lp
-- > <FILENAME>:<LINE>:<COLUMN>: <MAIN MESSAGE>
lp.error = function(msg)
  local f = 'Parse Error in lp\n'
  local pos = lp.getCurrPos()
  error(f .. pos .. ': ' .. msg)
end

-- lp.catch: ((... -> a), ...) -> (Bool, a)
-- Run ... as pcall, and return the result of pcall.
-- It preserve savepoint corruption during error propagation.
lp.catch = function(...)
  -- Save all savepoints
  lp.save()
  local saved_bak = ctxt.saved
  ctxt.saved = {}
  -- Run function with pcall
  local res, ret = pcall(...)
  -- Restore all savepoints
  ctxt.saved = saved_bak
  if res == true then
    -- If there is no error, just discard a savepoint
    lp.commit()
  else
    -- Otherwise, restore to the last position
    lp.restore()
  end
  return res, ret
end

-- lp.orSeq: (...) -> a
-- Take functions and run sequentially until one of them returned without err.
-- It returns the first return value.
-- If every function throws error, it only pass the last error.
lp.orSeq = function(...)
  local n = select('#', ...)
  local res, val
  for i = 1, n do
    local f = select(i, ...)
    res, val = lp.catch(f)
    if res then return val end
  end
  error(val)
end

--- Savepoint Helpers

-- lp.save: () -> Int
-- Make a savepoint.
-- It returns the number of savepoints after push.
lp.save = function()
  local t = { p = ctxt.p, ln = ctxt.ln, col = ctxt.col }
  ctxt.saved[#ctxt.saved + 1] = t
  return #ctxt.saved
end

-- lp.restore: () -> Int
-- Restore a cursor to the last savepoint.
-- It returns the number of savepoints after pop.
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

-- lp.commit: () -> Int
-- Discard the last savepoint.
-- It returns the number of savepoints after pop.
lp.commit = function()
  if #ctxt.saved >= 1 then
    ctxt.saved[#ctxt.saved] = nil
  end
  return #ctxt.saved
end

--- Cursor Movement Helper

-- lp.pass: (Maybe Int) -> ()
-- Move the cursor `offset` characters forward.
-- The default value of offset is 1.
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

--- Substring Helpers

-- lp.sub: (Maybe Int, Maybe Int) -> Str
-- Return the substring from `p + off` length of `len`.
-- lp.sub() = lp.sub(0, 1) (extract 1 chracter)
-- lp.sub(len) = lp.sub(0, len) (extract `len` characters)
-- It returns string length shorter than `len` when the string after cursor
-- is shorter than `len`.
lp.sub = function(off, len)
  if len == nil then
    if off == nil then return ctxt.c:sub(ctxt.p, ctxt.p)
    else return ctxt.c:sub(ctxt.p, ctxt.p + off - 1)
    end
  end
  return ctxt.c:sub(ctxt.p + off, ctxt.p + off + len - 1)
end

-- lp.subAt: (Int, Maybe Int) -> Str
-- Return the substring from absolute position `p` length of `len`.
-- The default value of `len` is 1
lp.subAt = function(p, len)
  if len == nil then return ctxt.c:sub(p, p)
  else return ctxt.c:sub(p, p + len - 1)
  end
end

-- lp.byte: (Maybe Int) -> Int
-- Return the byte at `p + off`.
-- The default value of `off` is 0.
lp.byte = function(off)
  if off == nil then off = 0 end
  return ctxt.c:byte(ctxt.p + off)
end

-- lp.byte: (Maybe Int) -> Int
-- Return the byte at the absolute position `p`.
lp.byteAt = function(p)
  return ctxt.c:byte(p)
end

-- lp.commitSub: () -> Str
-- Pop the last savepoint, and return a substring from the last savepoint
-- to the current cursor.
-- Its behaviour is just `lp.commit` and then `lp.sub`.
-- If there are no savepoints, it'll return nil
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

--- Predicates for strings

-- lp.isEOF: () -> Bool
-- Return true iff the cursor is at EOF.
lp.isEOF = function()
  return ctxt.p > #ctxt.c
end

-- lp.isStr: (Str) -> Bool
-- Return true iff the given string `pat` is at the cursor.
lp.isStr = function(pat)
  return ctxt.c:sub(ctxt.p, ctxt.p + #pat - 1) == pat
end

-- lp.isOneOf: (Str) -> Bool
-- Return true iff a character at the cursor equals to one char of `cs`
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

-- lp.isBetween: (Chr, Chr) -> Bool
-- Return true iff a character at the cursor is between `fr` and `to`.
lp.isBetween = function(fr, to)
  local b_c = ctxt.c:byte()
  return fr:byte() <= b_c and b_c <= to:byte()
end

--- Read Functions
-- ** It moves cursors when it succeed
-- ** and throws error when it fails.

-- lp.any: (Maybe Int) -> Str
-- Read `len` characters and return it.
-- The default value of `len` is 1
lp.any = function(len)
  if len == nil then len = 1 end
  p = ctxt.p
  if #ctxt.c - ctxt.p < len then
    lp.error(string.format("expect %d characters", len))
  end
  lp.pass(len)
  return lp.subAt(p, len)
end

-- lp.str: (Str) -> ()
-- Read the given string.
lp.str = function(pat)
  if not lp.isStr(pat) then
    lp.error(string.format("expect %q", pat))
  else
    lp.pass(#pat)
  end
end

-- lp.oneOf: (Str) -> ()
-- Read a character which is contained in `cs`
lp.oneOf = function(cs)
  if not lp.isOneOf(cs) then
    lp.error(string.format("expect one of %q", cs))
  else
    lp.pass(1)
  end
end

-- lp.noneOf: (Str) -> ()
-- Read a character which is not contained in `cs`
lp.noneOf = function(cs)
  if lp.isOneOf(cs) then
    lp.error(string.format("expect none of %q", cs))
  else
    lp.pass(1)
  end
end

-- lp.between: (Chr, Chr) -> ()
-- Read a character which is in between `fr` and `to`
lp.between = function(fr, to)
  if not lp.isBetween(fr, to) then
    lp.error(string.format("expect a char between %q and %q", fr, to))
  else
    lp.pass(1)
  end
end

-- lp.outOf: (Chr, Chr) -> ()
-- Read a character which is not in between `fr` and `to`
lp.outOf = function(fr, to)
  if lp.isBetween(fr, to) then
    lp.error(string.format("expect a char not between %q and %q", fr, to))
  else
    lp.pass(1)
  end
end

--- Whitespaces Handling Helpers

-- lp.passToLineEnd: () -> ()
-- Move the cursor to the end of line. (The next char will be `\n` or EOF)
lp.passToLineEnd = function()
  while not (lp.isEOF() or lp.isStr('\n')) do
    lp.pass()
  end
end

-- lp.passWhitespaces: () -> ()
-- Pass all whitespaces except `\n`.
lp.passWhitespaces = function()
  while not lp.isEOF() and not lp.isStr('\n') and lp.isBetween('\x00', ' ') do
    lp.pass()
  end
end

-- lp.passWhitespacesNL: () -> ()
-- Pass all whitespaces.
lp.passWhitespacesNL = function()
  while not lp.isEOF() and lp.isBetween('\x00', ' ') do
    lp.pass()
  end
end

--- Number Parser
2156
-- lp.hex2int: (Str, Int) -> Maybe Int
-- Convert a string `c` into an integer in base `base`.
-- e.g. 14-base `b3a` = 11 * 14^2 + 3 * 14 + 10 = 2208
-- If `c` contains not allowed characters, it'll return nil.
-- It consider a=10, b=11, ..., z=35. Thus, base must be 2..36
lp.hex2int = function(c, base)
  if base == nil then base = 16 end
  local z_0, z_9, z_a, z_z, z_A, z_Z = string.byte("09azAZ", 1, 6)
  local v = 0
  local b, t
  for i = 1, #c do
    b = c:byte()
    if z_0 <= b and b <= z_9 then t = b - z_0
    elseif z_a <= b and b <= z_z then t = 10 + b - z_a
    elseif z_A <= b and b <= z_Z then t = 10 + b - z_A
    else return nil
    end
    if t >= base then return nil end
    v = v * base + t
  end
  return v
end

-- lp.getHexNum: (Int, Maybe Int, Maybe Int) -> Maybe Int
-- Try to convert a substring `p + off` length of len in `base`-base into int.
-- IT DOES NOT MOVE CURSOR
-- If it failed, it'll return nil.
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

-- lp.number: () -> (Num, 'int'|'flt')
-- Convert a string after cursor into number.
-- Allowed format is:
-- [+-](0[xoqb])?X+(\.X*)?
-- where 0[xoqb] denotes a base 16/8/4/2, and X denotes a digit in the base.
-- It may throw error when take wrong number format.
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

--- Quotation Handler

-- lp.quote: (Str) -> Str
-- Read a block with quotation block.
-- e.g. lp.quote('"') takes a string looks like `"......"`
-- Block is taken lazily. (As short as possible).
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

-- lp.quoteWithEscape: (Str) -> Str
-- Read a block with quotation block, which can contain escape sequences
-- Block is taken lazily. (As short as possible).
-- The return value is an unescaped string.
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

-- Paren Helper

-- lp.pairOfParen: (Chr) -> Maybe Chr
-- Return open-close pair of the given character.
lp.pairOfParen = function(p)
  return ({['('] = ')', [')'] = '(',
           ['{'] = '}', ['}'] = '{',
           ['['] = ']', [']'] = '[',
           ['<'] = '>', ['>'] = '<'})[p]
end


-- Return package
return lp