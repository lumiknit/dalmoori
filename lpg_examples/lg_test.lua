#!/usr/bin/env lua

-- Load LPG
package.path = package.path .. ";../?.lua"
lg = require('lpg/lg')
lp = require('lpg/lp')

-----------------------------------------------------------------

function E(expected)
  print("[Expected] " .. expected)
end

function X(expected)
  print("[Expected]\n" .. expected)
end

function G(g)
  print("[Generated]")
  local txt, loc = lg.generate(lg.top(g))
  print(txt)
  print()
end

-----------------------------------------------------------------

print("--- Simple Expressions ---");

(function()
  E('a = 42')
  G({ lg.set('a', lg.literal(42)) })
end)();

(function()
  E('local hello = "world!\\n"')
  G({
    lg.local_('hello', lg.literal("world!\n"))
  })
end)();

(function()
  E('a = (3 + 2) * 4 * 5 - 10 ^ (2 - 1) and (-5) ^ (#a) ')
  local n2 = lg.literal(2)
  local n4 = lg.literal(4)
  local n5 = lg.literal(5)
  local l2 = lg.op(lg.op(lg.op(lg.literal(3), '+', n2), '*', n4), '*', n5)
  local r2 = lg.op(lg.literal(10), '^', lg.op(n2, '-', lg.literal(1)))
  local l1 = lg.op(l2, '-', r2)
  local r1 = lg.op(lg.op('-', n5), '^', lg.op('#', 'a'))
  local e = lg.op(l1, 'and', r1)
  G({ lg.set('a', e) })
end)();

(function()
  E('a = -1 + (1 + -1 + 1) + 1 - (1 - 1) - 1')
  local n1 = lg.literal(1)
  local a1 = lg.op('-', n1)
  local a2 = lg.op(lg.op(n1, '+', lg.op('-', n1)), '+', n1)
  local a3 = lg.op(a1, '+', a2)
  local a4 = lg.op(a3, '+', n1)
  local a5 = lg.op(n1, '-', n1)
  local a6 = lg.op(a4, '-', a5)
  local e = lg.op(a6, '-', n1)
  G({ lg.set('a', e) })
end)();

(function()
  E('a = ("test"):byte() + x.f[3](5) .. {}[5]')
  local s_t = lg.literal('test')
  local n_3 = lg.literal(3)
  local n_5 = lg.literal(5)
  local tb = lg.app(lg.method(s_t, 'byte'), {})
  local xf = lg.app(lg.index(lg.access('x', 'f'), n_3), {n_5})
  local t5 = lg.app(lg.table({}), n_5)
  local e = lg.op(lg.op(tb, '+', xf), '..', t5)
  G({ lg.set('a', e) })
end)();

(function()
  E('local a, b, c = nil, {3, 4, [4]=42, boom=false}[2], true')
  local l = lg.literal
  local lhs = lg.comma({'a', 'b', 'c'})
  local r1 = l(nil)
  local tbl = {l(3), l(4), [4]=l(42), boom=l(false)}
  local r2 = lg.index(lg.table(tbl), l(2))
  local r3 = l(true)
  local rhs = lg.comma({r1, r2, r3})
  G({ lg.local_(lhs, rhs) })
end)();

-----------------------------------------------------------------

print("--- Simple Statements ---");

(function()
  X([[
if x == 20 then
  print("BOOM")
elseif y then
  print("ahh")
else
  print("dead")
end]])
  local l = lg.literal
  local c1 = lg.op('x', '==', l(20))
  local c2 = 'y'
  local pr1 = lg.app('print', {l('BOOM')})
  local pr2 = lg.app('print', {l('ahh')})
  local pr3 = lg.app('print', {l('dead')})
  local b1 = lg.block({pr1})
  local b2 = lg.block({pr2})
  local b3 = lg.block({pr3})
  G({ lg.if_({c1, b1, c2, b2, b3}) })
end)();

(function()
  X([[
if x == 20 then
  print("BOOM")
else
  print("dead")
end]])
  local l = lg.literal
  local c1 = lg.op('x', '==', l(20))
  local c2 = 'y'
  local pr1 = lg.app('print', {l('BOOM')})
  local pr3 = lg.app('print', {l('dead')})
  local b1 = lg.block({pr1})
  local b3 = lg.block({pr3})
  G({ lg.if_({c1, b1, b3}) })
end)();

(function()
  X([[
if x == 20 then
  print("BOOM")
elseif y then
  print("ahh")
end]])
  local l = lg.literal
  local c1 = lg.op('x', '==', l(20))
  local c2 = 'y'
  local pr1 = lg.app('print', {l('BOOM')})
  local pr2 = lg.app('print', {l('ahh')})
  local pr3 = lg.app('print', {l('dead')})
  local b1 = lg.block({pr1})
  local b2 = lg.block({pr2})
  G({ lg.if_({c1, b1, c2, b2,}) })
end)();

(function()
  X([[
while true do
  io.read('*a')
end]])
  local c = lg.literal(true)
  local d = lg.app('io.read', {lg.literal('*a')})
  G({ lg.while_(c, lg.block({d})) })
end)();

(function()
  X([[
local acc = 0
for i = 1, 10 do
  acc = acc + i
end]])
  local l = lg.literal
  local inc = lg.set('acc', lg.op('acc', '+', 'i'))
  G({ lg.local_('acc', l(0)),
      lg.for_('i', l(1), l(10), nil, lg.block({ inc })) })
end)();

(function()
  X([[
local acc = 0
for i = 1, 10, 2 do
  break
  acc = acc + i
end]])
  local l = lg.literal
  local inc = lg.set('acc', lg.op('acc', '+', 'i'))
  G({ lg.local_('acc', l(0)),
      lg.for_('i', l(1), l(10), l(2), lg.block({
        lg.break_(),
        inc })) })
end)();

-----------------------------------------------------------------

print("--- Functions ---");

(function()
  X([[
function fibo(n)
  if n <= 1 then
    return n
  else
    return fibo(n - 1) + fibo(n - 2)
  end
end]])
  local l = lg.literal
  local c1 = lg.op('n', '<=', l(1))
  local r1 = lg.return_('n')
  local a1 = lg.app('fibo', { lg.op('n', '-', l(1)) })
  local a2 = lg.app('fibo', { lg.op('n', '-', l(2)) })
  local r2 = lg.return_(lg.op(a1, '+', a2))
  local br = lg.if_({
    c1, lg.block({ r1 }),
    lg.block({ r2 })
  })
  local fb = { br }
  local f = lg.fn({'n'}, lg.block(fb), 'fibo')
  G({ f })
end)();

(function()
  X([[
local tbl = {
  boom = function(self, x, y)
    return x + y
  end
}]])
  local r = lg.return_(lg.op('x', '+', 'y'))
  local f = lg.fn({'self', 'x', 'y'}, lg.block({r}))
  local t = lg.table({
    boom = f
  })
  local lc = lg.local_('tbl', t)
  G({ lc })
end)();

(function()
  X([[
5 + (function(x); return x + 1; end)(42) + 6]])
  local l = lg.literal
  local r = lg.return_(lg.op('x', '+', l(1)))
  local f = lg.fn({'x'}, lg.block({r}))
  local a = lg.app(f, {l(42)})
  local v = lg.op(lg.op(l(5), '+', a), '+', l(6))
  G({ v })
end)();

(function()
  X([[
obj:z = function(x)
  return function(y)
    return x << y
  end
end]])
  local l = lg.literal
  local rf_nested = lg.return_(lg.op('x', '<<', 'y'))
  local f_nested = lg.fn({'y'}, lg.block({ rf_nested }))
  local rf = lg.return_(f_nested)
  local rhs = lg.fn({'x'}, lg.block({ rf }))
  G({ lg.set(lg.method('obj', 'z'), rhs) })
end)();