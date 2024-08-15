-- This filter simply adds the target format to the metadata.
function Meta (meta)
  meta.format = pandoc.Inlines(FORMAT)
  return meta
end
