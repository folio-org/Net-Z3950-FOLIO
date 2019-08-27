# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Net-Z3950-FOLIO.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 1;
BEGIN { use_ok('Net::Z3950::FOLIO') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


### From discussion with Wayne:
#
# Soon I will write tests for the FOLIO Z39.50 server, verifying that
# the pipeline (JSON records merged into one, converted to XML,
# transformed via XSLT to MARCXML, rendered as ISO2709 records)
# continued to give the expected results. The most convenient way to
# do this would be by fetching well-known records from a reliable
# FOLIO service. Does such a service exist, and what is the best way
# to find the well-known records?
#
# What about using records that are in the inventory-storage
# schema(s)? Like in
# https://github.com/folio-org/mod-inventory-storage/tree/master/sample-data/instances
