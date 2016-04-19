local dbg = {}

dbg.enabled = false
-- dbg.enabled = true

function dbg.print(...)
  if dbg.enabled then
    print(...)
  end
end

function dbg.printf(formatstring, ...)
  if dbg.enabled then
    print(string.format(formatstring, ...))
  end
end

local function noop() end
local function debugging(self, f, ...)
  if dbg.enabled then
    return f(...)
  end
end
setmetatable(dbg, {__call = debugging})

return dbg
