# Expected in div

Perevir allow to place the expected output in a `Div` element. The
content of the div is used as the content of the expected document.

The advantage of this method is that the files are much more readable
when viewed in a rendered form. Tests become more intuitive and document
modifications can become more obvious. The downside is that this cannot
be used if the format used for the *perevirky* is too lossy and if the
expected document can't be "round-tripped" through the format.

## Example

We're using a simple Org-mode paragraph as input.

``` org {#input}
This is /org-mode/ syntax. See the [[https://orgmode.org][website]]
for details.
```

The expected output is wrapped in a div. Here we also put the div
into an additional block quote to separate is from the rest of the
text. However, this isn't necessary.

> <div id="expected">
>
> This is *org-mode* syntax. See the [website](https://orgmode.org)
> for details.
>
> </div>
