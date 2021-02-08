package Net::Z3950::FOLIO::HoldingsInfo;

use strict;
use warnings;

sub insertHoldingsInfo {
    my($ihi, $marc) = @_;

    # XXX Do nothing for now: see ZF-30
}


use Exporter qw(import);
our @EXPORT_OK = qw(insertHoldingsInfo);


1;
