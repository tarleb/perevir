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


local TestParser = {}

--- Checks whether a pandoc CodeBlock element contains the expected output.
local is_output_code = function (codeblock)
  return codeblock.identifier:match '^out'
    or codeblock.identifier == 'expected'
end

--- Test object for transformation tests.
local Test = {}
Test.new = function (filepath)
  return setmetatable({}, {__index = Test})
end
Test.from_file = function (filepath)
  local input, output, options = nil, nil, {}
  local filecontents = select(2, mediabag.fetch(filepath))
  local doc = pandoc.read(filecontents):walk{
    CodeBlock = function (cb)
      if cb.identifier:match'^in' or cb.classes[1] == 'markdown' then
        input = cb.text
      elseif is_output_code(cb) then
        output = cb.text
      elseif cb.identifier == 'options' or cb.classes:includes 'lua' then
        local ok, thunk = pcall(load, cb.text)
        if ok then
          options = thunk()
        else
          warn('Error parsing options: ', thunk)
        end
      end
    end
  }
  return {
    filepath = filepath,       -- path to the test file
    doc      = doc,            -- the full test document (Pandoc)
    options  = options,        -- test options
    input    = input .. '\n',  -- pandoc gobbles the final newline
    output   = output,         -- expected string output
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
  local test = Test.from_file(testfile)

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
