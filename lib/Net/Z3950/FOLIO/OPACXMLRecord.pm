package Net::Z3950::FOLIO::OPACXMLRecord;

use strict;
use warnings;

sub makeOPACXMLRecord {
    my($ihi, $marcXML) = @_;

    # The first line of $marcXML is an XML declaration, and there
    # seems to be no way to have MARC::File::XML omit this, so we just
    # snip it off.
    $marcXML =~ s/.*?\n//m;

    my $holdings = _makeHoldingsRecords($ihi->{holdingsRecords2});
    my $holdingsRecords = join('\n', @$holdings);

    return "
<opacRecord>
  <bibliographicRecord>
    $marcXML
  </bibliographicRecord>
  <holdings>
    $holdingsRecords
  </holdings>
</opacRecord>
";
}

sub _makeHoldingsRecords {
    my($holdings) = @_;
    return [ map { _makeSingleHoldingsRecord($_) } @$holdings ];
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
    my($holding) = @_;

    return qq[
<holding>
  <typeOfRecord>xxx</typeOfRecord>
  <encodingLevel>xxx</encodingLevel>
  <format>xxx</format>
  <receiptAcqStatus>xxx</receiptAcqStatus>
  <generalRetention>xxx</generalRetention>
  <completeness>xxx</completeness>
  <dateOfReport>xxx</dateOfReport>
  <nucCode>xxx</nucCode>
  <localLocation>xxx</localLocation>
  <shelvingLocation>xxx</shelvingLocation>
  <callNumber>xxx</callNumber>
  <shelvingData>xxx</shelvingData>
  <copyNumber>xxx</copyNumber>
  <publicNote>xxx</publicNote>
  <reproductionNote>xxx</reproductionNote>
  <termsUseRepro>xxx</termsUseRepro>
  <enumAndChron>xxx</enumAndChron>
  <volumes>
    <volume>
      <enumeration>xxx</enumeration>
      <chronology>xxx</chronology>
      <enumAndChron>xxx</enumAndChron>
    </volume>
  </volumes>
  <circulations>
    <circulation>
      <availableNow value="xxx" />
      <availabilityDate>xxx</availabilityDate>
      <availableThru>xxx</availableThru>
      <restrictions>xxx</restrictions>
      <itemId>xxx</itemId>
      <renewable value="xxx" />
      <onHold value="xxx" />
      <enumAndChron>xxx</enumAndChron>
      <midspine>xxx</midspine>
      <temporaryLocation>xxx</temporaryLocation>
    </circulation>
  </circulations>
</holding>
];
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
