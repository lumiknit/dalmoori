#!/usr/bin/env lua

local L = require('lgen/lgen')

readFile = function(filename)
  local f = io.open(filename, 'r')
  local s = f:read('a')
  f:close()
  return s
end

writeFile = function(filename, contents)
  local f = io.open(filename, 'w')
  f:write(contents)
  f:close()
end

if #arg < 2 then
  print("Usage: " .. arg[-1] .. " " .. arg[0] .. " <IN> <OUT>")
  os.exit()
end

in_filename = arg[1]
out_filename = arg[2]

src = readFile(in_filename)

b = {}
h = {b}

-- local t = {}
table.insert(b, L.set(L.raw('t'), L.tbl({L.lit(0)}), true))
-- local x = 0
table.insert(b, L.set(L.raw('x'), L.lit(1), true))

cur_v = L.idx(L.raw('t'), L.raw('x'))

zset_cond = L.bin(cur_v, '==', L.lit(nil))
zset_ln = L.set(cur_v, L.lit(0))
zset = L.if_({{zset_cond, {L.ln(zset_ln)}}})

acc = 0
for i = 1, #src do
  local c = string.sub(src, i, i)
  if c == '+' then
    acc = (acc + 1) % 256
  elseif c == '-' then
    acc = (acc + 255) % 256
  else
    if acc ~= 0 then
      local a = L.bin(cur_v, '+', L.lit(acc))
      local t = L.set(cur_v, L.bin(a, '%', L.lit(256)))
      table.insert(h[#h], t)
      acc = 0
    end
    if c == '.' then
      local args = {L.app(L.raw('string.char'), {cur_v})}
      table.insert(h[#h], L.ln(L.app(L.raw('io.write'), args)))
    elseif c == ',' then
      local r = L.app(L.raw('io.read'), {L.lit(1)})
      local y = L.app(L.raw('string.byte'), {r})
      table.insert(h[#h], L.set(cur_v, y))
    elseif c == '>' then
      local t = L.set(L.raw('x'), L.bin(L.raw('x'), '+', L.lit(1)))
      table.insert(h[#h], t)
      table.insert(h[#h], zset)
    elseif c == '<' then
      local t = L.set(L.raw('x'), L.bin(L.raw('x'), '-', L.lit(1)))
      table.insert(h[#h], t)
      table.insert(h[#h], zset)
    elseif c == '[' then
      table.insert(h, {})
    elseif c == ']' then
      if #h == 1 then
        print("Syntax Error! (Too many closes)")
        os.exit(1)
      end
      z = h[#h]
      h[#h] = nil
      local cond = L.bin(cur_v, '~=', L.lit(0))
      local w = L.whl(cond, z)
      table.insert(h[#h], w)
    end
  end
end

if #h > 1 then
  print("Syntax Error! (Unclosed paren)")
  os.exit(1)
end

writeFile(out_filename, L.block(b)())