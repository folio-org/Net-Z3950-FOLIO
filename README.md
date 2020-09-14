# z2folio - the Z39.50-to-FOLIO gateway

Copyright (C) 2018-2020 The Open Library Foundation

This software is distributed under the terms of the Apache License,
Version 2.0. See the file "[LICENSE](LICENSE)" for more information.

## Introduction

[`z2folio`](bin/z2folio) is a Z39.50 server for FOLIO bibliographic and holdings data, supporting record retrieval in USMARC, OPAC and XML formats. The functionality is all provided by [the `Net::Z3950::FOLIO` library](lib/Net/Z3950/FOLIO.pm), which is also part of this distribution. It is written in Perl, and follows standard Perl-module conventions.

## Installation

To install this module type the following:

    perl Makefile.PL
    make
    make test
    make install

On some platforms (e.g. my MacBook running MacOS 10.13.6 with YAZ and libxml2 installed from Homebrew 1.8.4, installing the prerequisite SimpleServer with `cpan install Net::Z3950::SimpleServer` fails. I fixed it using:

    C_INCLUDE_PATH=/usr/local/Cellar/libxml2/2.9.4_3/include/libxml2 cpan install Net::Z3950::SimpleServer

## Running

If you don't want to install, you can run directly from the development checkout as:

    perl -I lib bin/z2folio -c etc/config.json -- -f etc/yazgfs.xml

## Building and running from Docker

    terminal1$ docker build -t zfolio .
    terminal1$ docker run -it --rm -p9997:9997 --name run-zfolio zfolio

    terminal2$ yaz-client @:9997
    Z> find @attr 1=4 a
    Z> format opac
    Z> show 1

## Authentication

Whichever approach to running the server you prefer, the [default configuration file](etc/config.json) specifies that the password used to authenticate onto the back-end FOLIO system must be specified in the `FOLIO_PASSWORD` environment variable. You can provide that however seems best to you -- e.g. injecting it into a Docker container -- or indeed use a different configuration file that hardwires the credentials.

## Additional information

### Other documentation

Other [modules](https://dev.folio.org/source-code/) are described,
with further FOLIO Developer documentation at [dev.folio.org](https://dev.folio.org/)

### Issue tracker

See project [ZF](https://issues.folio.org/browse/ZF)
at the [FOLIO issue tracker](https://dev.folio.org/guidelines/issue-tracker).

