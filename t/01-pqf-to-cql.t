use strict;
use warnings;
use Net::Z3950::PQF;

BEGIN {
    use vars qw(@tests);
    @tests = (
	[ 'water', 'water' ],
	[ '@and @attr 1=1003 kernighan @attr 1=4 unix', '(author=kernighan and title=unix)' ],
    );
}

use Test::More tests => 2*scalar(@tests) + 2;

BEGIN { use_ok('Net::Z3950::FOLIO') };

$ENV{OKAPI_PASSWORD} = ''; # Avoid warning from failed variable substitution
my $service = new Net::Z3950::FOLIO('etc/config.json');
ok(defined $service, 'made FOLIO service object');
my $parser = new Net::Z3950::PQF();

foreach my $test (@tests) {
    my($input, $output) = @$test;

    my $node = $parser->parse($input);
    ok(defined $node, "parsed PQF: $input");

    my $ss = $node->toSimpleServer();
    my $args = { GHANDLE => $service };
    my $cql = $ss->_toCQL($args);
    is($cql, $output, "generated correct CQL: $output");
}
