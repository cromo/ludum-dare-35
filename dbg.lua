local dbg = {}

dbg.enabled = true

function dbg.print(...)
  if dbg.enabled then
    print(...)
  end
end

return dbg
