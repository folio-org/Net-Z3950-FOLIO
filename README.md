# z2folio - the Z39.50-to-FOLIO gateway

Copyright (C) 2018-2020 The Open Library Foundation

This software is distributed under the terms of the Apache License,
Version 2.0. See the file "[LICENSE](LICENSE)" for more information.

## Introduction

A Z39.50 server for FOLIO bibliographic data.

## Installation

To install this module type the following:

    perl Makefile.PL
    make
    make test
    make install

On some platforms (e.g. my MacBook running MacOS 10.13.6 with YAZ and libxml2 installed from Homebrew 1.8.4, installing the prerequisite SimpleServer with `cpan install Net::Z3950::SimpleServer` fails. I fixed it using:

    C_INCLUDE_PATH=/usr/local/Cellar/libxml2/2.9.4_3/include/libxml2 cpan install Net::Z3950::SimpleServer

## Running

If you don't want to install, you can run from the development checkout as:

    perl -I lib bin/z2folio -c etc/config.json -- -f etc/yazgfs.xml

## Additional information

### Other documentation

Other [modules](https://dev.folio.org/source-code/) are described,
with further FOLIO Developer documentation at [dev.folio.org](https://dev.folio.org/)

### Issue tracker

See project [ZF](https://issues.folio.org/browse/ZF)
at the [FOLIO issue tracker](https://dev.folio.org/guidelines/issue-tracker).

