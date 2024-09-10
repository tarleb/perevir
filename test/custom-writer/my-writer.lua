local pandoc = require 'pandoc'
function Writer (doc, opts)
  local out = pandoc.write(doc, 'plain', opts)
  return out:upper()
end
