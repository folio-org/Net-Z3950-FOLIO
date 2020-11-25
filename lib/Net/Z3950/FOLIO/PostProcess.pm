package Net::Z3950::FOLIO::PostProcess;

use strict;
use warnings;

use Data::Dumper;
use Unicode::Diacritic::Strip ':all';


sub postProcess {
    my($cfg, $json) = @_;

    return $json if !$cfg;

    foreach my $field (@{ $json->{fields} }) {
	# Silly data structure: each "field" is a single-element hash
	foreach my $key (keys %$field) {
	    my $val = $field->{$key};
	    if (!ref $val) {
		# Simple field
		my $rules = $cfg->{$key};
		$field->{$key} = transform($rules, $field->{$key}) if $rules;
	    } else {
		# Complex field with subfields
		foreach my $subfield (@{ $val->{subfields} }) {
		    # Silly data structure: each "subfield" is a single-element hash
		    foreach my $key2 (keys %$subfield) {
			my $rules = $cfg->{"$key\$$key2"};
			$subfield->{$key2} = transform($rules, $subfield->{$key2}) if $rules;
		    }
		}
	    }
	}
    }

    return $json;
}


sub transform {
    my($cfg, $value) = @_;

    if (ref $cfg eq 'HASH') {
	# Single transformation
	return applyRule($cfg, $value);
    } else {
	# List of transformations
	foreach my $rule (@$cfg) {
	    $value = applyRule($rule, $value);
	}
	return $value;
    }
}


sub applyRule {
    my($rule, $value) = @_;

    my $op = $rule->{op};
    if ($op eq 'stripDiacritics') {
	# It seems that the regular strip_diacritics function just plain no-ops, hence fast_strip instead
	my $result = fast_strip($value);
	warn "stripping diacritics: '$value' -> '$result'";
	return $result;
    } elsif ($op eq 'regsub') {
	warn "transforming '$value' by ", Dumper($rule);
	my $from = $rule->{from};
	my $to = $rule->{to};
	my $flags = $rule->{flags};
	### now what? See https://perlmonks.org/?node_id=11124218
	return "[$value]";
    } else {
	die "unknown post-processing op '$op'";
    }
}


use Exporter qw(import);
our @EXPORT_OK = qw(postProcess);


1;
