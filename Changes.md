# Revision history for Perl extension Net::Z3950::FOLIO.

## 0.01  Thu Dec  6 13:03:26 2018
* Original version; created by `h2xs -X --name=Net::Z3950::FOLIO --compat-version=5.8.0 --omit-constant --skip-exporter --skip-ppport`

## To do

* Provide module descriptor specifying dependencies (required as per edge-module conventions)
* Richer query support
* Formal release
* Determine FOLIO tenant from database name (and postpone initialisation and authentication until we know that).
* Write tests (ensuring query and record formats have not changed).
* Write a non-trivial version of `etc/folio2marcxml.xsl`.

