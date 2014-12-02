- [interactive demo](http://briatte.org/althing)

# HOWTO

Replicate by running `make.r` in R.

The `data.r` script downloads information on bills and sponsors. The download loops need to be run several times to solve networks errors.

Due to a bug in the `httr` package, the download loop for bills is likely to fail after a thousand iterations or so. Re-run as many times as needed.

# DATA

- The `sex` variable (gender) is imputed from first and family names.
- The `nyears` variable (mandate length) is imputed from textual information.
