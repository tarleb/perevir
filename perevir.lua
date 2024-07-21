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
local structure= require 'pandoc.structure'
local template = require 'pandoc.template'
local utils    = require 'pandoc.utils'

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
  return block.identifier
    and block.identifier:match'^input$'
    or block.identifier:match'^in$'
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

  structure.make_sections(doc):walk{
    CodeBlock = function (cb)
      if self.is_input(cb) then
        set('input', cb)
      elseif self.is_output(cb) then
        set('output', cb)
      end
    end,
    Div = function (div)
      if self.is_input(div) then
        set('input', div)
      elseif self.is_output(div) then
        set('output', div)
      end
    end,
  }

  if blocks.input.t == 'Div' and blocks.input.classes[1] == 'section' then
    local section = blocks.input:clone()
    section.content:remove(1)
    blocks.input = section
  end
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
    options  = doc.meta.perevir or {}, -- test options
    input    = input,          -- input code block or div
    output   = output,         -- expected string output
    actual   = false,          -- actual conversion result (Pandoc|false)
    expected = false,          -- expected document result (Pandoc|false)
  }
end

--- The test runner
local TestRunner = {}
TestRunner.__index = TestRunner

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
    end,
    Div = function (div)
      if test_factory.is_output(div) then
        found_outblock = true
        div.content = actual.blocks
        return div
      end
    end
  }
  if not found_outblock then
    doc.blocks:insert(pandoc.CodeBlock(actual_str, {'expected'}))
  end
  local md_writer_opts = {template = template.default 'markdown'}
  local fh = io.open(filename, 'w')
  fh:write(pandoc.write(testdoc, 'markdown', md_writer_opts))
  fh:close()
end

--- Report a test failure
TestRunner.report_failure = function (test)
  io.stderr:write('Failed: ' .. test.filepath .. '\n')
  assert(test.actual, "The actual result is missing from the test object")
  assert(test.expected, "The expected result is missing from the test object")

  local opts = {}
  if next(test.actual.meta) or (next(test.expected.meta)) then
    -- has metadata, use template
    opts.template = pandoc.template.default 'native'
  end
  local actual_str   = pandoc.write(test.actual, 'native', opts)
  local expected_str = pandoc.write(test.expected, 'native', opts)
  system.with_temporary_directory('perevir-diff', function (dir)
    system.with_working_directory(dir, function ()
      local fha = io.open('actual', 'wb')
      local fhe = io.open('expected', 'wb')
      fha:write(actual_str)
      fhe:write(expected_str)
      fha:close()
      fhe:close()
      os.execute('diff --color -c expected actual')
    end)
  end)
end

function TestRunner:get_doc (block)
  if block.t == 'CodeBlock' then
    local text = block.text .. '\n\n'

    if self.reader then
      return self.reader(text)
    else
      local format = block.classes[1] or 'markdown'
      local exts = block.attributes.extensions or ''
      -- pandoc gobbles the final newline in code blocks
      return pandoc.read(text, format .. exts)
    end
  end
  return pandoc.Pandoc(block.content)
end


--- Run the test in the given file.
TestRunner.run_test = function (self, test, accept)
  assert(test.input, 'No input found in test file ' .. test.filepath)
  assert(
    accept or test.output,
    'No expected output found in test file ' .. test.filepath
  )

  test.actual = self:get_doc(test.input)

  for i, filter in ipairs(test.options.filters or {}) do
    test.actual = utils.run_lua_filter(test.actual, utils.stringify(filter))
  end

  local output = test.output
  local ok, expected_doc = true, pandoc.Pandoc(output)
  if output.t == 'CodeBlock' then
    ok, expected_doc = pcall(pandoc.read, output.text, 'native')
  elseif output.t == 'Div' and output.classes[1] == 'section' then
    local section_content = output.content:clone()
    section_content:remove(1)
    expected_doc = pandoc.Pandoc(section_content)
  elseif output.t == 'Div' then
    expected_doc = pandoc.Pandoc(output.content)
  end

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
    success = self:test_file(testfile) and success
  end

  os.exit(success and 0 or 1)
end

--- Perform tests on the files given in `opts.path`.
function M.do_checks(opts)
  local perevirka = Perevirka.new {
    runner = opts.runner or TestRunner.new(),
    accept = opts.accept,
  }
  return perevirka:test_files_in_dir(opts.path)
end

M.Perevirka = Perevirka
M.TestParser = TestParser
M.TestRunner = TestRunner

-- Run the default tests when the file is called as a script.
if not pcall(debug.getlocal, 4, 1) then
  local opts = M.parse_args(arg)
  M.do_checks(opts)
end

return M
