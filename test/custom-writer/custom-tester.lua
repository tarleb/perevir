--- Command line arguments
local arg = arg
local perevir = require 'perevir'
local TestRunner

local opts = perevir.parse_args(arg)
local pereviryalnyk = perevir.Pereviryalnyk.new{
  accept = opts.accept,
  runner = perevir.TestRunner.new {
    ioformats = {
      write = {
        custom = function (doc)
          local out = pandoc.write(doc, 'plain')
          return out:upper():gsub('\n*$', '')
        end
      }
    }
  }
}
pereviryalnyk:test_files_in_dir(opts.path)
