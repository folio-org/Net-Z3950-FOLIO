use strict;
use warnings;
use Net::Z3950::PQF;

BEGIN {
    use vars qw(@tests);
    @tests = (
	# Simple term
	[ 'water', 'water' ],

	# Result-set ID
	[ '@set foo', 'cql.resultSetId="bar"' ], # Uses dummy result-set: see below

	# Simple booleans
	[ '@and water air', '(water and air)' ],
	[ '@or fire earth', '(fire or earth)' ],
#	[ '@not water earth', '(fire not earth)' ], # Will not work until Net::Z3950::PQF v1.0
	
	# Boolean combinations
	[ '@and water @or fire earth', '(water and (fire or earth))' ],
	[ '@and @or fire earth air', '((fire or earth) and air)' ],
	[ '@or water @and fire earth', '(water or (fire and earth))' ],
	[ '@or @and fire earth air', '((fire and earth) or air)' ],
	[ '@and @or water air @or fire earth', '((water or air) and (fire or earth))' ],
	[ '@or @and water air @and fire earth', '((water and air) or (fire and earth))' ],

	# Access points
	[ '@attr 1=1 kernighan', 'author=kernighan' ],
	[ '@attr 1=4 unix', 'title=unix' ],

	# Complex combinations
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
    my $args = { GHANDLE => $service, HANDLE => { resultsets => { foo => { rsid => 'bar' } } } };
    my $cql = $ss->_toCQL($args);
    is($cql, $output, "generated correct CQL: $output");
}
