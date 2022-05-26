#!/usr/bin/env lua

-- Brainfuck-Lua Compiler Example

-- Load LPG
lg = require('lpg/lg')
lp = require('lpg/lp')

-- File R/W helpers

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

-- Parse arguments

if #arg < 2 then
  print("Usage: " .. arg[-1] .. " " .. arg[0] .. " <IN> <OUT>")
  os.exit()
end

in_filename = arg[1]
out_filename = arg[2]

-- Read source file



function parseBF()
  local b = {}
  local h = {b}

  -- local t = {}
  table.insert(b, lg.set(lg.raw('t'), lg.tbl({lg.lit(0)}), true))
  -- local x = 0
  table.insert(b, lg.set(lg.raw('x'), lg.lit(1), true))

  local cur_v = lg.idx(lg.raw('t'), lg.raw('x'))

  local zset_cond = lg.bin(cur_v, '==', lg.lit(nil))
  local zset_ln = lg.set(cur_v, lg.lit(0))
  local zset = lg.if_({{zset_cond, {lg.ln(zset_ln)}}})

  local acc = 0
  while not lp.isEOF() do
    if lp.isStr('+') then
      acc = (acc + 1) % 256
    elseif lp.isStr('-') then
      acc = (acc + 255) % 256
    else
      if acc ~= 0 then
        local a = lg.bin(cur_v, '+', lg.lit(acc))
        local t = lg.set(cur_v, lg.bin(a, '%', lg.lit(256)))
        table.insert(h[#h], t)
        acc = 0
      end
      if lp.isStr('.') then
        local args = {lg.app(lg.raw('string.char'), {cur_v})}
        table.insert(h[#h], lg.ln(lg.app(lg.raw('io.write'), args)))
      elseif lp.isStr(',') then
        local r = lg.app(lg.raw('io.read'), {lg.lit(1)})
        local y = lg.app(lg.raw('string.byte'), {r})
        table.insert(h[#h], lg.set(cur_v, y))
      elseif lp.isStr('>') then
        local t = lg.set(lg.raw('x'), lg.bin(lg.raw('x'), '+', lg.lit(1)))
        table.insert(h[#h], t)
        table.insert(h[#h], zset)
      elseif lp.isStr('<') then
        local t = lg.set(lg.raw('x'), lg.bin(lg.raw('x'), '-', lg.lit(1)))
        table.insert(h[#h], t)
        table.insert(h[#h], zset)
      elseif lp.isStr('[') then
        table.insert(h, {})
      elseif lp.isStr(']') then
        if #h == 1 then lp.error('too many closes') end
        z = h[#h]
        h[#h] = nil
        local cond = lg.bin(cur_v, '~=', lg.lit(0))
        local w = lg.whl(cond, z)
        table.insert(h[#h], w)
      end
    end
    lp.pass()
  end

  if #h > 1 then lp.error('unclosed paren exists') end

  return b
end

-- Run Parser-Generator

src = readFile(in_filename)
res, ret = lp.parse(parseBF, src, in_filename)
if res == false then error(ret) end
writeFile(out_filename, lg.block(ret)())