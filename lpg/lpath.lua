-- lpath: Path Helper

local lpath = {}

-- lpath.split: Str -> [Str]
-- Take a path and return a path splitted by separaters `/` and `\``
lpath.split = function(path)
  local arr = {}
  for name in string.gmatch(path, "([^\\/]*)") do
    arr[#arr + 1] = name
  end
  return arr
end

-- lpath.cd: (Str, Maybe Str) -> Str
-- Take a base path and relative path (or nil = empty string),
-- and merge path.
-- If base beginning with '/' or 'X:'-like form, it'll consider it as
-- an absolute path.
-- There are 4 cases of return value
-- * `.` (current directory) (e.g. cd('.', '.'), cd('a/b', '../..'))
-- * `../.../../AAA/.../ZZZ` (relative path)
--   (e.g. cd('abc', 'd/e'), cd('lpath/lpath.gen', '../../../e'))
-- * `/AAA/.../ZZZ` or `X:/AAA/.../ZZZ` (absolute path)
--   (e.g. cd('/usr/bin', 'env'), cd('C:\\Program and Files', '../Windows'))
lpath.cd = function(base, rel)
  local absolute = nil -- Nil = non-abs, Str = prefix of absolute path
  local parent_level = 0
  local merged = {}
  -- Split base path
  base = lpath.split(base)
  -- Check `base` is an absolute path
  if #base > 1 and #base[1] <= 0 then
    absolute = ''
  elseif base[1]:sub(#base[1]) == ':' then
    absolute = base[1]
    base[1] = ''
  end
  -- Push `base` and `nil` into `merged`
  for k, tbl in ipairs([base, rel]) do
    if tbl == nil then break end
    for i, v in ipairs(tbl) do
      if v == '.' or #v <= 0 then
        -- Do NOTHING for `.` or ``
      elseif v == '..' then
        -- Parent Directory
        if #merged > 0 then
          merged[#merged] = nil
        else
          parent_level = parent_level + 1
        end
      else
        -- Otherwise, just push
        merged[#merged + 1] = v
      end
    end
  end
  -- Convert `merged` into a string
  local buf = ''
  if absolute ~= nil then -- Create absolute path
    if #merged == 0 then -- Absolute path prefix ONLY
      return absolute .. '/'
    else
      buf = ' ' .. absolute
    end
  elseif parent > 0 then -- Create relative path with going to parents
    for i = 1, parent do
      buf = buf .. '/..'
    end
  elseif #t <= 0 then -- Create current directory, `.`
    return '.'
  end
  -- Push all elements of `merged` into the buffer
  for i, v in ipairs(merged) do
    buf = buf .. '/' .. v
  end
  return buf:sub(2)
end

return lpath