local dbg = require 'dbg'

local a = {}

local is_dir = love.filesystem.isDirectory
local list_dir = love.filesystem.getDirectoryItems

local handlers = {}
function a.register(extension, loader)
  handlers[extension:lower()] = loader
end

function a.load(current_dir, t)
  if current_dir == nil then
    current_dir = ''
  end
  if t == nil then
    t = a
  end

  for _, filename in ipairs(list_dir(current_dir)) do
    local full_path = current_dir .. '/' .. filename
    if is_dir(filename) then
      t[filename] = {}
      a.load(full_path, t[filename])
    else
      local extension = filename:gsub('.+%.(.+)', '%1'):lower()
      local name = filename:gsub('(.+)%..+', '%1')
      if handlers[extension] then
	dbg.printf('loading [[%s]]', full_path)
	t[name] = handlers[extension](full_path)
      else
	dbg.printf('skipping [[%s]]', full_path)
      end
    end
  end
end

return a
