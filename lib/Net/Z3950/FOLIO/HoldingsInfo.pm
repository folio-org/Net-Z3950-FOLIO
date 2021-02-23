package Net::Z3950::FOLIO::HoldingsInfo;

use strict;
use warnings;

use Net::Z3950::FOLIO::OPACXMLRecord;


sub insertHoldingsInfo {
    my($ihi, $marc, $cfg) = @_;
    my $marcCfg = $cfg->{marcHoldings} || {};
    my $holdingsObjects = Net::Z3950::FOLIO::OPACXMLRecord::_makeHoldingsRecords($ihi->{holdingsRecords2}, $marc);

    for (my $i = 0; $i < @$holdingsObjects; $i++) {
	my $holdingsObject = $holdingsObjects->[$i];
	my $marcField; # Annoyingly, this can't be created with no subfields

	for (my $j = 0; $j < @$holdingsObject; $j++) {
	    my $keyVal = $holdingsObject->[$j];
	    my($key, $val) = @$keyVal;

	    my $target = $marcCfg->{elements}->{$key};
	    if ($target) {
		if ($marcField) {
		    $marcField->add_subfields($target, $val);
		} else {
		    # Delayed creation
		    $marcField = MARC::Field->new($marcCfg->{field}, @{ $marcCfg->{indicators}}, $target, $val);
		}
	    }
	}

	$marc->append_fields($marcField) if $marcField;
    }
}


use Exporter qw(import);
our @EXPORT_OK = qw(insertHoldingsInfo);


1;
