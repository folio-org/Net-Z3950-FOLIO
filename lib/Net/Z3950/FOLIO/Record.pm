package Net::Z3950::FOLIO::Record;

use strict;
use warnings;

use Scalar::Util qw(blessed reftype);
use XML::Simple;


sub new {
    my $class = shift();
    my($json) = @_;

    return bless {
	json => $json,
    }, $class;
}

sub id {
    my $this = shift();
    return $this->{json}->{id};
}

sub jsonStructure {
    my $this = shift();
    return $this->{json};
}

sub prettyJSON {
    my $this = shift();
    return _format_json($this->{json});
}

sub prettyXML {
    my $this = shift();
    return _format_xml($this->{json});
}


sub _format_json {
    my($obj) = @_;

    my $coder = Cpanel::JSON::XS->new->ascii->pretty->allow_blessed->space_before(0)->indent_length(2)->sort_by;
    return $coder->encode($obj);
}

sub _format_xml {
    my($json) = @_;

    my $xml;
    {
	# Sanitize output to remove JSON::PP::Boolean values, which XMLout can't handle
	_sanitize_tree($json);

	# I have no idea why this generates an "uninitialized value" warning
	local $SIG{__WARN__} = sub {};
	$xml = XMLout($json, NoAttr => 1);
    }
    $xml =~ s/<@/<__/;
    $xml =~ s/<\/@/<\/__/;
    return $xml;
}

# This code modified from https://www.perlmonks.org/?node_id=773738
sub _sanitize_tree {
    for my $node (@_) {
	if (!defined($node)) {
	    next;
	} elsif (ref($node) eq 'JSON::PP::Boolean') {
            $node += 0;
        } elsif (blessed($node)) {
            die('_sanitize_tree: unexpected object');
        } elsif (reftype($node)) {
            if (ref($node) eq 'ARRAY') {
                _sanitize_tree(@$node);
            } elsif (ref($node) eq 'HASH') {
                _sanitize_tree(values(%$node));
            } else {
                die('_sanitize_tree: unexpected reference type');
            }
        }
    }
}



1;
