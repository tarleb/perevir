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
local List     = require 'pandoc.List'
local mediabag = require 'pandoc.mediabag'
local path     = require 'pandoc.path'
local system   = require 'pandoc.system'
local structure= require 'pandoc.structure'
local template = require 'pandoc.template'
local utils    = require 'pandoc.utils'

local ptype = utils.type

--- Command line arguments; only set when invoked as a script.
local arg = arg

local usage = [==[Usage:

    %s [-a] [-f FORMAT] TESTFILE

Options:

  -a: Accept the parse result as correct and update the test file.

  -f: Sets the reader format used to parse perevirky test definitions.
]==]


--- The perevir module.
local M = {}

--- Parse command line arguments
function M.parse_args (args)
  local accept = false -- whether to accept output as correct
  local format = 'markdown'
  local filepath
  local i = 1
  while i <= #args do
    if args[i] == '-a' then
      accept = true
      i = i + 1
    elseif args[i] == '-f' then
      format = args[i+1]
      i = i + 2
    elseif args[i]:sub(1,1) == '-' then
      io.stdout:write(usage)
      io.stdout:write('\n')
      os.exit(2)
    else
      filepath = args[i]
      i = i + 1
    end
  end

  return {
    accept = accept,
    format = format,
    path = filepath,
  }
end

--- A filter to generate GitHub-friendly code-blocks
local mod_syntax = {
  CodeBlock = function (cb)
    local lang = cb.classes:remove(1)
    if lang then
      local mdcode = pandoc.write(pandoc.Pandoc{cb}, 'markdown')
      return pandoc.RawBlock(
        'markdown',
        mdcode:gsub('^```+', '%1 ' .. lang)
      )
    end
  end,
}

--- A filter to replace plain strings with Inlines in metadata.
local metastrings_to_inlines = {
  Meta = function (meta)
    local function str2inlines (metadata)
      if type(metadata) == 'table' then
        for key, value in pairs(metadata) do
          metadata[key] = str2inlines(value)
        end
      elseif type(metadata) == 'string' then
        return pandoc.Inlines(metadata)
      end
      return metadata
    end

    return str2inlines(meta)
  end
}

--- Split a string on whitespace into a list.
local function split (str)
  local list = pandoc.List{}
  for s in string.gmatch(str, '[^%s]+') do
    list:insert(s)
  end
  return list
end

--- Reads a file and returns its contents.
local function read_file (filename)
  local fh = io.open(filename, 'r')
  local content = fh:read('a')
  fh:close()
  return content
end

--- Returns true if the given filepath exists and is a file
local function file_exists (filepath)
  local f = io.open(filepath, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

------------------------------------------------------------------------
--- Test factory.
local TestParser = {}
TestParser.__index = TestParser

-- Creates a new TestParser object..
function TestParser.new (opts)
  opts = opts or {}
  local newtp = {
    is_output = opts.is_output,
    is_input  = opts.is_input,
    format    = opts.format,
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

function TestParser.is_command (block)
  return block.identifier
    and block.identifier:match '^command$'
end

--- Parses a test file into a Pandoc object.
function TestParser:reader (text, opts)
  return pandoc.read(text, self.format, opts)
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
      elseif self.is_command(cb) then
        set('command', cb)
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
  return blocks.input, blocks.output, blocks.command
end

--- Generates a new test object from the given file.
function TestParser:create_test (filepath)
  local text = select(2, mediabag.fetch(filepath))
  local doc = self:reader(text)
  local input, output, command = self:get_test_blocks(doc)
  return {
    filepath = filepath,       -- path to the test file
    text     = text,           -- full text for this test
    doc      = doc,            -- the full test document (Pandoc)
    options  = doc.meta.perevir or {}, -- test options
    input    = input,          -- input code block or div
    output   = output,         -- expected string output
    command  = command,        -- specific command to run on the input
    actual   = false,          -- actual conversion result (Pandoc|false)
    expected = false,          -- expected document result (Pandoc|false)
    target_format = 'native',  -- the FORMAT value passed to filters
  }
end

------------------------------------------------------------------------
-- Test functions

--- Create a deep copy of a table.
local function copy_table (tbl, depth)
  if type(tbl) == 'table' then
    local copy = {}
    -- Iterate 'raw' pairs, i.e., without using metamethods
    for key, value in next, tbl, nil do
      if depth == 'shallow' then
        copy[key] = value
      else
        copy[copy_table(key)] = copy_table(value)
      end
    end
    return setmetatable(copy, getmetatable(tbl))
  else -- number, string, boolean, etc
    return tbl
  end
end

--- Create a copy of a test
local copy_test = copy_table

--- Create a modified test with the given default options
local function apply_test_options (test, default_options)
  local newtest = copy_test(test)
  for name, value in pairs(default_options) do
    if newtest.options[name] == nil then
      newtest.options[name] = value
    end
  end

  return newtest
end

------------------------------------------------------------------------
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

  local actual_str

  if ptype(actual) == 'string' then
    actual_str = actual
  else
    local writer_opts = {}
    local format = test.output.classes[1] or 'native'
    if format == 'haskell' then
      format = 'native'
    end
    local exts = test.output.attributes.extensions or ''

    if ptype(actual) == 'Pandoc' and next(actual.meta) then
      -- has metadata, use template
      writer_opts.template = pandoc.template.default(format)
    end

    actual_str = pandoc.write(actual, format .. exts, writer_opts)
  end

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
        assert(ptype(actual) == 'Pandoc', 'Actual value in test must be Pandoc')
        found_outblock = true
        div.content = actual.blocks
        return div
      end
    end
  }
  if not found_outblock then
    testdoc.blocks:insert(pandoc.CodeBlock(actual_str, {'expected'}))
  end
  local md_writer_opts = {
    template = template.default 'markdown',
    wrap_text = 'preserve',
  }
  local fh = io.open(filename, 'w')
  local out_format = 'markdown-fenced_divs-simple_tables'
  fh:write(pandoc.write(testdoc:walk(mod_syntax), out_format, md_writer_opts))
  fh:close()
end

TestRunner.diff = function (expected, actual)
  return system.with_temporary_directory('perevir-diff', function (dir)
    return system.with_working_directory(dir, function ()
      local fha = io.open('actual', 'wb')
      local fhe = io.open('expected', 'wb')
      fha:write(actual)
      fhe:write(expected)
      fha:close()
      fhe:close()
      return io.popen('diff --color=always -c expected actual'):read('a')
    end)
  end)
end

--- Report a test failure
function TestRunner:report_failure (test)
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
  io.stderr:write(self.diff(expected_str, actual_str))
  io.stderr:write('\n')
end

function TestRunner:get_doc (block)
  if block.t == 'CodeBlock' then
    local text = block.text .. '\n\n'

    if self.reader then
      return self.reader(text, block.attr)
    else
      local format = block.attributes.format or block.classes[1] or 'markdown'
      local exts = block.attributes.extensions or ''
      -- pandoc gobbles the final newline in code blocks
      return pandoc.read(text, format .. exts)
    end
  end
  return pandoc.Pandoc(block.content)
end

function TestRunner:get_actual_doc (test)
  assert(test.input, 'No input found in test file ' .. test.filepath)
  local actual = self:get_doc(test.input)
  local filters = test.options.filters
    and test.options.filters:map(utils.stringify)
    or {}
  for _, filter in ipairs(filters) do
    if filter == 'citeproc' then
      actual = utils.citeproc(actual)
    else
      -- Run the filters in a copy of the global environment,
      -- but set FORMAT to the test's target format.
      local env = copy_table(_G, 'shallow')
      env.FORMAT = test.target_format
      actual = utils.run_lua_filter(actual, filter, env)
    end
  end

  return actual
end

--- Returns the expected document and, if specified, the target format.
-- The third value indicates whether a document was found and parsed.
function TestRunner:get_expected_doc (test)
  if not test.output then
    return 'No expected output found in file ' .. test.filepath, nil, false
  end

  local output = test.output
  if output.t == 'CodeBlock' then
    local format = output.attributes.format or output.classes[1] or 'native'
    if format == 'haskell' then
      format = 'native'
    end
    local exts = output.attributes.extensions or ''
    local ok, doc = pcall(pandoc.read, output.text, format .. exts)
    return doc, format, ok
  elseif output.t == 'Div' and output.classes[1] == 'section' then
    local section_content = output.content:clone()
    section_content:remove(1)
    return pandoc.Pandoc(section_content), nil, true
  elseif output.t == 'Div' then
    return pandoc.Pandoc(output.content), nil, true
  else
    error("Don't know how to handle output block; aborting.")
  end
end

function TestRunner:run_command_test (test, accept)
  local pandoc_args = split(test.command.text)
  assert(pandoc_args:remove(1) == 'pandoc', 'Must be a pandoc command.')
  local input_str = test.input.text
  local actual = pandoc.pipe('pandoc', pandoc_args, input_str)
  local expected = test.output.text .. '\n'
  if actual == expected then
    return true
  elseif accept then
    test.actual   = actual
    test.expected = expected
    self:accept(test)
    return true
  else
    io.stderr:write(self.diff(expected, actual))
    io.stderr:write('\n')
    return false
  end
end

--- Run the test in the given file.
TestRunner.run_test = function (self, test, accept)
  if test.command then
    return self:run_command_test(test, accept)
  end

  local expected, format, ok = self:get_expected_doc(test, accept)
  if not accept and not ok then
    error('Could not get the expected Pandoc document:\n' .. tostring(expected))
  elseif not ok then
    expected = nil
  end
  test.target_format = format or test.target_format
  local actual   = self:get_actual_doc(test)
  local modifier_filters = List{}
  if test.options['ignore-softbreaks'] then
    modifier_filters:insert{SoftBreak = function() return pandoc.Space() end}
  end
  if test.options['metastrings-to-inlines'] then
    modifier_filters:insert(metastrings_to_inlines)
  end
  for _, modfilter in ipairs(modifier_filters) do
    actual = actual:walk(modfilter)
    expected = expected and expected:walk(modfilter)
  end

  if actual == expected then
    return true
  elseif accept then
    test.actual   = actual
    test.expected = expected
    self:accept(test)
    return true
  else
    test.actual   = actual
    test.expected = expected
    self:report_failure(test)
    return false
  end
end

--- Run all tests in a test group
function TestRunner:run_test_group (testgroup, accept)
  local success = true
  for _, test in ipairs(testgroup.tests) do
    local localtest = apply_test_options(test, testgroup.options)
    success = self:run_test(localtest, accept) and success
  end

  return success
end

------------------------------------------------------------------------
--- Group of tests with common options
local TestGroup = {
  tests = List{},
  options = {},
}
TestGroup.__index = TestGroup
TestGroup.new = function (tests, options)
  local tg = { tests = List(tests), options = options }
  return setmetatable(tg, TestGroup)
end
TestGroup.from_path = function (filepath, test_from_file)
  local is_dir, dirfiles = pcall(system.list_directory, filepath)
  local testfiles = List{}
  local optionsfile
  if not is_dir then
    testfiles:insert(filepath)
    -- look for a config on the same level
    local optionsfp = path.join{path.directory(filepath), 'perevir.yaml'}
    optionsfile = file_exists(optionsfp) and optionsfp or nil
  else
    local add_dir = function(p) return path.join{filepath, p} end
    for _, fp in ipairs(dirfiles) do
      if fp == 'perevir.yaml' then
        optionsfile = add_dir(fp)
      else
        testfiles:insert(add_dir(fp))
      end
    end
  end

  local options = optionsfile
    and pandoc.read(read_file(optionsfile)).meta
    or {}
  return TestGroup.new(testfiles:map(test_from_file), options)
end

------------------------------------------------------------------------
--- Complete tester object.
local Pereviryalnyk = {}
Pereviryalnyk.__index = Pereviryalnyk
Pereviryalnyk.accept = false
Pereviryalnyk.format = 'markdown'
Pereviryalnyk.runner = TestRunner.new()
Pereviryalnyk.test_parser = TestParser.new()
Pereviryalnyk.new = function (opts)
  local pereviryalnyk = {}
  pereviryalnyk.accept = opts.accept
  pereviryalnyk.runner = opts.runner
  pereviryalnyk.test_parser = opts.test_parser
  return setmetatable(pereviryalnyk, Pereviryalnyk)
end

function Pereviryalnyk:test_file (filepath)
  assert(filepath, "test file required")
  local test = self.test_parser:create_test(filepath)
  return self.runner:run_test(test, self.accept)
end

function Pereviryalnyk:test_files_in_dir (filepath)
  local test_from_file = function (fp)
    return self.test_parser:create_test(fp)
  end
  local testgroup = TestGroup.from_path(filepath, test_from_file)
  local success = self.runner:run_test_group(testgroup, self.accept)

  os.exit(success and 0 or 1)
end

--- Perform tests on the files given in `opts.path`.
function M.do_checks(opts)
  local pereviryalnyk = Pereviryalnyk.new {
    runner = opts.runner or TestRunner.new(),
    accept = opts.accept,
    format = opts.format,
    test_parser = TestParser.new { format = opts.format },
  }
  return pereviryalnyk:test_files_in_dir(opts.path)
end

M.Pereviryalnyk = Pereviryalnyk
M.Tester = Pereviryalnyk
M.TestParser = TestParser
M.TestRunner = TestRunner

-- Run the default tests when the file is called as a script.
if not pcall(debug.getlocal, 4, 1) then
  local opts = M.parse_args(arg)
  M.do_checks(opts)
end

return M
