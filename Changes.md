# Revision history for Perl extension Net::Z3950::FOLIO.

## TO DO (should eventually be moved to their own GitHub tickets)
* Use Z39.50 database name to indicate FOLIO tenant. Will require delaying the authentication call from Init until the first Search, which is when we learn what the database name.
* Support returning OPAC records as well as MARC. That means getting the holdings and items, which is best done by running against mod-graphql and doing an all-in-one query.

## 0.01  Thu Dec  6 13:03:26 2018
* Original version; created by `h2xs -X --name=Net::Z3950::FOLIO --compat-version=5.8.0 --omit-constant --skip-exporter --skip-ppport`

