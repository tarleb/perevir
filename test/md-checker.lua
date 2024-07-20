--- Command line arguments
local arg = arg
local perevir = require 'perevir'

local opts = perevir.parse_args(arg)
local perevirka = perevir.Perevirka.new{
  accept = opts.accept
}
perevirka:test_files_in_dir(opts.path)
