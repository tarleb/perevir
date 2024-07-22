perevir
=======

A tool to test pandoc document transformations.

*Perevir* aims to make test easy to write and use, and to have
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
with input and the expected output, and it will check whether the
conversion succeeded.

These extensions are often hosted on development platforms that
allow to view Markdown files either as code or as rendered
documents, offering syntax highlighting etc. Test definitions
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

All perevirky much have at least two parts: *input* and *expected
output*. Each of these parts is marked by setting an appropriate
ID on an element.

E.g., input that is to be treated as Markdown input would be
defined as

````` markdown
```{#input .markdown}
This is _*nice*_!
```
`````

while the expected internal pandoc representation would be defined as

````` markdown
```{#expected .haskell}
[ Para
    [ Str "This"
    , Space
    , Str "is"
    , Space
    , Emph [ Emph [ Str "nice" ] ]
    , Str "!"
    ]
]
```
`````
