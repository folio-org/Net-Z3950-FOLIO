package Net::Z3950::FOLIO::HoldingsRecords;

use strict;
use warnings;


use Net::Z3950::FOLIO::lodashGet qw(lodashGet);


sub makeHoldingsRecords {
    my($rec, $marc) = @_;
    my $cfg = $rec->rs()->session()->{cfg}; # XXX maybe make an accessor method
    my $holdings = $rec->jsonStructure()->{holdingsRecords2};

    return [ map { _makeSingleHoldingsRecord($_, $marc, $cfg) } @$holdings ];
}


# The YAZ XML format for OPAC records is a fairly close representation
# of the Z39.50 OPAC record, which is specified by the ASN.1 at
# https://www.loc.gov/z3950/agency/asn1.html#RecordSyntax-opac
#
# But this is only very lightly documented. Some of the fields are
# commented with what seem to be references to the MARC format,
# e.g. `typeOfRecord` is commented "LDR 06", which is indeed "Type of
# record" is the MARC specification: see
# https://www.loc.gov/marc/bibliographic/bdleader.html
# But why would we include information from the MARC record describing
# the bibliographic data related to the holding when we already have
# the actual MARC record in <bibliographicRecord>?
#
# Based on the document "z39.50 OPAC response examples for Cornell"
# attached to UXPROD-560, it seems like the key elements to fill in
# are:
#	format
#	localLocation
#	shelvingLocation
#	callNumber
#	enumAndChron
#	availableNow
#	availabilityDate
#	availableThru
#	itemId
#	temporaryLocation (overrides shelvingLocation)
#
# In the FOLIO data model, <enumAndChron> does not exist at the
# holdings or volume level, only at the item level.
#
sub _makeSingleHoldingsRecord {
    my($holding, $marc, $cfg) = @_;

    my $nucCode;
    my $localLocation;
    my $shelvingLocation;
    my $location = $holding->{temporaryLocation} || $holding->{permanentLocation};
    if ($location) {
	$nucCode = ($location->{institution} || {})->{name};
	$localLocation = ($location->{library} || {})->{name};
	$shelvingLocation = $location->{name};
    }

    my $itemObjects = _makeItemRecords($holding->{bareHoldingsItems}, $cfg, $location, $holding->{permanentLocation});

    return bless [
        [ 'typeOfRecord', substr($marc->leader(), 5, 1) ], # LDR 06
        [ 'encodingLevel', substr($marc->leader(), 16, 1) ], # LDR 017
        [ 'format', _format($holding, $marc) ],
        [ 'receiptAcqStatus', _marcFieldChars($marc, '008', '06') ],
        [ 'generalRetention', _marcFieldChars($marc, '008', '12') ],
        [ 'completeness', _marcFieldChars($marc, '008', '16') ],
        [ 'dateOfReport', _marcFieldChars($marc, '008', '26-31') ],
        [ 'nucCode', $nucCode ],
        [ 'localLocation', $localLocation ],
        [ 'shelvingLocation', $shelvingLocation ],
        # Z39.50 OPAC record has no way to express item-level callNumber
        [ '_callNumberPrefix', $holding->{callNumberPrefix} ],
        [ 'callNumber', $holding->{callNumber} ],
        [ '_callNumberSuffix', $holding->{callNumberSuffix} ],
        [ 'shelvingData', _makeShelvingData($holding) ],
        [ 'copyNumber', $holding->{copyNumber} ], # 852 $t
        [ 'publicNote', _makePublicNote($holding) ], # 852 $z
        [ 'reproductionNote', _notesOfType($holding->{notes}, qr/reproduction/i) ], # 843
        [ 'termsUseRepro', _makeTermsUseRepro($marc) ], # 845
        [ 'circulations', $itemObjects, undef, 1 ],
    ], 'Net::z3950::FOLIO::OPACXMLRecord::holding';
}


sub _marcFieldChars {
    my($marc, $fieldName, $chars) = @_;
    my $field = $marc->field($fieldName);
    return undef if !$field;
    my $data = $field->data();
    return undef if !$data;

    my @pieces = split(/-/, $chars);
    my($start1, $end1) = @pieces;
    $end1 = $start1 if !$end1;
    return substr($data, $start1-1, $end1-$start1+1);
}


# I don't really know what they want of me here. The "documentation",
# found only in the OPAC record-format ASN-1, simply says "852 $j thru
# $m". But these fields mostly just duplicate the call-number:
#
#	$j - Shelving control number (NR)
#	$k - Call number prefix (R)
#	$l - Shelving form of title (NR)
#	$m - Call number suffix (R)
#
# Since the only thing we have that is _not_ part of the call-number
# is the shelving title, I guess we may as well return that.

sub _makeShelvingData {
    my($holding) = @_;
    return $holding->{shelvingTitle};
}


# This field is rather overloaded. It must contain not only holdings
# notes of type "public" and similar, but also any holdings statements
# (each potentially consisting of statement, note and staffNote) along
# with the same thing for holdingsStatementsForSupplements and
# holdingsStatementsForIndexes.
#
# Here's how we do this:
# * Each entry is newline-separated
# * Each holdings statement is included
# * Each holdings-for-supplements statement is included, prefixed with "SUPPLEMENT: "
# * Each holdings-for-indexes statement is included, prefixed with "INDEX: "
# * Any public notes are included
#
# When there is more than one statement in any of the categories
# (holdings, holdings for supplements, holdings for indexes), they are
# all numbered within that category. When there is only one statement
# in a category, it is not numbered.
#
# This means that in the common case of a single holdings statement,
# it will appear alone and unadorned.

sub _makePublicNote {
    my($holding) = @_;

    my @notes;
    push @notes, _holdingsStatements($holding->{holdingsStatements}, undef);
    push @notes, _holdingsStatements($holding->{holdingsStatementsForSupplements}, "SUPPLEMENT");
    push @notes, _holdingsStatements($holding->{holdingsStatementsForIndexes}, "INDEX");
    push @notes, _notesOfType($holding->{notes}, qr/public/i);

    @notes = grep { defined } @notes;
    return undef if @notes == 0;
    return join("\n", @notes);
}


sub _holdingsStatements {
    my($statements, $caption) = @_;
    return undef if !defined $statements || @$statements == 0;

    my @res = map {
	my $s = $statements->[$_-1];
	my $res;
	if (defined $caption && @$statements > 1) {
	    $res = "$caption $_: ";
	} elsif (defined $caption) {
	    $res = "$caption: ";
	} elsif (@$statements > 1) {
	    $res = "$_: ";
	}

	$res .= $s->{statement};
	$res .= " [NOTE: " . $s->{note} . "]" if $s->{note};
	$res .= " [STAFF NOTE: " . $s->{staffNote} . "]" if $s->{staffNote};
	$res;
    } 1..@$statements;

    return join("\n", @res);
}


# In the FOLIO inventory model, instances, holdings records and items
# can all have a set of zero or more notes, each of which has a note
# type. These note types are drawn from three separate vocabularies
# (one each for instances, holdings records and items), each
# maintained in the Settings rather than hardwired like identifier
# types. Among these vocabularies, there may be (and in the sample
# data there are) types called "Reproduction" and "Public". So we can
# pick these out by referring to the note-type text rather than to
# known UUIDS -- and pull out the text of notes of the appropriate
# type.
#
# When there is more than one note of a given type, we return a single
# string containing each note on a line of its own preceded by its
# ordinal number. This number is omitted when there is a single note.
#
sub _notesOfType {
    my($notes, $regexp) = @_;

    my @notes;
    foreach my $note (@$notes) {
	my $type = $note->{holdingsNoteType};
	push @notes, $note->{note} if $type && $type->{name} =~ $regexp;
    }

    return undef if @notes == 0;
    return $notes[0] if @notes == 1;
    return join("\n", map { "$_: " . $notes[$_-1] } 1..@notes);
}


# The ASN.1 one relates this OPAC-record field to MARC field 845,
# which is "Terms Governing Use and Reproduction Note". That field has
# 13 subfields, and there is no guidance on which might be
# relevant. The best we can do is probably just to glue them all
# together.
#
sub _makeTermsUseRepro {
    my($marc) = @_;

    my $field845 = $marc->field('845') or return undef;
    my @subfields = $field845->subfields() or return undef;
    return join('', map { '$' . $_->[0] . $_->[1] } @subfields);
}


sub _makeItemRecords {
    my($items, $cfg, $defaultLocation, $defaultPermamentLocation) = @_;
    return [ map { _makeSingleItemRecord($_, $cfg, $defaultLocation, $defaultPermamentLocation) } @$items ];
}


sub _makeSingleItemRecord {
    my($item, $cfg, $defaultLocation, $defaultPermamentLocation) = @_;

    my @tmp;
    push @tmp, $item->{enumeration} if $item->{enumeration};
    push @tmp, $item->{chronology} if $item->{chronology};
    my $enumAndChronForItem = @tmp ? join(' ', @tmp) : undef;
    my $ecnc = $item->{effectiveCallNumberComponents} || {};

    return bless [
	[ 'availableNow', _makeAvailableNow($item), 'value' ],
	[ 'availabilityDate', _makeAvailabilityDate($item) ],
        [ 'availableThru', _makeAvailableThru($item, $cfg) ],
        [ 'restrictions', _makeRestrictions($item) ],
        [ 'itemId', $item->{barcode} ],
	# XXX Determining a correct value for <renewable> would be
	# very complicated, involving loan policies. But we have to
	# include _something_, because this element is mandatory in
	# YAZ's OPACXML schema -- probably accidentally
        [ 'renewable', '', 'value' ],
        [ 'onHold', _makeOnHold($item), 'value' ],
        [ '_enumeration', $item->{enumeration} ],
        [ '_chronology', $item->{chronology} ],
        [ 'enumAndChron', $enumAndChronForItem ],
        [ 'midspine', undef ], # XXX Will be added in UIIN-220 but doesn't exist yet
        [ 'temporaryLocation', _makeLocation($item->{temporaryLocation} || $item->{permanentLocation} || $defaultLocation) ],
	[ '_permanentLocation', _makeLocation($item->{permanentLocation} || $defaultPermamentLocation) ],
        [ '_holdingsLocation', _makeLocation($defaultLocation) ],
        [ '_callNumber', $ecnc->{callNumber} ],
        [ '_callNumberPrefix', $ecnc->{prefix} ],
        [ '_callNumberSuffix', $ecnc->{suffix} ],
        [ '_volume', $item->{volume} ],
        [ '_yearCaption', _makeYearCaption($item->{yearCaption}) ],
	[ '_accessionNumber', $item->{accessionNumber} ],
	[ '_copyNumber', $item->{copyNumber} ],
	[ '_descriptionOfPieces', $item->{descriptionOfPieces} ],
	[ '_discoverySuppress', $item->{discoverySuppress} ],
	[ '_hrid', $item->{hrid} ],
	[ '_id', $item->{id} ],
	[ '_itemIdentifier', $item->{itemIdentifier} ],
    ], 'Net::z3950::FOLIO::OPACXMLRecord::item';
}


# We _could_ make an attempt to get a holdings-level format, but to do
# that we would need to have mod-graphql expand the the
# `holdingsTypeId` field into a holdings-type object, and somehow
# interpret a field from within that structure into the MARC 007/0-1
# controlled vocabulary. That's a lot of work for little gain, so we
# just use the information from the MARC record.

sub _format {
    my($holding, $marc) = @_;

    my $field007 = $marc->field('007');
    return undef if !defined $field007;
    my $data = $field007->data();
    return substr($data, 0, 2);
}


# Initially, the calculation here was just that an item is available
# if it has a status and that status is 'Available'. But since there
# is no way to directly represent item suppression in the Z39.50 OPAC
# record, we also use this field for it: an item that is suppressed
# from discovery is reported as unavailable. See ZF-60.
#
sub _makeAvailableNow {
    my($item) = @_;

    return 0 if $item->{discoverySuppress};
    return $item->{status} && $item->{status}->{name} eq 'Available' ? 1 : 0;
}


sub _makeAvailabilityDate {
    my($item) = @_;

    return $item->{loans} && $item->{loans}->{dueDate};
}


# It's not clear what the <availableThru> field even means. It's
# included in the name, without comment, in the Z39.50 ASN.1 and in
# the YAZ OPAC XML schema.
#
# * I first thought it meant "Date until which the item is guaranteed
#   to remain available".
# * Examples in the document "z39.50 OPAC response examples for
#   Cornell" attached to UXPROD-560 suggests that it's the opaque
#   identifier of a loan policy.
# * A brief note in the document "Kuali OLE Z39.50 Integration -
#   DRAFT" suggests it means "Library building location, or possibly
#   access policy".
#
# But we have concrete expectations from Lehigh that it means the
# material-type of the item: see ZF-26. It's not clear why that would
# be called "availableThru", but ¯\_(ツ)_/¯
#
sub _makeAvailableThru {
    my($item, $cfg) = @_;
    # use Data::Dumper; $Data::Dumper::INDENT = 2; print "_makeAvailableThru: cfg = ", Dumper($cfg);
    if ($cfg->{fieldDefinitions} &&
	$cfg->{fieldDefinitions}->{circulation} &&
	$cfg->{fieldDefinitions}->{circulation}->{availableThru}) {
	my $field = $cfg->{fieldDefinitions}->{circulation}->{availableThru};
	# warn "using field '$field' for availableThru";
	# XXX We may need more sophisticated interpolation from the item record and maybe even the holding or instance
	return lodashGet($item, $field);
    }

    return ($item->{materialType} || {})->{name};
}


# The restrictions, if any, can be inferred from some values of
# status. Charlotte says "I would say all of them except: Available,
# and On order". She will check with out contacts at Lehigh.
#
# The list of valid statuses is wired right into the JSONN Schema at
# mod-inventory-storage/ramls/item.json
#
sub _makeRestrictions {
    my($item) = @_;

    my $status = $item->{status} || return undef;
    my $name = $status->{name} || return undef;
    return ($name ne 'Available' && $name ne 'On order') ? $name : undef;
}


# Items don't know whether they are on hold, but the requests module
# does. We can discover this by another request (or, more likely, by
# having mod-graphql include the results of another request). The
# relevant WSAPI is documented at
# https://github.com/folio-org/mod-circulation/blob/cab5ab44a3383bad938f33ad616fb0ef1244e67a/ramls/circulation.raml#L278
#
# But we have to provide a non-undef value here, because this element
# is mandatory in YAZ's OPACXML schema -- probably accidentally.
#
sub _makeOnHold {
    my($item) = @_;
    return ''; # XXX for now
}


sub _makeLocation {
    my($data) = @_;
    return undef if !defined $data;
    return $data->{name} if defined $data->{name};

    my @tmp;
    foreach my $key (qw(institution campus library primaryServicePointObject)) {
	push @tmp, $data->{$key}->{name} if $data->{$key};
    }
    return join('/', @tmp);
}


sub _makeYearCaption {
    my($data) = @_;

    return undef if !$data;
    return join(', ', @$data) if (ref $data eq 'ARRAY');
    return $data;
}


use Exporter qw(import);
our @EXPORT_OK = qw(makeHoldingsRecords _makeSingleHoldingsRecord);


1;
