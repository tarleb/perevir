perevir
=======

A tool to test pandoc document transformations.

*Perevir* aims to make tests easy to write and use, and to have
tests that can also serve as a form of documentation. Ideally,
test files should be readable and informative when viewed as
rendered Markdown on a developer platform such as GitHub, GitLab,
or Codeberg.

The name *perevir* is the transliteration of the Ukrainian word
перевір, "check (something)!"

Motivation
----------

Extensions for pandoc, for example pandoc Lua filters, should be
tested just like any other software. Perevir can read text files
with input and the expected output, and check whether the
conversion succeeded.

These extensions are often hosted on development platforms that
allow Markdown files to be viewed either as code or as rendered
documents, and offer syntax highlighting etc. Test definitions
(perevirky) should be readable on those platforms, and thus can
double as easily accessible and always up-to-date documentation.

Installation
------------

The tool is a single file and thus easy to install. Just download
`perevir.lua` and call it with `pandoc lua perevir.lua
<TESTFILE>`.

When used as a command-line program you'll need to have pandoc
installed and have a "`pandoc-lua`" symlink to pandoc in your
path.

### luarocks

An alternative installation method is via [luarocks][], the
package manager for Lua.

```sh
luarocks install --local perevir
```

In addition, it may also be necessary to run `eval "$(luarocks
path)"` to set the environment variables to the correct values.

[luarocks]: https://luarocks.org/


Usage
-----

Perevir can be used both as a command line program and as a
library to create customized checkers. The command line program
takes as argument the testfile, or a directory of test files.

    ./perevir.lua <TEST-FILE-OR-DIR>

The format for test files, called "perevirky", is described below.

Since it's often cumbersome to write (or update) expected results
by hand, this can be automated. Call `perevir.lua` with `-a` to
*accept* all transformation results as the expected output. The
file will be modified in-place.

Perevirky (test files)
----------------------

All perevirky much have two parts: *input* and *expected output*.
Each of these parts is marked by setting an appropriate element
ID: `input` for the input and `expected` or `output` for the
expected result.

The example below is a very simple test that would verify the
built-in Markdown reader, checking whether it produces the correct
"pandoc native" output.

````` markdown
``` markdown {#input}
This is *nice*!
```

The internal document representation for this Markdown is

``` haskell {#expected}
[ Para
    [ Str "This"
    , Space
    , Str "is"
    , Space
    , Emph [ Str "nice" ]
    , Str "!"
    ]
]
```
`````

Notice the IDs on the code blocks, and that there can be any kind
of explanatory text outside of the input and output blocks.

### Format specifications

How a code block is parsed into a pandoc document depends on the
classes and attributes. In general, the (markup) language
identifier is used as the name of a pandoc reader. Hence

````markdown
```html {#input}
<h1>Intro</h1>
```
````

marks that the block content must be parsed as HTML.

The `extensions` attribute can be set to fine-tune the reader as
one would on the command line. E.g., to disable the *smart*
extension when parsing the input, one might write

````markdown
``` markdown {#input extensions="-smart"}
"Yeah, right."
```
````

Perevir reads the input and output blocks into pandoc's internal
document format. The tests checking the conversion results use the
objects of that internal format, **not** the string
representation. This improves accuracy and also makes tests
more robust.

### Input and output divs

Normal (pandoc Markdown) text is generally easier and more
pleasant to read than codeblocks with markup. It is therefore
possible to use divs to set the input or expected output.

```` markdown
<div id="input">

Normal [pandoc](https://pandoc.org) Markdown
paragraph.

</div>
````

It is advisable to use HTML divs instead of pandoc's own fenced
divs syntax, as fenced divs are not supported on most development
platforms and perevirky become less readable when viewed there.
Perevir disables fenced divs when rewriting perevirky with `-a`.

### Options

Perevir can be configured by setting values below the `perevir`
metadata field. Currently only the following options are
supported:

-   `filters`: it takes a list of filters that are run on the input.

-   `ignore-softbreaks`: treat softbreaks as spaces, meaning that
    non-semantic linebreaks are ignored when comparing documents.

Example:

``` yaml
perevir:
  filters: ['citeproc', 'transmogrify.lua']
  ignore-softbreaks: true
```

This will run the `transmogrify.lua` Lua filter on the input and
will make perevir check the result against the given output.

### Command tests

Command tests allow to set a specific pandoc command that
transforms the input into the output. The command must be the
content of a code block with ID `command`.

````markdown
``` sh {#command}
pandoc --from=org --to=html --number-sections
```
````

The classes on the input and output blocks have no effect in this
case.

Command tests differ from other tests in that they compare the
expected and actual output as strings. Other tests compare the
respective pandoc documents as objects.

This kind of test is particularly useful when testing writer
features, which otherwise are difficult to check.
