package Net::Z3950::FOLIO::OPACXMLRecord;

use strict;
use warnings;

sub makeOPACXMLRecord {
    my($ihi, $marcXML) = @_;

    return $marcXML; # XXX for now
}

use Exporter qw(import);

our @EXPORT_OK = qw(makeOPACXMLRecord);

1;
