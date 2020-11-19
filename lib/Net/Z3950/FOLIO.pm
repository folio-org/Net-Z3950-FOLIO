package Net::Z3950::FOLIO;

use 5.008000;
use strict;
use warnings;

use Cpanel::JSON::XS qw(decode_json encode_json);
use Net::Z3950::SimpleServer;
use ZOOM; # For ZOOM::Exception
use LWP::UserAgent;
use MARC::Record;
use MARC::File::XML (BinaryEncoding => 'utf8', RecordFormat => 'USMARC');
use XML::Simple;
use Scalar::Util qw(blessed reftype);
use Data::Dumper; $Data::Dumper::Indent = 1;

use Net::Z3950::FOLIO::Session;
use Net::Z3950::FOLIO::OPACXMLRecord qw(makeOPACXMLRecord);

our $VERSION = '1.3';


sub FORMAT_USMARC { '1.2.840.10003.5.10' }
sub FORMAT_XML { '1.2.840.10003.5.109.10' }
sub FORMAT_OPAC { '1.2.840.10003.5.102' }
sub FORMAT_JSON { '1.2.840.10003.5.1000.81.3' }
sub ATTRSET_BIB1 { '1.2.840.10003.3.1' }


=head1 NAME

Net::Z3950::FOLIO - Z39.50 server for FOLIO bibliographic data

=head1 SYNOPSIS

 use Net::Z3950::FOLIO;
 $service = new Net::Z3950::FOLIO('config');
 $service->launch_server("someServer", @ARGV);

=head1 DESCRIPTION

The C<Net::Z3950::FOLIO> module provides all the application logic of
a Z39.50 server that allows searching in and retrieval from the
inventory module of FOLIO.  It is used by the C<z2folio> program, and
there is probably no good reason to make any other program to use it.

The library has only two public entry points: the C<new()> constructor
and the C<launch_server()> method.  The synopsis above shows how they
are used: a Net::Z3950::FOLIO object is created using C<new()>, then
the C<launch_server()> method is invoked on it to start the server.
(In fact, this synopsis is essentially the whole of the code of the
C<simple2zoom> program.  All the work happens inside the library.)

=head1 METHODS

=head2 new($configBase)

 $s2z = new Net::Z3950::FOLIO('config');

Creates and returns a new Net::Z3950::FOLIO object, configured according to
the JSON file C<$configFile.json> specified by the only argument.  The format of
this file is described in C<Net::Z3950::FOLIO::Config>.

=cut

sub new {
    my $class = shift();
    my($cfgbase) = @_;

    my $this = bless {
	cfgbase => $cfgbase || 'config',
	ua => new LWP::UserAgent(),
	sessions => {}, # Maps database name to session object
    }, $class;

    $this->{ua}->agent("z2folio $VERSION");
    $this->{server} = Net::Z3950::SimpleServer->new(
	GHANDLE => $this,
	INIT =>    \&_init_handler_wrapper,
	SEARCH =>  \&_search_handler_wrapper,
	FETCH =>   \&_fetch_handler_wrapper,
	DELETE =>  \&_delete_handler_wrapper,
	SORT   =>  \&_sort_handler_wrapper,
#	SCAN =>    \&_scan_handler_wrapper,
    );

    return $this;
}


sub getSession {
    my $this = shift();
    my($name) = @_;

    if (!$this->{sessions}->{$name}) {
	my $session = new Net::Z3950::FOLIO::Session($this, $name);
	$this->{sessions}->{$name} = $session;
	$session->_reload_config_file();
	$session->_login($this->{user}, $this->{pass});
    }

    return $this->{sessions}->{$name};
}    


sub _init_handler_wrapper { _eval_wrapper(\&_init_handler, @_) }
sub _search_handler_wrapper { _eval_wrapper(\&_search_handler, @_) }
sub _fetch_handler_wrapper { _eval_wrapper(\&_fetch_handler, @_) }
sub _delete_handler_wrapper { _eval_wrapper(\&_delete_handler, @_) }
sub _sort_handler_wrapper { _eval_wrapper(\&_sort_handler, @_) }


sub _eval_wrapper {
    my $coderef = shift();
    my $args = shift();

    eval {
	&$coderef($args, @_);
    }; if (ref $@ && $@->isa('ZOOM::Exception')) {
	if ($@->diagset() eq 'Bib-1') {
	    $args->{ERR_CODE} = $@->code();
	    $args->{ERR_STR} = $@->addinfo();
	} else {
	    $args->{ERR_CODE} = 100;
	    $args->{ERR_STR} = $@->message() || $@->addinfo();
	}
    } elsif ($@) {
	# Non-ZOOM exceptions may be generated by the Perl
	# interpreter, for example if we try to call a method that
	# does not exist in the relevant class.  These should be
	# considered fatal and not reported to the client.
	die $@;
    }
}


sub _init_handler {
    my($args) = @_;
    my $ghandle = $args->{GHANDLE};

    $args->{IMP_ID} = '81';
    $args->{IMP_VER} = $Net::Z3950::FOLIO::VERSION;
    $args->{IMP_NAME} = 'z2folio gateway';

    $ghandle->{user} = $args->{USER};
    $ghandle->{pass} = $args->{PASS};
    # That's all we can do until we know the database name at search time
}


sub _search_handler {
    my($args) = @_;
    my $ghandle = $args->{GHANDLE};

    my $bases = $args->{DATABASES};
    _throw(111, 1) if @$bases != 1; # Too many databases specified
    my $base = $bases->[0];

    my $session = $ghandle->getSession($base);
    $args->{HANDLE} = $session;

    if ($args->{CQL}) {
	$session->{cql} = $args->{CQL};
    } else {
	my $type1 = $args->{RPN}->{query};
	$session->{cql} = $type1->_toCQL($session, $args->{RPN}->{attributeSet});
	warn "search: translated '" . $args->{QUERY} . "' to '" . $session->{cql} . "'\n";
    }

    $session->{sortspec} = undef;
    $args->{HITS} = $session->_rerun_search($args->{SETNAME});
}


sub _fetch_handler {
    my($args) = @_;
    my $session = $args->{HANDLE};

    my $rs = $session->{resultsets}->{$args->{SETNAME}};
    _throw(30, $args->{SETNAME}) if !$rs; # Result set does not exist

    my $index1 = $args->{OFFSET};
    _throw(13, $index1) if $index1 < 1 || $index1 > $rs->total_count();

    my $rec = $rs->record($index1-1);
    if (!defined $rec) {
	# We need to fetch a chunk of records that contains the
	# requested one. We'll do this by splitting the whole set into
	# chunks of the specified size, and fetching the one that
	# contains the requested record.
	my $index0 = $index1 - 1;
	my $chunkSize = $session->{cfg}->{chunkSize} || 10;
	my $chunk = int($index0 / $chunkSize);
	$session->_do_search($rs, $chunk * $chunkSize, $chunkSize);
	$rec = $rs->record($index1-1);
	_throw(1, "missing record") if !defined $rec;
    }

    # Special case: when asking for MARC with element-set "dynamic", we generate it by XSLT
    #
    # XXX There seems to be a GFS bug in which if this code is invoked
    # with format USMARC but no element-set specified, the first
    # branch (correctly) runs, but the GFS tries to convert the MARC
    # record from MARCXML to MARC. I will raise this with Adam later.

    my $comp = $args->{COMP} || '';
    my $format = $args->{REQ_FORM};
    warn "REQ_FORM=$format, COMP=$comp\n";

    my $res;
    if ($format eq FORMAT_JSON) {
	$res = _pretty_json($rec);

    } elsif ($format eq FORMAT_XML && $comp eq 'raw') {
	# Mechanical XML translitation of the JSON response
	$res = _xml_record($rec);
    } elsif ($format eq FORMAT_XML && $comp eq 'usmarc') {
	# MARCXML made from SRS Marc record
	my $marc = $session->marc_record($rs, $index1);
	$res = $marc->as_xml_record();
    } elsif ($format eq FORMAT_XML && $comp eq 'opac') {
	# OPAC-format XML
	my $marc = $session->marc_record($rs, $index1);
	$res = makeOPACXMLRecord($rec, $marc);
    } elsif ($format eq FORMAT_XML) {
	_throw(25, "XML records available in element-sets: raw, usmarc, opac");

    } elsif ($format eq FORMAT_USMARC && (!$comp || $comp eq 'f' || $comp eq 'b')) {
	# Static USMARC from SRS
	my $marc = $session->marc_record($rs, $index1);
	$res = $marc->as_usmarc();
    } elsif ($format eq FORMAT_USMARC) {
	_throw(25, "USMARC records available in element-sets: f, b");

    } else {
	_throw(239, $format); # 239 = Record syntax not supported
    }

    $args->{RECORD} = $res;
    return;
}


sub _xml_record {
    my($rec) = @_;

    my $xml;
    {
	# Sanitize output to remove JSON::PP::Boolean values, which XMLout can't handle
	_sanitize_tree($rec);

	# I have no idea why this generates an "uninitialized value" warning
	local $SIG{__WARN__} = sub {};
	$xml = XMLout($rec, NoAttr => 1);
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


sub _delete_handler {
    my($args) = @_;
    my $session = $args->{HANDLE};

    my $setname = $args->{SETNAME};
    if ($session->{resultsets}->{$setname}) {
	$session->{resultsets}->{$setname} = undef;
    } else {
	$args->{STATUS} = 1; # failure-1: Result set did not exist
    }

    return;
}


sub _sort_handler {
    my($args) = @_;
    my $ghandle = $args->{GHANDLE};
    my $session = $args->{HANDLE};

    my $setnames = $args->{INPUT};
    _throw(230, '1') if @$setnames > 1; # Sort: too many input results
    my $setname = $setnames->[0];
    my $rs = $session->{resultsets}->{$setname};
    _throw(30, $args->{SETNAME}) if !$rs; # Result set does not exist

    my $cqlSort = $ghandle->_sortspecs2cql($args->{SEQUENCE});
    _throw(207, Dumper($args->{SEQUENCE})) if !$cqlSort; # Cannot sort according to sequence

    $session->{sortspec} = $cqlSort;
    $session->_rerun_search($args->{OUTPUT});
}


sub _sortspecs2cql {
    my $this = shift();
    my($sequence) = @_;

    my @res = ();
    foreach my $item (@$sequence) {	
	push @res, $this->_singleSortspecs2cql($item);
    }

    my $spec = join(' ', @res);
    return $spec;
}


sub _singleSortspecs2cql {
    my $this = shift();
    my($item) = @_;
    my $indexMap = $this->{cfg}->{indexMap};

    my $set = $item->{ATTRSET};
    if ($set ne Net::Z3950::FOLIO::ATTRSET_BIB1 && lc($set) ne 'bib-1') {
	# Unknown attribute set (anything except BIB-1)
	_throw(121, $set);
    }

    my @modifiers = (
	[ missing => _translateSortParam($item->{MISSING}, 213, {
	    1 => 'missingFail',
	    2 => 'missingLow',
	})],
	[ relation => _translateSortParam($item->{RELATION}, 214, {
	    0 => 'ascending',
	    1 => 'descending',
	})],
	[ case => _translateSortParam($item->{CASE}, 215, {
	    0 => 'respectCase',
	    1 => 'ignoreCase',
        })],
    );

    my($accessPoint, $cqlIndex, $entry);
    my $attrs = $item->{SORT_ATTR};
    foreach my $attr (@$attrs) {
	my $type = $attr->{ATTR_TYPE};
	_throw(237, "sort-attribute of type $type (only 1 is supported)") if defined $type && $type != 1;

	$accessPoint = $attr->{ATTR_VALUE};
	$entry = $indexMap->{$accessPoint};
	_throw(207, "undefined sort-index $accessPoint") if !defined $entry;
	if (ref $entry) {
	    $cqlIndex = $entry->{cql};
	} else {
	    $cqlIndex = $entry;
	    $entry = undef;
	}
	last;
    }

    my $res = $cqlIndex;

    my $omitList = $entry ? $entry->{omitSortIndexModifiers} : [];
    foreach my $modifier (@modifiers) {
	my($name, $value) = @$modifier;
	if (!$omitList || ! grep { $_ eq $name } @$omitList) {
	    $res .= "/sort.$value";
	} else {
	    # warn "omitting '$name' sort-modifier for access-point $accessPoint ($cqlIndex)";
	}
    };

    return $res;
}


sub _translateSortParam {
    my($zval, $diag, $map) = @_;

    my $cqlVal = $map->{$zval};
    _throw($diag, $zval) if !$cqlVal;
    return $cqlVal;
}


=head2 launch_server($label, @ARGV)

 $s2z->launch_server("someServer", @ARGV);

Launches the Net::Z3950::FOLIO server: this method never returns.  The
C<$label> string is used in logging, and the C<@ARGV> vector of
command-line arguments is interpreted by the YAZ backend server as
described at
https://software.indexdata.com/yaz/doc/server.invocation.html

=cut

sub launch_server {
    my $this = shift();
    my($label, @argv) = @_;

    return $this->{server}->launch_server($label, @argv);
}


sub _throw {
    my($code, $addinfo, $diagset) = @_;
    $diagset ||= "Bib-1";

    # HTTP body for errors is sometimes a plain string, sometimes a JSON structure
    if ($addinfo =~ /^{/) {
	my $obj = decode_json($addinfo);
	$addinfo = $obj->{errors} ? $obj->{errors}->[0]->{message} : $obj->{errorMessage};
    }

    die new ZOOM::Exception($code, undef, $addinfo, $diagset);
}


sub _pretty_json {
    my($obj) = @_;

    my $coder = Cpanel::JSON::XS->new->ascii->pretty->allow_blessed->sort_by;
    return $coder->encode($obj);
}


# The following code maps Z39.50 Type-1 queries to CQL by providing a
# _toCQL() method on each query tree node type.

package Net::Z3950::RPN::Term;

sub _throw { return Net::Z3950::FOLIO::_throw(@_); }

sub _toCQL {
    my $self = shift;
    my($session, $defaultSet) = @_;
    my $indexMap = $session->{cfg}->{indexMap};
    my($field, $relation);

    my $attrs = $self->{attributes};
    untie $attrs;

    # First we determine USE attribute
    foreach my $attr (@$attrs) {
	my $set = $attr->{attributeSet} || $defaultSet;
	if ($set ne Net::Z3950::FOLIO::ATTRSET_BIB1 &&
	    lc($set) ne 'bib-1') {
	    # Unknown attribute set (anything except BIB-1)
	    _throw(121, $set);
	}
	if ($attr->{attributeType} == 1) {
	    my $val = $attr->{attributeValue};
	    $field = _ap2index($indexMap, $val);
	    $relation = _ap2relation($indexMap, $val);
	}
    }

    if (!$field && $indexMap) {
	# No explicit access-point, fall back to default if specified
	$field = _ap2index($indexMap, 'default');
	$relation = _ap2relation($indexMap, 'default');
    }

    if ($field) {
	my @fields = split(/,/, $field);
	if (@fields > 1) {
	    return '(' . join(' or ', map { $self->_CQLTerm($_, $relation) } @fields) . ')';
	}
    }

    return $self->_CQLTerm($field, $relation);
}


sub _CQLTerm {
    my $self = shift;
    my($field, $relation) = @_;

    my($left_anchor, $right_anchor) = (0, 0);
    my($left_truncation, $right_truncation) = (0, 0);
    my $term = $self->{term};
    my $attrs = $self->{attributes};

    if (defined $field && $field =~ /(.*?)\/(.*)/) {
	$field = $1;
	$relation = "=/$2";
    }

    # Handle non-use attributes
    foreach my $attr (@$attrs) {
        my $type = $attr->{attributeType};
        my $value = $attr->{attributeValue};

        if ($type == 2) {
	    # Relation.  The following switch hard-codes information
	    # about the crrespondance between the BIB-1 attribute set
	    # and CQL context set.
	    if ($relation) {
		if ($value == 1) {
		    $relation = "<";
		} elsif ($value == 2) {
		    $relation = "<=";
		} elsif ($value == 3) {
		    $relation = "=";
		} elsif ($value == 4) {
		    $relation = ">=";
		} elsif ($value == 5) {
		    $relation = ">";
		} elsif ($value == 6) {
		    $relation = "<>";
		} elsif ($value == 100) {
		    $relation = "=/phonetic";
		} elsif ($value == 101) {
		    $relation = "=/stem";
		} elsif ($value == 102) {
		    $relation = "=/relevant";
		} else {
		    _throw(117, $value);
		}
	    }
        }

        elsif ($type == 3) { # Position
            if ($value == 1 || $value == 2) {
                $left_anchor = 1;
            } elsif ($value != 3) {
                _throw(119, $value);
            }
        }

        elsif ($type == 4) { # Structure -- we ignore it
        }

        elsif ($type == 5) { # Truncation
            if ($value == 1) {
                $right_truncation = 1;
            } elsif ($value == 2) {
                $left_truncation = 1;
            } elsif ($value == 3) {
                $right_truncation = 1;
                $left_truncation = 1;
            } elsif ($value == 101) {
		# Process # in search term
		$term =~ s/#/?/g;
            } elsif ($value == 104) {
		# Z39.58-style (CCL) truncation: #=single char, ?=multiple
		$term =~ s/\?\d?/*/g;
		$term =~ s/#/?/g;
            } elsif ($value != 100) {
                _throw(120, $value);
            }
        }

        elsif ($type == 6) { # Completeness
            if ($value == 2 || $value == 3) {
		$left_anchor = $right_anchor = 1;
	    } elsif ($value != 1) {
                _throw(122, $value);
            }
        }

        elsif ($type != 1) { # Unknown attribute type
            _throw(113, $type);
        }
    }

    $term = "*$term" if $left_truncation;
    $term = "$term*" if $right_truncation;
    $term = "^$term" if $left_anchor;
    $term = "$term^" if $right_anchor;

    $term = "\"$term\"" if $term =~ /[\s""\/=]/;

    if (defined $field && defined $relation) {
	$term = "$field $relation $term";
    } elsif (defined $field) {
	$term = "$field=$term";
    } elsif (defined $relation) {
	$term = "cql.serverChoice $relation $term";
    }

    return $term;
}


sub _ap2index {
    my($indexMap, $value) = @_;

    if (!defined $indexMap) {
	# This allows us to use string-valued attributes when no indexes are defined.
	return $value;
    }

    my $field = $indexMap->{$value};
    _throw(114, $value) if !defined $field;
    return $field->{cql} if ref $field;
    return $field;
}


sub _ap2relation {
    my($indexMap, $value) = @_;

    return undef if !defined $indexMap;
    my $field = $indexMap->{$value};
    return undef if !defined $field || !ref $field;
    return $field->{relation};
}


package Net::Z3950::RPN::RSID;

sub _throw { return Net::Z3950::FOLIO::_throw(@_); }

sub _toCQL {
    my $self = shift;
    my($session, $defaultSet) = @_;

    my $zid = $self->{id};
    my $rs = $session->{resultsets}->{$zid};
    _throw(128, $zid) if !defined $rs; # "Illegal result set name"

    my $sid = $rs->{rsid};
    return qq[cql.resultSetId="$sid"]
}

package Net::Z3950::RPN::And;
sub _toCQL {
    my $self = shift;
    my $left = $self->[0]->_toCQL(@_);
    my $right = $self->[1]->_toCQL(@_);
    return "($left and $right)";
}

package Net::Z3950::RPN::Or;
sub _toCQL {
    my $self = shift;
    my $left = $self->[0]->_toCQL(@_);
    my $right = $self->[1]->_toCQL(@_);
    return "($left or $right)";
}

package Net::Z3950::RPN::AndNot;
sub _toCQL {
    my $self = shift;
    my $left = $self->[0]->_toCQL(@_);
    my $right = $self->[1]->_toCQL(@_);
    return "($left not $right)";
}


=head1 SEE ALSO

=over 4

=item The C<z2folio> script conveniently launches the server.

=item C<Net::Z3950::FOLIO::Config> describes the configuration-file format.

=item The C<Net::Z3950::SimpleServer> handles the Z39.50 service.

=back

=head1 AUTHOR

Mike Taylor, E<lt>mike@indexdata.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 The Open Library Foundation

This software is distributed under the terms of the Apache License,
Version 2.0. See the file "LICENSE" for more information.

=cut

