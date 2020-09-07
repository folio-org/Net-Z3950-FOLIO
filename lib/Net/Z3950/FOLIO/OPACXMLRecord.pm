package Net::Z3950::FOLIO::OPACXMLRecord;

use strict;
use warnings;

sub makeOPACXMLRecord {
    my($ihi, $marc) = @_;
    my $marcXML = $marc->as_xml_record();

    # The first line of $marcXML is an XML declaration, and there
    # seems to be no way to have MARC::File::XML omit this, so we just
    # snip it off.
    $marcXML =~ s/.*?\n//m;

    # Indent to fit into the record nicely
    $marcXML =~ s/^/    /gm;

    my $holdings = _makeHoldingsRecords($ihi->{holdingsRecords2}, $marc);
    my $holdingsRecords = join('\n', @$holdings);

    return qq[<opacRecord>
  <bibliographicRecord>
$marcXML
  </bibliographicRecord>
  <holdings>
    $holdingsRecords
  </holdings>
</opacRecord>
];
}

sub _makeHoldingsRecords {
    my($holdings, $marc) = @_;
    return [ map { _makeSingleHoldingsRecord($_, $marc) } @$holdings ];
}

# 
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
#	format (which is difficult to figure out)
#	localLocation
#	shelvingLocation
#	callNumber
#	enumAndChron
#	availableNow
#	availabilityDate
#	availableThru
#	itemId
#	temporaryLocation (overrides shelvingLocation)

sub _makeSingleHoldingsRecord {
    my($holding, $marc) = @_;

    my $effectiveLocation = $holding->{permanentLocation};

    my $format = _format($holding, $marc);
    my $nucCode = '';
    my $localLocation = '';
    my $shelvingLocation = '';
    my $location = $holding->{temporaryLocation} || $holding->{permanentLocation};
    if ($location) {
	$nucCode = ($location->{institution} || {})->{name};
	$localLocation = ($location->{campus} || {})->{name};
	$shelvingLocation = ($location->{library} || {})->{name};
    }
    my $callNumber = $holding->{callNumber}; # Z39.50 OPAC record has no way to express item-level callNumber
    # In the FOLIO data model, $enumAndChron does not exist at the holdings or volume level

    my $items = _makeItemRecords($holding->{holdingsItems});
    my $itemRecords = join('\n', @$items);

    my $typeOfRecord = 'xxx';
    my $encodingLevel = 'xxx';
    my $receiptAcqStatus = 'xxx';
    my $generalRetention = 'xxx';
    my $completeness = 'xxx';
    my $dateOfReport = 'xxx';
    my $shelvingData = 'xxx';
    my $copyNumber = 'xxx';
    my $publicNote = 'xxx';
    my $reproductionNote = 'xxx';
    my $termsUseRepro= 'xxx';

    my $xml = qq[
      <holding>
        <typeOfRecord>$typeOfRecord</typeOfRecord>
        <encodingLevel>$encodingLevel</encodingLevel>
        <format>$format</format>
        <receiptAcqStatus>$receiptAcqStatus</receiptAcqStatus>
        <generalRetention>$generalRetention</generalRetention>
        <completeness>$completeness</completeness>
        <dateOfReport>$dateOfReport</dateOfReport>
        <nucCode>$nucCode</nucCode>
        <localLocation>$localLocation</localLocation>
        <shelvingLocation>$shelvingLocation</shelvingLocation>
        <callNumber>$callNumber</callNumber>
        <shelvingData>$shelvingData</shelvingData>
        <copyNumber>$copyNumber</copyNumber>
        <publicNote>$publicNote</publicNote>
        <reproductionNote>$reproductionNote</reproductionNote>
        <termsUseRepro>$termsUseRepro</termsUseRepro>
        <circulations>
          $itemRecords
        </circulations>
      </holding>
];
    $xml =~ s/^\n//s; # trim leading newline
    $xml =~ s/^  //gm;
    return $xml;
}


sub _makeItemRecords {
    my($items) = @_;
    return [ map { _makeSingleItemRecord($_) } @$items ];
}


sub _makeSingleItemRecord {
    my($item) = @_;

    my $availableNow = $item->{status} && $item->{status}->{name} eq 'Available' ? 1 : 0;
    my $availabilityDate = 'xxx1a'; # This information is not in the FOLIO inventory data
    my $availableThru = 'xxx1b'; # This information is not in the FOLIO inventory data
    my $itemId = $item->{hrid};
    my @tmp;
    push @tmp, $item->{enumeration} if $item->{enumeration};
    push @tmp, $item->{chronology} if $item->{chronology};
    my $enumAndChronForItem = join(' ', @tmp);
    my $tl = $item->{temporaryLocation};
    my $temporaryLocation = $tl ? _makeLocation($tl) : '';

    my $xml = qq[
      <circulation>
        <availableNow value="$availableNow" />
        <availabilityDate>$availabilityDate</availabilityDate>
        <availableThru>$availableThru</availableThru>
        <restrictions>xxx2</restrictions>
        <itemId>$itemId</itemId>
        <renewable value="xxx3" />
        <onHold value="xxx5" />
        <enumAndChron>$enumAndChronForItem</enumAndChron>
        <midspine>xxx4</midspine>
        <temporaryLocation>$temporaryLocation</temporaryLocation>
      </circulation>];
    $xml =~ s/^/    /gm;
    return $xml;
}


# We _could_ make an attempt to get a holdings-level format, but to do
# that we would need to have mod-graphql expand the the
# `holdingsTypeId` field into a holdings-type object, and somehow
# interpret a field from within that structure into the MARC 007/0-1
# controlled vocabulary. That's a lot of work for little gain, so we
# just use the information from the MARC record.

sub _format {
    my($holding, $marc) = @_;

    my $field007 = $marc->field('007')->data();
    return substr($field007, 0, 2);
}


sub _makeLocation {
    my($data) = @_;

    my @tmp;
    foreach my $key (qw(institution campus library primaryServicePointObject)) {
	push @tmp, $data->{$key}->{name} if $data->{$key};
    }
    return join('/', @tmp);
}


use Exporter qw(import);
our @EXPORT_OK = qw(makeOPACXMLRecord);


# XXX only for debugging
sub _pretty_json {
    my($obj) = @_;

    my $coder = Cpanel::JSON::XS->new->ascii->pretty->allow_blessed->sort_by;
    return $coder->encode($obj);
}


1;
