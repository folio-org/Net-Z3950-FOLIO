package Net::Z3950::FOLIO::lodashGet;

use strict;
use warnings;
use Data::Dumper; $Data::Dumper::INDENT = 2;


sub lodashGet {
    my($data, $path) = @_;
    # warn "starting with ", Dumper($data);

    # XXX should be much more powerful, e.g. handing "[1]"
    my @components = split(/\./, $path);
    while (@components) {
	my $component = shift @components;
	$data = $data->{$component};
	# warn "moved down from '$component' to ", Dumper($data);
    }

    # warn "got ", (defined $data ? "'$data'" : 'UNDEF');

    return $data;
}


use Exporter qw(import);
our @EXPORT_OK = qw(lodashGet);


1;
