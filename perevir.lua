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
  local input, output = nil, nil

  doc:walk{
    CodeBlock = function (cb)
      if self.is_input(cb) then
        input = cb
      elseif self.is_output(cb) then
        output = cb
      end
    end
  }

  return input, output
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

--- Accept the actual document as correct and rewrite the test file.
TestRunner.accept = function (test)
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
      if is_output_code(cb) then
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
function M.run_test_file (reader, filepath, accept)
  local testfile = assert(filepath, "test file required")
  local testparser = TestParser.new()
  local test = testparser:create_test(testfile)

  assert(test.input, 'No input found in test file ' .. test.filepath)
  assert(
    accept or test.output,
    'No expected output found in test file ' .. test.filepath
  )

  test.actual = reader(test.input .. '\n')
  local ok, expected_doc = pcall(pandoc.read, test.output, 'native')

  if ok and test.actual == expected_doc then
    return true
  elseif accept then
    test.expected = expected_doc
    TestRunner.accept(test)
    return true
  elseif not ok then
    io.stderr:write('Could not parse expected doc: \n' .. test.output .. '\n')
  else
    test.expected = expected_doc
    TestRunner.report_failure(test)
    return false
  end
end

function M.test_files_in_dir(reader, source, accept)
  local success = true
  local is_dir, dirfiles = pcall(system.list_directory, source)
  local testfiles = pandoc.List{}
  if not is_dir then
    testfiles:insert(source)
  else
    local add_dir = function(p) return path.join{source, p} end
    testfiles = pandoc.List(dirfiles):map(add_dir)
  end

  for _, testfile in ipairs(testfiles) do
    success = success and M.run_test_file(reader, testfile, accept)
  end

  os.exit(success and 0 or 1)
end

function M.do_checks(reader, opts)
  return M.test_files_in_dir(reader, opts.path, opts.accept)
end

return M
