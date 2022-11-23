package Net::Z3950::FOLIO::PostProcess::OPAC;

use strict;
use warnings;
use utf8;

use Net::Z3950::FOLIO::PostProcess::Transform qw(transform);


sub postProcessHoldings {
    my($cfg, $holdings) = @_;

    # use Data::Dumper; $Data::Dumper::INDENT = 2; print Dumper($cfg);
    # XXX do it!

    return $holdings;
}


use Exporter qw(import);
our @EXPORT_OK = qw(postProcessHoldings);


1;
