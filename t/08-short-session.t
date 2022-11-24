# Note that this test currently emits a harmless, though alarming, message:
#	Unknown argument "limit" on field "T_instance.holdingsRecords2".
# This is due to the Index Data FOLIO testing server being out of
# date. It should be cleared up in early 2022.

use strict;
use warnings;
use Test::More tests => 3;
BEGIN { use_ok('Net::Z3950::FOLIO') };

SKIP: {
    skip('zoomsh not available', 2) if system('zoomsh quit') ne 0;

    my $pid = fork();
    exit 'Uh-oh! $!' if $pid < 0;

    if ($pid == 0) {
	# Child
	sleep 1; # Allow time for server to start up
	exec 'zoomsh -e "open @:9996/snapshot|marcHoldings" "find @attr 1=12 in00000000006" "set preferredRecordSyntax opac" "show 0" quit 1>&2';
    }

    $ENV{OKAPI_SNAPSHOT_PASSWORD} = 'admin';
    my $service = new Net::Z3950::FOLIO('etc/config');
    ok(defined $service, 'created service');
    $service->launch_server('z2folio', '-1', '-f', 't/data/config/yazgfs-9996.xml');
    ok(1, 'served a session');
}
