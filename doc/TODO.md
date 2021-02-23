# Outstanding tasks for the FOLIO Z39.50 server


<!-- md2toc -l 2 TODO.md -->
* [Introduction](#introduction)
* [Problems](#problems)
    * [Call-number sections](#call-number-sections)
        * [Candidate solution](#candidate-solution)
    * [Choice of granular call-number fields](#choice-of-granular-call-number-fields)
        * [Candidate solution](#candidate-solution)
    * [Applying post-processing to MARC records with holdings](#applying-post-processing-to-marc-records-with-holdings)
        * [Candidate solution](#candidate-solution)
    * [How to represent multiple holdings](#how-to-represent-multiple-holdings)
        * [Candidate solution](#candidate-solution)
    * [How to represent multiple items within a holding](#how-to-represent-multiple-items-within-a-holding)
        * [Candidate solution](#candidate-solution)
    * [`marcHoldings` configuration documentions](#marcholdings-configuration-documentions)
        * [Candidate solution](#candidate-solution)



## Introduction

At the time of writing (Friday 22 February 2021), only one significant issue requires addressing: [ZF-30, Add item-specific call number and location to local field in record returned from barcode search](https://issues.folio.org/browse/ZF-30). (There is also the less specific [ZF-25, SRU output tweaks to support ABLE bindery application](https://issues.folio.org/browse/ZF-25), but that is basically an umbrella containing ZF-25.)

But this issue contains a legion of issues. By laying them out here, I hope to enable myself to think more clearly about them.



## Problems


### Call-number sections

ZF-30 calls for effective call number prefix, effective call number and effective call number suffix each to be placed in their own subfields of field 953 (k, h and m respectively), but these granular fields are not present in the OPAC-record data structure -- only an aggregated `callNumber` field, since that's what's needed for the actual OPAC record.

Granular call-number fields are in fact available in the FOLIO item schema, but at present [the GraphQL query used by the Z-server](../etc/instances.graphql-query) does not pull these in, as they have not been needed.

#### Candidate solution

To make this work, we would need to add the granular call-number fields to the query and have `OPACRecord.js` gather those fields into the structures it builds, even though it doesn't need them itself. Then the code that copies fields from that structure into the MARC record would have access to them.


### Choice of granular call-number fields

The item-record schema actually provides _two_ sets of granular call-number fields: [`itemLevelCallNumber`, `itemLevelCallNumberPrefix`, `itemLevelCallNumberSuffix` and `itemLevelCallNumberTypeId` at the top level](https://github.com/folio-org/mod-inventory-storage/blob/4e164c9c524b1fd002f1aebe50cf44dc8eb873fa/ramls/item.json#L42-L57), and [`callNumber`, `prefix`, `suffix` and `typeId` within an `effectiveCallNumberComponents` subrecord](https://github.com/folio-org/mod-inventory-storage/blob/4e164c9c524b1fd002f1aebe50cf44dc8eb873fa/ramls/item.json#L58-L85). It's not obvious which of these to use.

#### Candidate solution

Looking at the git histories of thw two approaches, it's apparent that [the top-level fields](https://github.com/folio-org/mod-inventory-storage/blame/4e164c9c524b1fd002f1aebe50cf44dc8eb873fa/ramls/item.json#L42-L57) were [added on 28 November 2018](https://github.com/folio-org/mod-inventory-storage/commit/151e82a8428e96a832f07f45e191e244196a354a) but [the `effectiveCallNumberComponents` object](https://github.com/folio-org/mod-inventory-storage/blame/4e164c9c524b1fd002f1aebe50cf44dc8eb873fa/ramls/item.json#L58-L85) was added [on 12 November 2019](https://github.com/folio-org/mod-inventory-storage/commit/e6d876a4cec831b83d5c8b58a98578d7f1592158) (and subsequently further specified by the addition of named subfields). Also, the object is called _effective) call-number, which is matches what's asked for in the Jira issue. So this is almost certainly the one to use.


### Applying post-processing to MARC records with holdings

The Z39.50 server already includes facilities for applying post-processing transformations to the fields of MARC records, and it would be appealing to apply these to the fields generated to include holdings information -- for example, if call-numbers need massaging. Unfortunately, the present code doesn't allow this, because post-processing is done deep in the MARC-record fetching code in `Session::_insert_records_from_SRS`, whereas the holdings information is inserted only higher up in the Z39.50 fetch-handler.

#### Candidate solution

There are at least two candidate solutions here: we could generate the holdings information right down inside `Session::_insert_records_from_SRS`; or we could postpone the post-processing until the high-level Z39.50 handling of the record. The former is more efficient, in that it only needs to be done once for each fetched record rather than once each time the record is fetched; but in practice it's probably rare for records to be fetched more than once, so this is not a very important consideration.


### How to represent multiple holdings

The difficulty here is that in general each instance has many holdings (and each holdings record refers to many items). But the MARC holdings specifications don't seem to directly address how this multiplicity should be represented.

#### Candidate solution

Despite having raised this in [a comment on ZF-30](https://issues.folio.org/browse/ZF-30?focusedCommentId=97524&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-97524) I don't have a good answer. One obvious solution would be to use a separate 952 field for each holding.


### How to represent multiple items within a holding

As noted above, each holdings record refers to many items. But the MARC holdings specifications don't seem to directly address how this multiplicity should be represented.

#### Candidate solution

I don't have a good answer for this yet, either. Tod Olsen, in [a comment on ZF-30](https://issues.folio.org/browse/ZF-30?focusedCommentId=97640&page=com.atlassian.jira.plugin.system.issuetabpanels:comment-tabpanel#comment-97640), has suggested "for a barcode search, only insert the item information for the item that matches the barcode in the search" -- that doesn't help in the case of searches not by barcode.

However, experiment shows that not only can a MARC record contain multiple instances of the same field, but a MARC field can contain multiple instances of subfield.

So the solution here seems to be a separate MARC field for each holding, and a repeating set of subfields for each item in that holding.


### `marcHoldings` configuration documentions

Needs to be written.

#### Candidate solution

This should be simple enough -- in `lib/Net/Z3950/FOLIO/Config.pm` -- once we're confident that the configuration format has been laid down.


