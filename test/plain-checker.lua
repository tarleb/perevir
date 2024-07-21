--- Command line arguments
local arg = arg
local perevir = require 'perevir'

loadfile('test/plain-reader.lua')()

local opts = perevir.parse_args(arg)
local pereviryalnyk = perevir.Pereviryalnyk.new{
  accept = opts.accept,
  runner = perevir.TestRunner.new{reader = Reader},
}
pereviryalnyk:test_files_in_dir(opts.path)
