package Net::Z3950::FOLIO::MARCHoldings;

use strict;
use warnings;


sub insertMARCHoldings {
    my($rec, $marc, $cfg, $barcode) = @_;
    my $marcCfg = $cfg->{marcHoldings} || {};
    my $holdingsObjects = $rec->holdings($marc);

    for (my $i = 0; $i < @$holdingsObjects; $i++) {
	my $holdingsMap = _listOfPairs2map($holdingsObjects->[$i]);

	# Annoyingly, a field can't be created with no subfields, hence this "accumulator" approach
	my $marcField = _addSubfields(undef, $marcCfg, $marcCfg->{holdingsElements}, $holdingsMap);

	my $itemObjects = $holdingsMap->{circulations};
	for (my $j = 0; $j < @$itemObjects; $j++) {
	    my $itemMap = _listOfPairs2map($itemObjects->[$j]);
	    # use Data::Dumper; warn Dumper($itemMap);
	    if (!$marcCfg->{restrictToItem} || !$barcode || $itemMap->{itemId} eq $barcode) {
		$marcField = _addSubfields($marcField, $marcCfg, $marcCfg->{itemElements}, $itemMap);
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


sub _addSubfields {
    my($marcField, $marcCfg, $elementsCfg, $data) = @_;

    foreach my $subfield (sort keys %$elementsCfg) {
	next if $subfield =~ /^#/;
	my $name = $elementsCfg->{$subfield};
	my $val = $data->{$name};
	# warn "considering key '$subfield' mapped to '$name' with value '$val'";
	if ($val) {
	    $marcField = _addSubfield($marcField, $marcCfg, $subfield, $val);
	}
    }

    return $marcField;
}


sub _addSubfield {
    my($marcField, $marcCfg, $subfield, $val) = @_;

    if ($marcField) {
	$marcField->add_subfields($subfield, $val);
    } else {
	# Delayed creation
	$marcField = MARC::Field->new($marcCfg->{field}, @{ $marcCfg->{indicators}}, $subfield, $val);
    }
    return $marcField;
}


use Exporter qw(import);
our @EXPORT_OK = qw(insertMARCHoldings);


1;
