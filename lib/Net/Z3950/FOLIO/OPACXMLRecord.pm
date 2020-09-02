package Net::Z3950::FOLIO::OPACXMLRecord;

use strict;
use warnings;

sub makeOPACXMLRecord {
    my($ihi, $marcXML) = @_;

    # The first line of $marcXML is an XML declaration, and there
    # seems to be no way to have MARC::File::XML omit this, so we just
    # snip it off.
    $marcXML =~ s/.*?\n//m;

    my @holdings = _makeHoldingsRecords($ihi->{holdingsRecords2});
    my $holdingsRecords = join('\n', @holdings);

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

    warn "holdings=", _pretty_json($holdings);
    return ();
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
