# Serving MARC records from FOLIO's Source Record Storage

<!-- md2toc -l 2 using-srs.md -->
* [Introduction](#introduction)
* [Find example SRS records](#find-example-srs-records)
* [Creating example SRS records](#creating-example-srs-records)
* [Understanding the SRS WSAPI](#understanding-the-srs-wsapi)


## Introduction

FOLIO stores inventory information using its own
[`mod-inventory`](https://github.com/folio-org/mod-inventory)
module, which is a thinnish business-logic layer over the lower level
[`mod-inventory-storage`](https://github.com/folio-org/mod-inventory-storage)
module. `mod-inventory-storage` defines the FOLIO inventory formats: one each for
[instance records](https://github.com/folio-org/mod-inventory-storage/blob/master/ramls/instance.json),
[holdings records](https://github.com/folio-org/mod-inventory-storage/blob/master/ramls/holdingsrecord.json)
and
[item records](https://github.com/folio-org/mod-inventory-storage/blob/master/ramls/item.json).

However, many libraries remain wedded to [MARC records](https://en.wikipedia.org/wiki/MARC_standards), a standard from the 1960s that has comfortably outlives many of the citics who have pronounced its death over the years. FOLIO therefore provides a Source Record Storage (SRS) facility. Using this, MARC records may be uploaded to a FOLIO service. When this upload is performed using
[`mod-data-import`](https://github.com/folio-org/mod-data-import),
the records are automatically converted into instance records which are inked to the source records -- the latter being retained by the system and remaining the version of record.

The MARC format also remains important as the principal form in which [Z39.50](https://en.wikipedia.org/wiki/Z39.50) servers provide records to clients. [The FOLIO Z39.50 server](https://github.com/folio-org/Net-Z3950-FOLIO) can return XML records that are a transliteration of the JSON format for instances, but it is also required to serve MARC records -- for example, so it can provide relevant information to ILL systems.

[Issue ZF-05]https://issues.folio.org/browse/ZF-5) is to extend the Z93.50 server so that, when MARC records are requested, the server fetches the relevant records from SRS and returns them. To do this, it's necessary to locate a back-end service with sample SRS records, or create some; and to have the Z39.50 server issue requests to the SRS WSAPI. Both these steps are non-trivial.


## Finding example SRS records

It turns out that there are no SRS reference records, analogous to the reference records that are provided by `mod-inventory-storage` and which therefore turn up on each new build of reference environments such as [folio-snapshot](https://folio-snapshot.aws.indexdata.com/). That is unfortunate: such records would have been easy to work with, and to write test suites around.

There are specific servers, mostly beonging to customers, that do contain SRS records, but we cannot depend on these to remain in any given state such that tests can be reliably run against them. Similarly, bugfest environments like [bugfest-goldenrod](https://bugfest-goldenrod.folio.ebsco.com/) may contain SRS records, but their content cannot be relied upon to stay constant for tests.

As a result, it seems we have little option but to obtain a set of MARC records and insert them into a reference environment ourselves. (Or perhaps once such records exist, they could fairly easily be added as reference data to
[`mod-source-record-storage`](https://github.com/folio-org/mod-source-record-storage)
-- but that is for another day.)


XXX

My understanding is that when you insert a record into SRS, the corresponding inventory record is also automatically mapped and inserted.
New

Wayne Schneider  16:57
Well, not exactly. That is true if you use mod-data-import...but mod-source-record-storage is just a dumb store with its own API.




## Creating example SRS records

XXX


## Understanding the data import APIs

The WSAPI of `mod-source-record-storage` has [documentation generated automatically](https://dev.folio.org/reference/api/#mod-source-record-storage) from its RAML and JSON files, like all RMB-based modules. However, there is no high-level overview documentation, and in its absence it is difficult to understand how the pieces fit together. The module provides six separate RAML files and there is no obvious guidance on when, for example, one would prefer the APIs provided by `source-record-storage-records` over those provided by `source-record-storage-source-records`.

To make matters more confusing, there is also a [`mod-source-record-manager`](https://github.com/folio-org/mod-source-record-manager/)
module which _presumably_ implements a higher-level "business logic" interface over `mod-source-record-storage`. It provides [four RAML files of its own](https://dev.folio.org/reference/api/#mod-source-record-manager) and a complex API that involves JobExecutions, jobProfileInfos, sourceTypes, RawRecordsDTos and other such exotica. Thankfully there is [some documentation for this](https://github.com/folio-org/mod-source-record-manager/#data-import-workflow), but it assumes quite a bit of pre-existing knowledge.

Above this is yet another layer,
[`mod-data-import`](https://github.com/folio-org/mod-data-import/),
which may or may not also use
[`mod-data-import-converter-storage`](https://github.com/folio-org/mod-data-import-converter-storage/)
and/or
[`mod-data-loader`](https://github.com/folio-org/mod-data-loader/).
Documentation of these modules is variable in quality, and I have not been able to find any high-level documentation explaining how they all fit together (though that does not mean that no such document exists).

