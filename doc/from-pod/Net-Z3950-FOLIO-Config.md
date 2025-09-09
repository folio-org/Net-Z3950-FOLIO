# NAME

Net::Z3950::FOLIO::Config - configuration file for the FOLIO Z39.50 gateway

# SYNOPSIS

    {
      "okapi": {
        "url": "https://folio-snapshot-okapi.dev.folio.org",
        "tenant": "${OKAPI_TENANT-indexdata}"
      },
      "login": {
        "username": "diku_admin",
        "password": "${OKAPI_PASSWORD}"
      },
      "indexMap": {
        "1": "author",
        "7": "identifiers/@value/@identifierTypeId=\"8261054f-be78-422d-bd51-4ed9f33c3422\"",
        "4": "title",
        "12": {
          "cql": "hrid",
          "relation": "==",
          "omitSortIndexModifiers": [ "missing", "case" ]
        },
        "21": "subject",
        "1016": "author,title,hrid,subject"
      },
      "queryFilter": "source=marc",
      "graphqlQuery": "instances.graphql-query",
      "chunkSize": 5,
      "fieldDefinitions": {
        "circulation": {
          "availableThru": "permanentLoanType"
        }
      },
      "marcHoldings": {
        "restrictToItem": 0,
        "field": "952",
        "indicators": [" ", " "],
        "holdingsElements": {
          "t": "copyNumber"
        },
        "itemElements": {
          "b": "itemId",
          "k": "_callNumberPrefix",
          "h": "_callNumber",
          "m": "_callNumberSuffix",
          "v": "_volume",
          "e": "_enumeration",
          "y": "_yearCaption",
          "c": "_chronology"
        }
      },
      "postProcessing": {
        "marc": {
          "008": { "op": "regsub", "pattern": "([13579])", "replacement": "[$1]", "flags": "g" },
          "245$a": [
            { "op": "stripDiacritics" },
            { "op": "regsub", "pattern": "[abc]", "replacement": "*", "flags": "g" }
          ]
        },
        "opac": {
          "holding": {
            "callNumber": {
              "op": "regsub",
              "pattern": "(.*)",
              "replacement": "%{_callNumberPrefix}$1%{_callNumberSuffix}"
            }
          }
        }
      },
      "xmlElementSets": {
        "testmarc": "xslt/folio2marcxml.xsl",
        "testopac": "xslt/folio2opac.xsl"
      }
    }

# DESCRIPTION

The FOLIO Z39.50 gateway `z2folio` is configured by a stacking set of
JSON files whose basename is specified on the command-line. These
files specify how to connect to FOLIO, how to log in, and how to
search.

The structure of each of these file is the same, and the mechanism by
which they are stacked is described below. The shared format is
simple. There are several top-level sections, each described in its own
section below, and each of them is an object with several keys that can
exist in it.

If any string value contains sequences of the form `${NAME}`, they
are each replaced by the values of the corresponding environment
variables `$NAME`, providing a mechanism for injecting values into
the configuration. This is useful if, for example, it is necessary to
avoid embedding authentication secrets in the configuration file.

When substituting environment variables, the bash-like fallback syntax
`${NAME-VALUE}` is recognised. This evaluates to the value of the
environment variable `$NAME` when defined, falling back to the
constant value `VALUE` otherwise. In this way, the configuration can
include default values which may be overridden with environment
variables.

## `okapi`

Contains three elements (two mandatory, one optional), all with string values:

- `url`

    The full URL to the Okapi server that provides the gateway to the
    FOLIO installation.

- `graphqlUrl` (optional)

    Usually, the main Okapi URL is used for all interaction with FOLIO:
    logging in, searching, retrieving records, etc. When the optional
    `graphqlUrl` configuration entry is provided, it is used for GraphQL
    queries only. This provides a way of "side-loading" mod-graphql, which
    is useful in at least two situations: when the FOLIO snapshot services
    are unavailable (since the production services do not presently
    included mod-graphql); and when you need to run against a development
    version of mod-graphql so you can make changes to its behaviour.

- `tenant`

    The name of the tenant within that FOLIO installation whose inventory
    model should be queried.

## `login`

Contains two elements, both with string values:

- `username`

    The name of the user to log in as, unless overridden by authentication information in the Z39.50 init request.

- `password`

    The corresponding password, unless overridden by authentication information in the Z39.50 init request.

## `nologin`

If specified and set to 1, then no login is performed, and the
`login` section need not be provided.

## `indexMap`

Contains any number of elements. The keys are the numbers of BIB-1 use
attributes, and the corresponding values contain instructions about
the indexes in the FOLIO instance record to map those access-points
to. The key `default` is special, and is used for terms where no BIB-1
use attribute is specified.

Each value may be either a string, in which case it is interpreted as
a CQL index to map to (see below for details), or an object. When the
object version is used, that object's `cql` member contains the CQL
index mapping (see below), and any of the following additional members
may also be included:

- `omitSortIndexModifiers`

    A bug in FOLIO's CQL query interpreter means that for some indexes,
    query translation will fail if a sort-specification is provided that
    requests certain valid behaviours, e.g. a case-sensitive search on the
    HRID index. To work around this until it's fixed, an index's
    `omitSortIndexModifiers` allows you to specify a list of the
    index-modifier types that they do not support, so that the server can
    omit those qualifiers when creating sort-specifications. The valid
    index-modifier types are `missing`, `relation` and `case`.

- `relation`

    If specified, the value is the relation that should be used instead of
    `=` by default when searching in this index. This is useful mostly
    for defaulting to the strict-equality relation `==` for indexes whose
    values are atomic, such as identifiers.

Each `cql` value (or string value when the object form is not used)
may be a comma-separated list of multiple CQL indexes to be queried.

Each CQL index specified as a value, or as one of the comma-separated
components of a value, may contain a forward slash. If it does, then
the part before the slash is used as the actual index name, and the
part after the slash as a CQL relation modifier. For example, if the
index map contains

    "999": "foo/bar=quux"

Then a search for `@attr 1=9 thrick` will be translated to the CQL
query `foo =/bar=quux thrick`.

## `queryFilter`

If specified, this is a CQL query which is automatically `and`ed with
every query submitted by the client, so it acts as a filter allowing
through only records that satisfy it. This might be used, for example,
to specify `source=marc` to limit search result to only to those
FOLIO instance records that were translated from MARC imports.

See the section below on **Configuring filters**.

## `graphqlQuery`

The name of a file, in the same directory as the main configuration
file, which contains the text of the GraphQL query to be used to
obtain the instance, holdings and item data pertaining to the records
identified by the CQL query.

## `chunkSize`

An integer specifying how many records to fetch from FOLIO with each
search. This can be tweaked to tune performance. Setting it too low
will result in many requests with small numbers of records returned
each time; setting it too high will result in fetching and decoding
more records than are actually wanted.

## `fieldDefinitions`

An optional object specifying how the sources from which some
particular holdings fields should draw their data, overriding the
default sources.

The keys of this object specify domains in which the fields can be
found: supported domains are `holding` and `circulation`}.

Within the `holdings` domain, no fields are presently supported;
within the `circulation` domain, only the `availableThru` field is
presently supported. Support for further fields may be added as
required.

Each field within a domain is specified by its name as key, and the
corresponding value is a string specifying a path from which to fetch
the data. These strings follow the same syntax as [the get function
in JavaScript's lodash library](https://docs-lodash.com/v4/get/). It is
a dot-separate sequence of source field-names to navigate down, with
bracketed numbers indicating the selection of one element of an
array. For example, the path
`temporaryLocation.servicePoints[0].discoveryDisplayName` fetches the
`discoveryDisplayName` field from the first element of the
`servicePoints` array within the `temporaryLocation` structure. It
will work when running on data with the shape `{ temporaryLocation: {
servicePoints: [ { discoveryDisplayName: "Main" } ] } }`.

## `marcHoldings`

An optional object specifying how holdings and item-level data should
be mapped into MARC fields. It contains up to five elements:

- `restrictToItem`

    If specified and set to 1, then the item-level holding information
    included in MARC records is restricted to that which pertains to the
    barcode mentioned in the search that yielded the record, if any. If
    zero (the default), then information on all holdings and items is
    included.

- `field` (mandatory)

    A string specifying which MARC field should be used for holdings
    information. When a record contains multiple holdings, a separate
    instance of this MARC field is created for each holding.

- `indicators` (mandatory)

    An array containing two strings, each of them specifying one of the
    two indicators to be used in the MARC field that contains
    holdings. There must be exactly two elements: blank indicators can
    be specified as a single space.

    information.

- `fieldPerItem`

    If specified and set to a true value, then a separate MARC field is
    generated for each item in each holding. When this is absent or set to
    a false value (the default), one MARC field is generated for each
    holding, and multiple items within each holding are represented by
    repeating sets of subfields within that field.

    This setting makes it simpler to access information about individual
    items, at the cost of losing information about how they are grouped
    into holdings.

- `holdingsInEachItem`

    If specified and set to a true value, then holdings information is
    included in each item's MARC field.  When this is absent or set to a
    false value (the default), only the first item in a given holding
    includes the holdings fields.

    This setting makes it simpler to access all the information about any
    single item, at the cost of wasting record size and network bandwidth
    on redundant information.

- `holdingsElements`

    An object specifying MARC subfields that should be set from
    holdings-level data. The keys are the single-character names of the
    subfields, and the corresponding values are the names of
    holdings-level fields in the OPAC XML record structure.

    See `itemElements` for detail of the structure.

- `itemElements`

    An object specifying MARC subfields that should be set from item-level
    data. The keys are the single-character names of the subfields, and
    the corresponding values are the names of item-level fields in the
    OPAC XML record structure. In addition to the standard field names,
    several additional special fields are avaialable, not part of the OPAC
    Z39.50 record, assigned names that begin with underscores:

    - `_enumeration`
    - `_chronology`
    - `_callNumber`
    - `_callNumberPrefix`
    - `_callNumberSuffix`
    - `_permanentLocation`
    - `_holdingsLocation`
    - `_volume`
    - `_yearCaption`
    - `_accessionNumber`
    - `_copyNumber`
    - `_descriptionOfPieces`
    - `_discoverySuppress`
    - `_hrid`
    - `_id`
    - `_itemIdentifier`

    Since there may be multiple items in a single holding, sets of these
    fields can repeat, e.g. for a holding with two items each specifying
    data that is encoded in the `b`, `e` and `h` subfields, the field
    would take the form

        $b 46243154 $e 1994/95 v.1 $h
        $b 46243072 $e 1994/95 v.2 $h TD224.I3I58b

## `postProcessing`

Specifies sets of transformations to be applied to the values of
fields retrieved from the back-end. Two top-level keys are supported,
for post-processing of two different types of record, and they work
slightly differently:

- `marc`

    Specifies transformations to be applied to MARC records (either
    standalone or as part of OPAC records). The value is an object: keys
    are the names of simple MARC fields, such as `008`; or of complex
    field$subfield combinations, such as `245$a`. The corresponding
    values specify the transformations that should be applied to the
    values of these fields and subfields -- see below.

- `opac`

    Specifies transformations to be applied to the holdings and
    circulations parts of OPAC records. The value is an object which can
    contain either or both `holding` and `circulation` keys; the values
    corresponding to each of these keys are themselves objects which
    specify which fields within the holdings records, or their circulation
    subrecords, to transform.

    The keys within both of these subobjects are XML fieldnames, including
    both those defined for the OPAC record and the "special fields"
    beginning with underscores that are listed above in the
    `itemElements` section -- for example, `_callNumberPrefix`. The
    corresponding values specify the transformations that should be
    applied to the values of these fields and subfields -- see below.

In summary, the `marc` section lists fieldnames (both simple and
complex) directly; whereas the `opac` section contains `holding` and
`circulation` subsections which list the XML fieldnames of the two
sections separately.

Post-processing transformation specifications are the same for MARC
and OPAC records. Each value in the specification may be either a
single transformation or an array o zero or more transformations which
will be applied in the specified order.

Individual transformations are represented by objects. The fundamental
behaviour of each transformations is determined by an `op` key whose
value specifies the required operation.

The following transformation operations are supported:

- `stripDiacritics`

    All diacritics are stripped from the value in the relevant field: for
    example, `délétère` becomes `deletere`.

- `regsub`

    A regular expression substitution is performed on the value in the
    relevant field, as specified by the parameters in the transformation
    object:

    - `pattern`

        A regular expression intended to matching some part of the field
        value. This is Perl regular expression, as overviewed in
        [perlretut](https://perldoc.perl.org/perlretut)
        and fully documented in
        [perlre](https://perldoc.perl.org/perlre)
        and as such supports advanced facilities such as back-references.

    - `replacement`

        The string with which to replace the part of the field value that
        matches the pattern. This may include numbered references `$1`,
        `$2`, etc., to parenthesized sub-expressions in the pattern. (If this
        statement means nothing to you, you need to
        [go and read about regular expressions](https://perldoc.perl.org/perlretut).)

        Replacement strings may also include sequences of the form
        _%{fieldname}_, where _fieldname_ is interpreted in a manner
        appropriate for the kind of record being post-processed. For MARC
        records, _fieldname_ is either a simple control-field tag such as
        `001` or a field-and-subfield combination like `245$a`; for OPAC
        records, it is the name of an XML field from the same part of the
        record (i.e. a holdings field if substituting holdings data, and a
        circulation field if substituting circulation data).

        Such sequences cause the value of the specified field within the
        current record to be interpolated, so that for example a replacement
        string `%{001}/%{245a}` in a MARC-record substitution will cause the
        text that matches the regular expression to be replaced by the
        contents of the `001` and `245$a` fields separated by a slash.

        This mechanism yields a powerful and general facility allowing
        installations with complex requirements to generate exactly the detail
        they need. For example, it can be used to implement fallbacks, as in
        this case where if `952$2` has no value it's replaced by the value in
        `952$b`. (This could be used for situations like reporting the
        item-level copy-number if that's present, but falling back to the
        holdings-level copy-number if not.)

            "952$2": [
              { "op": "regsub", "pattern": "^$", "replacement": "%{952$b}" }
            ]

        Or a location string could be built in the `$z` subfield from
        fragments in the `$1`, `$2` and `$2` subfields:

            "952$z": [
              { "op": "regsub", "pattern": ".*", "replacement": "%{952$1}/%{952$2}/%{952$3}" }
            ]

    - `flags`

        Optionally, a set of flags such as `g` for global replacement, `i`
        for case-insensitivity, etc. See
        [Using regular expressions in Perl](https://perldoc.perl.org/perlretut#Using-regular-expressions-in-Perl).

For example, the MARC post-processing directive

      "245$a": [
        { "op": "stripDiacritics" },
        { "op": "regsub", "pattern": "[abc]", "replacement": "*", "flags": "g" }
      ]

Says first to remove all diacritics from the `245$a` (title) field of
the MARC record (so that for example `é` becomes `e`), then to
replace all vowels with asterisks.

## `xmlElementSets`

If provided, a mapping of XML element-set names to the names of XSLT 1.0 stylesheets, relative to the location of the top-level configuration file. These stylesheets must be provided as part of the broader configuration. When an XML record is requested in non-standard format (i.e. record-syntax is `xml` and element-set name is not `raw`, `usmarc` or `opac`), the raw XML record is processed using the nominated XSLT stylesheet and the reslt is returned. This facility can be used to provide clients with, for example, MODS records.

**NOTE.** Only XSLT 1.0 is supported: not XSLT 2.0. (There seems to be no Perl module that implements XSLT 2.0.)

# CONFIGURATION STACKING

To implement both multi-tenancy and per-database output tweaks that may be required for specific Z39.50 client application, it is necessary to allow flexibility in the configuration of the server, based both on Z39.50 database name and on further specifications. Three levels of configuration are therefore supported.

1. A base configuration file is always used, and will typically provide the bulk of the configuration that is the same for all supported databases. Its base name is specified when the server is invoked -- for example, as the argument to the `-c` command-line option of `z2folio`: when the server is invoked as `z2folio -c etc/config` the base configuration file is found at `etc/config.json`.
2. The Z39.50 database name provided in a search is used as a name of a sub-configuration specific to that database. So for example, if a Z39.50 search request come in for the database `theo`, then the additional database-specific configuration file `etc/config.theo.json` is also consulted. Often this file will specify the FOLIO tenant to be used for this database.

    Values provided in a database-specific configuration are added to those of the base configuration, overriding the base values when the same item is provided at both levels.

3. One or more _filters_ may also be used to specify additional configuration. These are specified as part of the Z39.50 database name, separated from the main part of the name by pipe characters (`|`). For example, if the database name `theo|foo|bar` is used, then two additional filter-specific configuration files are also read, `etc/config.foo.json` and `etc/config.bar.json`. The values of filter-specific configurations override those of the base or database-specific configuration, and those of later filters override those of earlier filters.

In the example used here, then, a server launched with `z2folio -c etc/config` and serving a search against the Z39.50 database `theo|foo|bar` will consult four configuration files:
`etc/config.json`,
`etc/config.theo.json` (if present),
`etc/config.foo.json`
and
`etc/config.bar.json`.

This scheme allows us to handle several scenarios in a uniform way:

- Basic configuration all in one place
- Database-specific overrides, such as the FOLIO tenant and any customer-specific definition of ISBN searching (see issue ZF-24) in the database configuration, leaving the standard definition to apply to other tenants.
- Application-specific overrides, such as those needed by the ABLE client (see issue ZF-25), specified only in a filter that is not used except when explicitly requested.

# CONFIGURING FILTERS

By design, the FOLIO Z39.50 server follows [the "Mechanism, Not Policy" approach](https://wiki.c2.com/?MechanismNotPolicy): it is not opinionated about what kinds of records should be returned, how holdings should be encoded in MARC, etc. — instead, it invites institutions to configure it according to their preference.

In some cases, that preference is for suppressed-from-discovery records to be omitted. So the configuration needs to be set up accordingly. The way to do this is with the `queryFilter` configuration item, which is used to provide a query fragment that gets `and`ed with every query submitted by the client.

The configuration file could be modified to include, at the top level:

    "queryFilter": "cql.allRecords=1 NOT discoverySuppress=true"

This could be done either in the top-level configuration, in a database-specific configuration, or in a filter configuration.

When this was used this against a good-sized institution's test service, a search for "water" found 19395 records, as opposed to 39181 when the filter was not in place. Search time remained around one or two seconds.

[A more rigorous filter](https://wiki.folio.org/display/FOLIOtips/Searching) can be used:

    "queryFilter": "cql.allRecords=1 NOT discoverySuppress=true NOT holdingsItems.discoverySuppress=true NOT item.discoverySuppress=true"

But as this is more complex, it has an impact on performance — as is the case when this query is used in the Inventory app's "query search". When this was used against the same institution's test service Chicago's test service, the "water" search came down to 19395 records, but it took nearly a minute to run.

Or an intermediate version can be used that omits both suppressed instances and suppressed holdings, but not suppressed items. This got the result count down to 38791 — as one would expect, more than when only instances are suppress, but less then when items are also suppressed — and took two or three seconds.

It's up to an individual installation to decide which trade-off best suits them. This trade-off may change as FOLIO's indexing changes: for example, if an index is added that makes the omit-instances-with-suppressed-items search much faster, that may become a more attractive option.

# SEE ALSO

- The `z2folio` script conveniently launches the server.
- `Net::Z3950::FOLIO` is the library that consumes this configuration.
- The `Net::Z3950::SimpleServer` handles the Z39.50 service.

# AUTHOR

Mike Taylor, <mike@indexdata.com>

# COPYRIGHT AND LICENSE

Copyright (C) 2018-2022 The Open Library Foundation

This software is distributed under the terms of the Apache License,
Version 2.0. See the file "LICENSE" for more information.
