package Net::Z3950::FOLIO::Record;

use strict;
use warnings;

use Scalar::Util qw(blessed reftype);
use XML::Simple;

use Net::Z3950::FOLIO::HoldingsRecords qw(makeHoldingsRecords);
use Net::Z3950::FOLIO::MARCHoldings qw(insertMARCHoldings);
use Net::Z3950::FOLIO::PostProcess qw(postProcessMARCRecord);


sub new {
    my $class = shift();
    my($rs, $offset, $json) = @_;

    return bless {
	rs => $rs, # back-reference
	offset => $offset, # within rs
	json => $json,
	holdingsStructure => undef,
    }, $class;
}

sub id {
    my $this = shift();
    my $id = $this->{json}->{id};
    return $id;
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

sub holdings {
    my $this = shift();
    my($marc) = @_;

    if (!$this->{holdingsStructure}) {
	$this->{holdingsStructure} = makeHoldingsRecords($this, $marc);
    }

    return $this->{holdingsStructure};
}

sub marc_record {
    my $this = shift();
    my $instanceId = $this->id();
    my $rs = $this->{rs};
    my $session = $rs->session();
    my $marc = $rs->marcRecord($instanceId);

    if (!defined $marc) {
	# Fetch a chunk of records that contains the requested one.
	# contains the requested record.
	my $index0 = $this->{offset};
	my $chunkSize = $session->{cfg}->{chunkSize} || 10;
	my $chunk = int($index0 / $chunkSize);
	$session->_insert_records_from_SRS($rs, $chunk * $chunkSize, $chunkSize);
	$marc = $rs->marcRecord($instanceId);
	_throw(1, "missing MARC record") if !defined $marc;
    }

    if (!$rs->processed($instanceId)) {
	insertMARCHoldings($this, $marc, $session->{cfg}, $rs->barcode());
	$marc = postProcessMARCRecord(($session->{cfg}->{postProcessing} || {})->{marc}, $marc);
	$rs->insert_marcRecords({ $instanceId, $marc }); # XXX this is clumsy
	$rs->setProcessed($instanceId);
    }

    return $marc;
}


# ----------------------------------------------------------------------------

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
