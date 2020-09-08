# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Net-Z3950-FOLIO.t'

### From discussion with Wayne:
#
# Soon I will write tests for the FOLIO Z39.50 server, verifying that
# the pipeline (JSON records merged into one, converted to XML,
# transformed via XSLT to MARCXML, rendered as ISO2709 records)
# continues to give the expected results. The most convenient way to
# do this would be by fetching well-known records from a reliable
# FOLIO service. Does such a service exist, and what is the best way
# to find the well-known records?
#
# What about using records that are in the inventory-storage
# schema(s)? Like in
# https://github.com/folio-org/mod-inventory-storage/tree/master/sample-data/instances

use strict;
use warnings;
use IO::File;
use MARC::Record;
use Cpanel::JSON::XS qw(decode_json);
use Test::More tests => 3;
BEGIN { use_ok('Net::Z3950::FOLIO') };
use Net::Z3950::FOLIO::OPACXMLRecord;

# Values taken from some random USMARC record
my $dummyMarc = new MARC::Record();
$dummyMarc->leader('03101cam a2200505Ii 4500');
$dummyMarc->append_fields(new MARC::Field('007', 'cr cnu---unuuu'));
$dummyMarc->append_fields(new MARC::Field('008', '1234567890123456789012345678901'));

for (my $i = 1; $i <= 2; $i++) {
    my $expected = readFile("t/data/expectedOutput$i.xml");
    my $folioJson = readFile("t/data/input$i.json");
    my $folioHoldings = decode_json($folioJson);
    my $holdingsXml = Net::Z3950::FOLIO::OPACXMLRecord::_makeSingleHoldingsRecord($folioHoldings, $dummyMarc);
    is($holdingsXml, $expected, "generated holdings $i match expected XML");
}


sub readFile {
    my($fileName) = @_;

    my $fh = IO::File->new();
    $fh->open("<$fileName") or die "can't read '$fileName': $!";
    my $data = join('', <$fh>);
    $fh->close();
    return $data;
}
