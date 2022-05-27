-- lish: Interactive shell helper

-- handler is a function: (src, opt) -> action
-- Argument of handler is:
-- * (nil, 'start') : notify that ish started
-- * (nil, 'end') : notify that ish finished
-- * (src, false) : check src without evaluation (only handle command)
-- * (src, true) : check src and evaluation
-- And the action can be
-- * nil : nothing occur
-- * 'start_multiline' : start multiline mode, until 'end_multiline' is given
-- * 'end_multiline' : finish multiline mode and require accumulated input
-- * 'exit' : finish ish

-- ish can be finished with `^D`

local default_options = {
  cursor = '> ',
  cursor_mult = '| ',
}

local lish = function(handler, options)
  local opt = {}
  if options then
    for k, v in pairs(options) do
      opt[k] = v
    end
  end
  for k, v in pairs(default_options) do
    if opt[k] == nil then opt[k] = v end
  end
  handler(nil, 'start')
  local is_multiline = false
  local inputs = ''
  while true do
    if is_multiline then
      io.stdout:write(opt.cursor_mult)
    else
      io.stdout:write(opt.cursor)
    end
    io.stdout:flush()
    local input = io.stdin:read('*l')
    if input == nil then break end
    local i = input:gsub("^%s(.-)%s*$", "%1")
    local res, ret = pcall(handler, i, not is_multiline)
    if res then
      if ret == 'exit' then
        break
      elseif ret == 'end_multiline' then
        is_multiline = false
        res, ret = pcall(handler, inputs, true)
      elseif ret == 'start_multiline' then
        is_multiline = true
        inputs = ''
      elseif is_multiline then
        if #inputs > 0 then inputs = inputs .. '\n' end
        inputs = inputs .. input
      end
    end
    if not res then
      print("ERROR")
      print(ret)
    end
  end
  handler(nil, 'end')
end

return lish

