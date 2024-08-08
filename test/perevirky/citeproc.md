---
perevir:
  filters:
  - citeproc
---

# Citeproc filter

This tests the *citeproc* processor built into pandoc.

``` markdown {#input}
---
references:
- id: Upper_1974
  type: article-journal
  author: [{family: Upper, given: Dennis}]
  issued: {year: 1974}
  title: The unsuccessful self-treatment of a case of “writer’s block”
  container-title: Journal of Applied Behavior Analysis
  publisher: Blackwell Publishing Ltd
  page: 497-497
  volume: '7'
  issue: '3'
  URL: 'http://dx.doi.org/10.1901/jaba.1974.7-497a'
  DOI: 10.1901/jaba.1974.7-497a
  ISSN: 1938-3703
---

The paper of @Upper_1974 will never not be relevant.
```

This test is a bit fragile as it depends on the details of the
*citeproc* processor.

``` haskell {#output}
Pandoc
  Meta
    { unMeta =
        fromList
          [ ( "references"
            , MetaList
                [ MetaMap
                    (fromList
                       [ ( "DOI"
                         , MetaInlines
                             [ Str "10.1901/jaba.1974.7-497a" ]
                         )
                       , ( "ISSN" , MetaInlines [ Str "1938-3703" ] )
                       , ( "URL"
                         , MetaInlines
                             [ Str
                                 "http://dx.doi.org/10.1901/jaba.1974.7-497a"
                             ]
                         )
                       , ( "author"
                         , MetaList
                             [ MetaMap
                                 (fromList
                                    [ ( "family"
                                      , MetaInlines [ Str "Upper" ]
                                      )
                                    , ( "given"
                                      , MetaInlines [ Str "Dennis" ]
                                      )
                                    ])
                             ]
                         )
                       , ( "container-title"
                         , MetaInlines
                             [ Str "Journal"
                             , Space
                             , Str "of"
                             , Space
                             , Str "Applied"
                             , Space
                             , Str "Behavior"
                             , Space
                             , Str "Analysis"
                             ]
                         )
                       , ( "id" , MetaInlines [ Str "Upper_1974" ] )
                       , ( "issue" , MetaInlines [ Str "3" ] )
                       , ( "issued"
                         , MetaMap
                             (fromList
                                [ ( "year"
                                  , MetaInlines [ Str "1974" ]
                                  )
                                ])
                         )
                       , ( "page" , MetaInlines [ Str "497-497" ] )
                       , ( "publisher"
                         , MetaInlines
                             [ Str "Blackwell"
                             , Space
                             , Str "Publishing"
                             , Space
                             , Str "Ltd"
                             ]
                         )
                       , ( "title"
                         , MetaInlines
                             [ Str "The"
                             , Space
                             , Str "unsuccessful"
                             , Space
                             , Str "self-treatment"
                             , Space
                             , Str "of"
                             , Space
                             , Str "a"
                             , Space
                             , Str "case"
                             , Space
                             , Str "of"
                             , Space
                             , Quoted
                                 DoubleQuote
                                 [ Str "writer\8217s"
                                 , Space
                                 , Str "block"
                                 ]
                             ]
                         )
                       , ( "type"
                         , MetaInlines [ Str "article-journal" ]
                         )
                       , ( "volume" , MetaInlines [ Str "7" ] )
                       ])
                ]
            )
          ]
    }
  [ Para
      [ Str "The"
      , Space
      , Str "paper"
      , Space
      , Str "of"
      , Space
      , Cite
          [ Citation
              { citationId = "Upper_1974"
              , citationPrefix = []
              , citationSuffix = []
              , citationMode = AuthorInText
              , citationNoteNum = 1
              , citationHash = 0
              }
          ]
          [ Str "Upper" , Space , Str "(1974)" ]
      , Space
      , Str "will"
      , Space
      , Str "never"
      , Space
      , Str "not"
      , Space
      , Str "be"
      , Space
      , Str "relevant."
      ]
  , Div
      ( "refs"
      , [ "references" , "csl-bib-body" , "hanging-indent" ]
      , [ ( "entry-spacing" , "0" ) ]
      )
      [ Div
          ( "ref-Upper_1974" , [ "csl-entry" ] , [] )
          [ Para
              [ Str "Upper,"
              , Space
              , Str "Dennis."
              , Space
              , Str "1974."
              , Space
              , Span
                  ( "" , [] , [] )
                  [ Str "\8220"
                  , Str "The"
                  , Space
                  , Str "Unsuccessful"
                  , Space
                  , Str "Self-Treatment"
                  , Space
                  , Str "of"
                  , Space
                  , Str "a"
                  , Space
                  , Str "Case"
                  , Space
                  , Str "of"
                  , Space
                  , Span
                      ( "" , [] , [] )
                      [ Str "\8216"
                      , Str "Writer\8217s"
                      , Space
                      , Str "Block"
                      , Str "\8217"
                      ]
                  , Str "."
                  , Str "\8221"
                  ]
              , Space
              , Emph
                  [ Str "Journal"
                  , Space
                  , Str "of"
                  , Space
                  , Str "Applied"
                  , Space
                  , Str "Behavior"
                  , Space
                  , Str "Analysis"
                  ]
              , Space
              , Str "7"
              , Space
              , Str "(3):"
              , Space
              , Str "497\8211\&97."
              , Space
              , Link
                  ( "" , [] , [] )
                  [ Str "https://doi.org/10.1901/jaba.1974.7-497a" ]
                  ( "https://doi.org/10.1901/jaba.1974.7-497a" , "" )
              , Str "."
              ]
          ]
      ]
  ]
```
