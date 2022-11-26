# Note that this test currently emits a harmless, though alarming, message:
#	Unknown argument "limit" on field "T_instance.holdingsRecords2".
# This is due to the Index Data FOLIO testing server being out of
# date. It should be cleared up in early 2022.

use strict;
use warnings;
use Test::More tests => 5;
use Test::Differences;
oldstyle_diff;

BEGIN { use_ok('Net::Z3950::FOLIO') };
my $count = 0;

SKIP: {
    skip('zoomsh not available', 2) if system('zoomsh quit') ne 0;

    my $pid = fork();
    exit 'Uh-oh! $!' if $pid < 0;

    if ($pid == 0) {
	print STDERR "*** starting server\n";
	# Child
	$ENV{OKAPI_INDEXDATA_PASSWORD} = 'swordfish';
	my $service = new Net::Z3950::FOLIO('etc/config');
	$service->launch_server('z2folio', '-1', '-f', 't/data/config/yazgfs-9996.xml');
	print STDERR "*** server exited\n";
    }

    # Parent
    sleep 1; # Allow time for server to start up
    print STDERR "*** waited for server, count=$count\n";
    $count++;
    ok(1, 'waited for service');
    my $res = `zoomsh -e "open \@:9996/indexdata|marcHoldings" "find \@attr 1=12 in00000000007" "set preferredRecordSyntax opac" "show 0" quit 2>&1`;
    ok(1, 'ran a session');
    print STDERR "*** got record\n";
    my @lines = split("\n", $res);
    shift(@lines); # remove "@:9996/snapshot|marcHoldings: 1 hits"
    shift(@lines); # remove "0 database= syntax=OPAC schema=unknown"
    $res = join("\n", @lines) . "\n";
    ok(1, 'extracted OPAC XML');
    print STDERR "*** record is [$res]\n";

    my $expectedFile = 'in00000000007-opac.xml';
    my $expected = readFile("t/data/fetch/$expectedFile");
    eq_or_diff($res, $expected, "OPAC record matches expected value ($expectedFile)");
    print STDERR "*** compared record\n";
    exit;
    print STDERR "*** still here\n";
}


sub readFile {
    my($fileName) = @_;

    my $fh = IO::File->new();
    $fh->open("<$fileName") or die "can't read '$fileName': $!";
    my $data = join('', <$fh>);
    $fh->close();
    return $data;
}
