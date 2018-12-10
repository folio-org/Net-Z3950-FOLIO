# z2folio

Copyright (C) 2018 The Open Library Foundation

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

