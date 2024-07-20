function Emph (emph)
  if #emph.content == 1 and emph.content[1].t == 'Emph' then
    return pandoc.SmallCaps(emph.content[1].content)
  end
end
