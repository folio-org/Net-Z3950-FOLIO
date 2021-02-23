package Net::Z3950::FOLIO::HoldingsInfo;

use strict;
use warnings;

use Net::Z3950::FOLIO::OPACXMLRecord;


sub insertHoldingsInfo {
    my($ihi, $marc, $cfg) = @_;
    my $marcCfg = $cfg->{marcHoldings} || {};
    my $holdingsObjects = Net::Z3950::FOLIO::OPACXMLRecord::_makeHoldingsRecords($ihi->{holdingsRecords2}, $marc);

    for (my $i = 0; $i < @$holdingsObjects; $i++) {
	my $holdingsMap = _listOfPairs2map($holdingsObjects->[$i]);
	my $marcField; # Annoyingly, this can't be created with no subfields

	my $elements = $marcCfg->{elements};
	foreach my $subfield (sort keys %$elements) {
	    next if $subfield =~ /^#/;
	    my $name = $elements->{$subfield};
	    my $val = $holdingsMap->{$name};
	    # warn "considering key '$subfield' mapped to '$name' with value '$val'";
	    next if !$val;

	    if ($marcField) {
		$marcField->add_subfields($subfield, $val);
	    } else {
		# Delayed creation
		$marcField = MARC::Field->new($marcCfg->{field}, @{ $marcCfg->{indicators}}, $subfield, $val);
	    }
	}

	$marc->append_fields($marcField) if $marcField;
    }
}


sub _listOfPairs2map {
    my($listOfPairs) = @_;

    my $map;
    for (my $j = 0; $j < @$listOfPairs; $j++) {
	my $keyVal = $listOfPairs->[$j];
	my($key, $val) = @$keyVal;
	$map->{$key} = $val;
    }

    return $map;
}


use Exporter qw(import);
our @EXPORT_OK = qw(insertHoldingsInfo);


1;
