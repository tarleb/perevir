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
local ConversionTest = {}
ConversionTest.new = function (filepath)
  return setmetatable({}, {__index = ConversionTest})
end
ConversionTest.from_file = function (filepath)
  local input, expected, options = nil, nil, {}
  local filecontents = select(2, mediabag.fetch(filepath))
  local doc = pandoc.read(filecontents):walk{
    CodeBlock = function (cb)
      if cb.identifier:match'^in' or cb.classes[1] == 'markdown' then
        input = cb.text
      elseif is_output_code(cb) then
        expected = cb.text
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
    doc = doc,
    filepath = filepath,
    input = input .. '\n',  -- pandoc gobbles the final newline
    expected = expected,
    options = options,
  }
end


--- The test runner
local TestRunner = {}

--- Accept the actual document as correct and rewrite the test file.
TestRunner.accept = function (filename, testdoc, actual)
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
TestRunner.report_failure = function (filepath, actual, expected)
  local opts = {}
  if next(actual.meta) or next(expected.meta) then
    -- has metadata, use template
    opts.template = pandoc.template.default 'native'
  end
  local actual_str = pandoc.write(actual, 'native', opts)
  local expected_str = pandoc.write(expected, 'native', opts)
  io.stderr:write('Failed: ' .. filepath .. '\n')
  io.stderr:write('Expected:\n')
  io.stderr:write(expected_str)
  io.stderr:write('\n\n')
  io.stderr:write('Actual:\n')
  io.stderr:write(actual_str)
end

--- Run the test in the given file.
function M.run_test_file (reader, filepath, accept)
  local testfile = assert(filepath, "test file required")
  local test = ConversionTest.from_file(testfile)

  assert(test.input, 'No input found in test file ' .. test.filepath)
  assert(
    accept or test.expected,
    'No expected output found in test file ' .. test.filepath
  )

  local actual_doc = reader(test.input .. '\n')
  local ok, expected_doc = pcall(pandoc.read, test.expected, 'native')

  if ok and actual_doc == expected_doc then
    return true
  elseif accept then
    TestRunner.accept(filepath, test.doc, actual_doc)
    return true
  elseif not ok then
    io.stderr:write('Could not parse expected doc: \n' .. test.expected .. '\n')
  else
    TestRunner.report_failure(filepath, actual_doc, expected_doc)
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
