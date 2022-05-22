-- lp.lua
-- Parser Helper in Lua

local saved_ctxt = {}
local ctxt = nil

local lp = {}

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
    p = 1,
    ln = 1,
    col = 1,
  }
end

lp.close = function()
  if #saved_ctxt >= 1 then
    ctxt = saved_ctxt[#saved_ctxt]
    saved_ctxt[#saved_ctxt] = nil
  else
    ctxt = nil
  end
end

lp.parse = function(p, contents, name)
  lp.open(contents, name)
  local status, result = pcall(p)
  lp.close()
  return status, result
end

lp.getCurrPos = function()
  local f = 'Parse Error in lp\n'
  return string.format('%s%s:%d:%d', f, ctxt.name, ctxt.ln, ctxt.col)
end

lp.error = function(msg)
  local pos = lp.getCurrPos()
  error(pos .. ': ' .. msg)
end

return lp

