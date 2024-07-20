--- Command line arguments
local arg = arg
local perevir = require 'perevir'

loadfile('test/plain-reader.lua')()

local opts = perevir.parse_args(arg)
local perevirka = perevir.Perevirka.new{
  accept = opts.accept,
  runner = perevir.TestRunner.new{reader = Reader},
}
perevirka:test_files_in_dir(opts.path)
