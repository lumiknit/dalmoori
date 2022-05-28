#!/usr/bin/env lua

-- Brainfuck-Lua Compiler Example

-- Load LPG
package.path = package.path .. ";../?.lua"
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
  table.insert(b, lg.local_('t', lg.table({lg.literal(0)})))
  -- local x = 0
  table.insert(b, lg.local_('x', lg.literal(1)))

  local cur_v = lg.idx('t', 'x')

  local zset_cond = lg.op(cur_v, '==', lg.literal(nil))
  local zset_ln = lg.set(cur_v, lg.literal(0))
  local zset = lg.if_({zset_cond, lg.block({zset_ln})})

  local acc = 0
  local cmt = false
  while not lp.isEOF() do
    if lp.isStr('+') then
      acc = (acc + 1) % 256
    elseif lp.isStr('-') then
      acc = (acc + 255) % 256
    else
      if acc ~= 0 then
        local a = lg.op(cur_v, '+', lg.literal(acc))
        local t = lg.set(cur_v, lg.op(a, '%', lg.literal(256)))
        table.insert(h[#h], t)
        acc = 0
      end
      cmt = true
      if lp.isStr('.') then
        local args = {lg.app('string.char', {cur_v})}
        table.insert(h[#h], lg.app('io.write', args))
      elseif lp.isStr(',') then
        local r = lg.app('io.read', {lg.literal(1)})
        local y = lg.app('string.byte', {r})
        table.insert(h[#h], lg.set(cur_v, y))
      elseif lp.isStr('>') then
        local t = lg.set('x', lg.op('x', '+', lg.literal(1)))
        table.insert(h[#h], t)
        table.insert(h[#h], zset)
      elseif lp.isStr('<') then
        local t = lg.set('x', lg.op('x', '-', lg.literal(1)))
        table.insert(h[#h], t)
        table.insert(h[#h], zset)
      elseif lp.isStr('[') then
        table.insert(h, {})
      elseif lp.isStr(']') then
        if #h == 1 then lp.error('too many closes') end
        z = lg.block(h[#h])
        h[#h] = nil
        local cond = lg.op(cur_v, '~=', lg.literal(0))
        local w = lg.while_(cond, z)
        table.insert(h[#h], w)
      else
        cmt = false
      end
      if cmt then
        table.insert(h[#h], lg.comment(lp.getCurrPosStr()))
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
local generated, loc = lg.generate(lg.top(ret))
print("Err Loc Table")
for k, v in pairs(loc) do
  print(k, v)
end
writeFile(out_filename, generated)
