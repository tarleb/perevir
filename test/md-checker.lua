--- Command line arguments
local arg = arg
local pandoc  = require 'pandoc'
local perevir = require 'perevir'

local Reader = pandoc.read
local opts = perevir.parse_args(arg)
perevir.do_checks(Reader, opts)
