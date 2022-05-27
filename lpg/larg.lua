-- larg: Simple commandline arg parser helper

-- larg takes a table of arguments (arg)
-- and give a result table
-- * common arguments are pushed with int args
-- * an option (e.g. -h, --version) is inserted as key except the first `-`
--   and the value of the entry is a table.
-- * if a common argument comes after an option, it's pushed into the
--   entry table.
-- * if no common argument exists after an option, it'll push `true` to
--   the entry table
-- * when `--` appear, all after arguments are pushed in `-` entry table.
-- Example:
-- When you run lua test.lua 4 -h q -v -l lib -l lamb 3 --go 2 -- 1 0 -z
-- The result of `larg` is:
-- {'4', '3',
--  ['h'] = {'q'},
--  ['v'] = {true},
--  ['l'] = {'lib', 'lamb'},
--  ['-go'] = {'2'},
--  ['-'] = {'1', '0', '-z'}}

local addOpt = function(res, name, val)
  if res[name] == nil then
    res[name] = {}
  end
  table.insert(res[name], val)
end

local larg = function(args)
  if args == nil then return {} end
  local result = {}
  local opt = nil
  for i, v in ipairs(args) do
    if v == '--' then
      while i < #args do
        i = i + 1
        addOpt(result, '-', args[i])
      end
      break
    elseif v:sub(1, 1) == '-' then
      if opt then
        addOpt(result, opt, true)
      end
      opt = v:sub(2)
    else
      if opt then
        addOpt(result, opt, v)
        opt = nil
      else
        table.insert(result, v)
      end
    end
  end
  if opt then
    addOpt(result, opt, true)
  end
  return result
end

return larg

