--- Command line arguments
local arg = arg
local perevir = require 'perevir'

local opts = perevir.parse_args(arg)
local pereviryalnyk = perevir.Pereviryalnyk.new{
  accept = opts.accept
}
pereviryalnyk:test_files_in_dir(opts.path)
