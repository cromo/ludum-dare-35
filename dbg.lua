local dbg = {}

dbg.enabled = true

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

return dbg
