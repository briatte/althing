This repository contains code to build cosponsorship networks from bills passed in the [Icelandic Parliament](http://www.althingi.is/).

- [interactive demo](http://briatte.org/althing)
- [static plots](http://briatte.org/althing/plots.html)

# HOWTO

Replicate by running `make.r` in R.

The `data.r` script downloads information on bills and sponsors. Due to [what looks like a bug](https://github.com/hadley/httr/issues/112) in the `httr` package, the download loop for bills is likely to fail after a thousand iterations or so. Re-run as many times as needed.

The `build.r` script then assembles the edge lists and plots the networks, with the help of a few routines coded into `functions.r`. Adjust the `plot`, `gexf` and `mode` parameters to skip the plots or to change the node placement algorithm.

# DATA

## Bills

- `session` -- parliamentary session number (int)
- `legislature` -- legislature id
- `ref` -- bill id (int)
- `date` -- date (yyyy-mm-dd)
- `name` -- title
- `url` -- URL
- `author` -- first author
- `authors` -- URL to sponsors list
- `text` -- sponsors list
- `sponsors` -- semicolon-separated integer ids of sponsors
- `ministry` -- is the bill authored by the executive (logical)
- `n_au` -- total number of sponsors

## Sponsors

- `url` -- profile URL, shortened to numeric id
- `name` -- name (duplicates solved by numbering them)
- `born` -- year of birth (int)
- `photo` -- photo URL, shortened to filename number
- `party` -- main party affiliation (with some transitions ignored), abbreviated
- `partyname` -- main party affiliation (with some transitions ignored), full name
- `sex` -- gender (F/M), imputed from first and family names
- `mandate` -- semicolon-separated mandate years, used to compute the `nyears` seniority variable

Note -- "SAMF" regroups the four parties that created the Social-Democratic Alliance in 1999.
