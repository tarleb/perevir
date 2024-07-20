#!/usr/bin/env pandoc-lua
--- perevir – a test tool for pandoc transformations.
--
-- Copyright: © 2024 Albert Krewinkel <albert+pandoc@tarleb.com>
-- License: MIT

-- Standard Lua modules
local io = require 'io'
local os = require 'os'

-- Pandoc modules
local pandoc   = require 'pandoc'
local mediabag = require 'pandoc.mediabag'
local path     = require 'pandoc.path'
local system   = require 'pandoc.system'

--- Command line arguments; only set when invoked as a script.
local arg = arg

local usage = [==[Usage:

    %s [-a] TESTFILE

Options:

  -a: Accept the parse result as correct and update the test file.
]==]

--- The perevir module.
local M = {}

--- Parse command line arguments
function M.parse_args (args)
  local accept = false -- whether to accept output as correct
  for i = #args, 1, -1 do
    if args[i] == '-a' then
      accept = true
      table.remove(args, i)
    end
  end

  return {
    accept = accept,
    path = args[1],
  }
end


--- Test factory.
local TestParser = {}
TestParser.__index = TestParser

-- Creates a new TestParser object..
function TestParser.new (opts)
  opts = opts or {}
  local newtp = {
    is_output = opts.is_output,
    is_input  = opts.is_input,
    reader    = opts.reader,
  }
  return setmetatable(newtp, TestParser)
end

--- Checks whether a pandoc Block element contains the expected output.
function TestParser.is_output (block)
  return block.identifier
    and block.identifier:match '^out'
    or block.identifier == 'expected'
end

--- Checks whether a pandoc Block element contains the input.
function TestParser.is_input (block)
  return block.identifier:match'^in'
end

--- Parses a test file into a Pandoc object.
function TestParser.reader (text, opts)
  return pandoc.read(text, 'markdown', opts)
end

--- Get the code blocks that define the tests
function TestParser:get_test_blocks (doc)
  local blocks = {}

  local function set (kind, block)
    if blocks[kind] then
      error('Found two potential ' .. kind .. ' blocks, bailing out.')
    else
      blocks[kind] = block
    end
  end

  doc:walk{
    CodeBlock = function (cb)
      if self.is_input(cb) then
        set('input', cb)
      elseif self.is_output(cb) then
        set('output', cb)
      end
    end,
  }

  return blocks.input, blocks.output
end

--- Generates a new test object from the given file.
function TestParser:create_test (filepath)
  local text = select(2, mediabag.fetch(filepath))
  local doc = self.reader(text)
  local input, output = self:get_test_blocks(doc)
  return {
    filepath = filepath,       -- path to the test file
    text     = text,           -- full text for this test
    doc      = doc,            -- the full test document (Pandoc)
    input    = input.text .. '\n',  -- pandoc gobbles the final newline
    output   = output.text,    -- expected string output
    actual   = false,          -- actual conversion result (Pandoc|false)
    expected = false,          -- expected document result (Pandoc|false)
  }
end

--- The test runner
local TestRunner = {}
TestRunner.__index = TestRunner

TestRunner.reader = function (input, opts)
  return pandoc.read(input, 'markdown', opts)
end

function TestRunner.new (opts)
  opts = opts or {}
  local newtr = {
    reader = opts.reader
  }
  return setmetatable(newtr, TestRunner)
end

--- Accept the actual document as correct and rewrite the test file.
TestRunner.accept = function (self, test, test_factory)
  test_factory = test_factory or TestParser.new()
  local actual = test.actual
  local filename = test.filepath
  local testdoc = test.doc
  local writer_opts = {}
  if next(actual.meta) then
    -- has metadata, use template
    writer_opts.template = pandoc.template.default 'native'
  end
  local actual_str = pandoc.write(actual, 'native', writer_opts)
  local found_outblock = false
  testdoc = testdoc:walk{
    CodeBlock = function (cb)
      if test_factory.is_output(cb) then
        found_outblock = true
        cb.text = actual_str
        return cb
      end
    end
  }
  if not found_outblock then
    doc.blocks:insert(pandoc.CodeBlock(actual_str, {'expected'}))
  end
  local fh = io.open(filename, 'w')
  fh:write(pandoc.write(testdoc, 'markdown'))
  fh:close()
end

--- Report a test failure
TestRunner.report_failure = function (test)
  local opts = {}
  assert(test.actual, "The actual result is missing from the test object")
  assert(test.expected, "The expected result is missing from the test object")
  if next(test.actual.meta) or (next(test.expected.meta)) then
    -- has metadata, use template
    opts.template = pandoc.template.default 'native'
  end
  local actual_str   = pandoc.write(test.actual, 'native', opts)
  local expected_str = pandoc.write(test.expected, 'native', opts)
  io.stderr:write('Failed: ' .. test.filepath .. '\n')
  io.stderr:write('Expected:\n')
  io.stderr:write(expected_str)
  io.stderr:write('\n\n')
  io.stderr:write('Actual:\n')
  io.stderr:write(actual_str)
end

--- Run the test in the given file.
TestRunner.run_test = function (self, test, accept)
  assert(test.input, 'No input found in test file ' .. test.filepath)
  assert(
    accept or test.output,
    'No expected output found in test file ' .. test.filepath
  )

  test.actual = self.reader(test.input .. '\n')
  local ok, expected_doc = pcall(pandoc.read, test.output, 'native')

  if ok and test.actual == expected_doc then
    return true
  elseif accept then
    test.expected = expected_doc
    self:accept(test)
    return true
  elseif not ok then
    io.stderr:write('Could not parse expected doc: \n' .. test.output .. '\n')
  else
    test.expected = expected_doc
    TestRunner.report_failure(test)
    return false
  end
end

--- Complete tester object.
local Perevirka = {}
Perevirka.__index = Perevirka
Perevirka.accept = false
Perevirka.runner = TestRunner.new()
Perevirka.test_parser = TestParser.new()
Perevirka.new = function (opts)
  local perevirka = {}
  perevirka.accept = opts.accept
  perevirka.runner = opts.runner
  perevirka.test_parser = opts.test_parser
  return setmetatable(perevirka, Perevirka)
end

function Perevirka:test_file (filepath)
  assert(filepath, "test file required")
  local test = self.test_parser:create_test(filepath)
  return self.runner:run_test(test, self.accept)
end

function Perevirka:test_files_in_dir (filepath)
  local is_dir, dirfiles = pcall(system.list_directory, filepath)
  local testfiles = pandoc.List{}
  if not is_dir then
    testfiles:insert(filepath)
  else
    local add_dir = function(p) return path.join{filepath, p} end
    testfiles = pandoc.List(dirfiles):map(add_dir)
  end

  local success = true
  for _, testfile in ipairs(testfiles) do
    success = self:test_file(filepath) and success
  end

  os.exit(success and 0 or 1)
end

--- Perform tests on the files given in `opts.path`.
function M.do_checks(reader, opts)
  local perevirka = Perevirka.new {
    runner = TestRunner.new{reader = reader},
    accept = opts.accept,
  }
  return perevirka:test_files_in_dir(opts.path)
end

M.Perevirka = Perevirka
M.TestParser = TestParser
M.TestRunner = TestRunner

-- Run the default tests when the file is called as a script.
if arg then
  local Reader = pandoc.read
  local opts = M.parse_args(arg)
  M.do_checks(Reader, opts)
end

return M
