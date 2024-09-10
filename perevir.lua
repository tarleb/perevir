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

--- Stringify an output value.
local function stringify_output (doc, format, exts)
  local doctype = ptype(doc)
  if doctype == 'string' then
    return doc
  elseif doctype == 'Pandoc' then
    local writer_opts = {}
    if next(doc.meta) then
      -- has metadata, use template
      writer_opts.template = pandoc.template.default(format)
    end

    return pandoc.write(doc, format .. exts, writer_opts)
  else
    error("Don't know how to stringify type " .. doctype)
  end
end


------------------------------------------------------------------------
--- Test
local Test = {
  filepath = false,            -- path to the test file
  doc      = pandoc.Pandoc{},  -- the full test document (Pandoc)
  options  = {},               -- test options
  input    = pandoc.Div{},     -- input code block or div
  output   = false,            -- expected output in CodeBlock or Div
  command  = false,            -- specific command to run on the input
  target_format = 'native',    -- the FORMAT value passed to filters
  target_extensions = '',      -- the format extensions used for the output
}
Test.__index = Test
Test.__newindex = function (_, k, _)
  error('Tryping to set the unknown field ' .. k .. ' on a Test object')
end

--- Get the format of the expected output.
local function get_expected_format(out)
  local default = 'native'
  if not out or out.t ~= 'CodeBlock' then
    return default, ''
  else
    local format = out.attributes.format or out.classes[1] or default
    -- Using `haskell` as the highlighting language for native output
    -- is so common that it makes sense to handle it as a special case.
    return format == 'haskell' and 'native' or format,
      out.attributes.extensions or ''
  end
end

--- Create a new Test.
function Test.new (args)
  local test = {}
  for key in pairs(Test) do
    test[key] = args[key]
  end
  local format, exts = get_expected_format(test.output)
  test.target_format = test.target_format or format
  test.target_extension = test.target_extensions or exts
  setmetatable(test, Test)
  -- Quick sanity check
  if not test.options.disable then
    assert(test.input,
           'No input found in test ' .. test.filepath or '<unnamed>')
  end
  return test
end

------------------------------------------------------------------------
--- Checks for Block properties
local BlockProperty = {
  --- Checks whether a pandoc Block element contains the expected output.
  is_output = function (block)
    return block.identifier
      and block.identifier:match '^out'
      or block.identifier == 'expected'
  end,

  --- Checks whether a pandoc Block element contains the input.
  is_input = function (block)
    return block.identifier
      and block.identifier:match'^input$'
      or block.identifier:match'^in$'
  end,

  --- Checks whether a pandoc block is a command block
  is_command = function (block)
    return block.identifier
      and block.identifier:match '^command$'
  end,
}

------------------------------------------------------------------------
--- A test embedded in a pandoc document.
local Perevirka = {
  filepath = false,
  --- The full document
  doc = pandoc.Pandoc{},
  --- Format in which the document is written to file.
  format = 'markdown-fenced_divs-simple_tables',
  syntax_modifiers = mod_syntax
}
Perevirka.__index = Perevirka
Perevirka.new = function (filepath, doc, format)
  local perevirka = {filepath = filepath, doc = doc, format = format}
  return setmetatable(perevirka, Perevirka)
end

--- Update the expected output in the document.
function Perevirka:update_expected (expected_output, format, exts)
  local found_outblock = false
  local newdoc = self.doc:walk{
    CodeBlock = function (cb)
      if BlockProperty.is_output(cb) then
        found_outblock = true
        cb.text = stringify_output(expected_output, format, exts)
        return cb
      end
    end,
    Div = function (div)
      if BlockProperty.is_output(div) then
        found_outblock = true
        div.content = expected_output.blocks
        return div
      end
    end
  }
  if found_outblock then
    self.doc = newdoc
  else
    local docstring = stringify_output(expected_output, format, exts)
    self.doc.blocks:insert(pandoc.CodeBlock(docstring, {'expected'}))
  end
end

--- Write the perevirka back to file.
function Perevirka:write ()
  --- Writer options to use when writing the document.
  local writer_opts = pandoc.WriterOptions{
    wrap_text = 'preserve',
    template = template.default 'markdown',
  }
  local content = pandoc.write(
    self.doc:walk(mod_syntax),
    self.format,
    writer_opts
  )
  local fh = io.open(self.filepath, 'w')
  fh:write(content)
  fh:close()
end

------------------------------------------------------------------------
--- Create Test objects from perevirky files.
local TestParser = {}
TestParser.__index = TestParser

-- Creates a new TestParser object..
function TestParser.new (opts)
  opts = opts or {}
  local newtp = {
    format    = opts.format,
    reader    = opts.reader,
  }
  return setmetatable(newtp, TestParser)
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
      if BlockProperty.is_input(cb) then
        set('input', cb)
      elseif BlockProperty.is_output(cb) then
        set('output', cb)
      elseif BlockProperty.is_command(cb) then
        set('command', cb)
      end
    end,
    Div = function (div)
      if BlockProperty.is_input(div) then
        set('input', div)
      elseif BlockProperty.is_output(div) then
        set('output', div)
      end
    end,
  }

  if blocks.input and
     blocks.input.t == 'Div' and
     blocks.input.classes[1] == 'section' then
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
  local options = doc.meta.perevir
  local input, output, command = self:get_test_blocks(doc)
  return Test.new{
    filepath = filepath,       -- path to the test file
    doc      = doc,            -- the full test document (Pandoc)
    options  = options,        -- test options
    input    = input,          -- input code block or div
    output   = output,         -- expected string output
    command  = command,        -- specific command to run on the input
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

--- map from formats to readers and writers
TestRunner.ioformats = {
  read = {
    haskell = 'native',
  },
  write = {
    haskell = 'native',
  }
}

function TestRunner.new (opts)
  opts = opts or {}
  local ioformats = opts.ioformats
  if opts.reader then
    ioformats = ioformats or {}
    -- always return the reader for unknown input formats
    ioformats.read = setmetatable(ioformats, {
        __index = function()
          return opts.reader
        end
    })
  end

  return setmetatable(
    {ioformats = ioformats},
    TestRunner
  )
end

--- Accept the actual document as correct and rewrite the test file.
function TestRunner:accept (test, actual)
  local format, exts = test.target_format, test.target_extensions
  local perevirka = Perevirka.new(test.filepath, test.doc)
  perevirka:update_expected(actual, format, exts)
  perevirka:write()
end

function TestRunner:get_reader(format)
  local reader = (self.ioformats.read or {})[format] or 'markdown'
  if type(reader) == 'function' then
    return reader
  elseif type(reader) == 'string' then
    -- use pandoc's read function
    return function (input, attr)
      local exts = attr.attributes.extensions or ''
      return pandoc.read(input, format .. exts)
    end
  else
    error('Unknown reader specifier: ' .. tostring(reader))
  end
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

function TestRunner:get_doc (block)
  if block.t == 'CodeBlock' then
    -- pandoc gobbles the final newline in code blocks
    local text = block.text .. '\n\n'
    local format = block.attributes.format or block.classes[1] or 'markdown'
    local reader = self:get_reader(format)
    return reader(text, block.attr)
  end
  return pandoc.Pandoc(block.content)
end

function TestRunner:get_actual_doc (test)
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
-- Returns nil if the perevirka does not specify the expected output.
function TestRunner:get_expected_doc (test)
  local output = test.output
  if not output then
    return nil
  elseif output.t == 'CodeBlock' then
    local format, exts = test.target_format, output.attributes.extensions
    return pandoc.read(output.text, format .. (exts or ''))
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

function TestRunner:run_command_test (test)
  local pandoc_args = split(test.command.text)
  assert(pandoc_args:remove(1) == 'pandoc', 'Must be a pandoc command.')
  local input_str = test.input.text
  local actual = pandoc.pipe('pandoc', pandoc_args, input_str)
  local expected = test.output.text .. '\n'
  return expected, actual
end

--- Run a test, but compare the string output instead of the documents.
function TestRunner:run_string_test (test, accept)
  local format, exts = test.target_format, test.target_extensions
  local expected = accept or test.output.text
  local actual = stringify_output(self:get_actual_doc(test), format, exts)
  return expected, actual
end

function TestRunner:get_expected_and_actual (test)
  local expected = self:get_expected_doc(test)
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
    expected = ptype(expected) == 'Pandoc'
      and expected:walk(modfilter)
      or expected
  end
  return expected, actual
end

--- Run the test in the given file.
TestRunner.run_test = function (self, test, accept)
  io.stdout:write(test.filepath)
  io.stdout:write(':' .. string.rep(' ', math.max(1, 55 - #test.filepath)))
  local result = nil
  local expected, actual, expected_str, actual_str
  if test.options.disable then
    -- An ignored test is neither true nor false
    result = nil
  elseif test.command then
    expected_str, actual_str = self:run_command_test(test)
    result = expected_str == actual_str
  elseif test.options.compare and
         utils.stringify(test.options.compare) == 'strings' then
    expected_str, actual_str = self:run_string_test(test, accept)
    result = expected_str == actual_str
  else
    expected, actual = self:get_expected_and_actual(test)
    result = actual == expected
    -- stringify actual and expected
    if not result then
      local opts = {}
      if next(actual.meta) or (expected and next(expected.meta)) then
        -- has metadata, use template
        opts.template = pandoc.template.default 'native'
      end
      actual_str   = pandoc.write(actual, 'native', opts)
      expected_str = expected
        and pandoc.write(expected, 'native', opts)
        or actual_str
    end
  end

  if result == true then
    io.stdout:write('OK\n')
  elseif result == nil then
    -- Disabled test
    io.stdout:write('DISABLED\n')
  elseif accept then
    self:accept(test, actual)
    io.stdout:write('ACCEPTED\n')
  else
    io.stdout:write('FAILED\n')
    io.stderr:write(self.diff(expected_str, actual_str))
    io.stderr:write('\n')
  end

  return accept and true or result
end

--- Run all tests in a test group
function TestRunner:run_test_group (testgroup, accept)
  local success = true
  for _, test in ipairs(testgroup.tests) do
    local localtest = apply_test_options(test, testgroup.options)
    success = (self:run_test(localtest, accept) ~= false) and success
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

  local options = {}
  if optionsfile then
    local yaml = read_file(optionsfile)
    -- Ensure the yaml starts and ends with YAML markers
    yaml = (not yaml:match '^%-%-%-\n') and '---\n' .. yaml or yaml
    yaml = (not yaml:match '\n%-%-%-%s*$')
      and yaml:gsub('%s*$', '\n---\n')
      or yaml
    options = pandoc.read(yaml).meta
  end
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
