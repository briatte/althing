This repository contains code to build cosponsorship networks from bills passed in the [Icelandic Parliament](http://www.althingi.is/).

- [interactive demo](http://f.briatte.org/parlviz/althing)
- [static plots](http://f.briatte.org/parlviz/althing/plots.html)
- [more countries](https://github.com/briatte/parlnet)

# HOWTO

Replicate by running `make.r` in R.

The `data.r` script downloads information on bills and sponsors. The download loop can be set to go back to 1907. By default, it stops in 1995, the first election after the constitutional reform that made the Althing a completely unicameral chamber.

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
- `n_au` -- total number of sponsors

## Sponsors

- `url` -- profile URL, shortened to numeric id
- `name` -- name (duplicates solved by numbering them)
- `born` -- year of birth (int)
- `photo` -- photo URL, shortened to filename number
- `party` -- main party affiliation (with some transitions ignored), abbreviated
- `constituency` -- sponsor constituency, stored as the string to its Wikipedia Íslenska entry
- `sex` -- gender (F/M), imputed from first and family names
- `mandate` -- semicolon-separated mandate years, used to compute the `nyears` seniority variable

Note (1) -- "SAMF" regroups the four parties that created the Social-Democratic Alliance in 1999.

Note (2) -- There are frequent transitions in constituency and party among the sponsors. These are not currently taken into account in the data: only the first constituency and party are used.
