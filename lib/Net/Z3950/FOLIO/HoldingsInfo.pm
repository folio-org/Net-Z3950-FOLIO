package Net::Z3950::FOLIO::HoldingsInfo;

use strict;
use warnings;

use Net::Z3950::FOLIO::OPACXMLRecord;


sub insertHoldingsInfo {
    my($ihi, $marc, $cfg) = @_;
    my $marcCfg = $cfg->{marcHoldings} || {};
    # XXX Document the `marcHoldings` part of the configuration

    my $holdingsObjects = Net::Z3950::FOLIO::OPACXMLRecord::_makeHoldingsRecords($ihi->{holdingsRecords2}, $marc);

    for (my $i = 0; $i < @$holdingsObjects; $i++) {
	my $holdingsObject = $holdingsObjects->[$i];

	for (my $j = 0; $j < @$holdingsObject; $j++) {
	    my $keyVal = $holdingsObject->[$j];
	    my($key, $val) = @$keyVal;
	    # XXX handle circulations separately
	    my $target = $marcCfg->{$key};
	    if ($target) {
		# XXX We may need to ensure multiple subfields are within the same field instance
		insertValue($marc, $target, $val);
	    }
	}
    }
}


sub insertValue {
    my($marc, $target, $val) = @_;

    # Target should be of the from FFFII$S where
    #	FFF is the MARC ield
    #	II are the two indicators, or '_' for no indicator value
    #	S is the subfield
    # For example, 999ff$i

    my $match = ($target =~ /(...)(.)(.)\$(.)/);
    if ($match) {
	my($field, $i1, $i2, $subfield) = ($1, $2, $3, $4);
	$i1 = ' ' if $i1 eq '_';
	$i2 = ' ' if $i2 eq '_';
	my $marcField = MARC::Field->new($field, $i1, $i2, $subfield, $val);
	$marc->append_fields($marcField);
    } else {
	die "Cannot parse MARC target '$target'";
    }
}


use Exporter qw(import);
our @EXPORT_OK = qw(insertHoldingsInfo);


1;
