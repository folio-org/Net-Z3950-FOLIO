use strict;
use warnings;
use utf8;
use IO::File;
use Cpanel::JSON::XS qw(decode_json);
use MARC::Record;

use Test::More tests => 18;
use Test::Differences;
oldstyle_diff;

BEGIN { use_ok('Net::Z3950::FOLIO') };
BEGIN { use_ok('Net::Z3950::FOLIO::PostProcess', qw(postProcess)) };

my $SETNAME = 'dummy';
my $session = mock_session();
ok(defined $session, 'mocked session');

my $args = {
    HANDLE => $session,
    SETNAME => $SETNAME,
    OFFSET => 1,
};

run_test($args, 'JSON', Net::Z3950::FOLIO::FORMAT_JSON, 'F', 'sorted1.json');
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'raw', 'inventory1.xml');
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'usmarc', 'marc1.xml');
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'opac', 'marc1.opac.xml');
run_test($args, 'USMARC', Net::Z3950::FOLIO::FORMAT_USMARC, 'F', 'marc1.usmarc');
run_test($args, 'USMARC', Net::Z3950::FOLIO::FORMAT_USMARC, 'b', 'marc1.usmarc');


sub run_test {
    my($args, $format, $req_form, $comp, $expectedFile) = @_;

    my $argsCopy = {
	%$args,
	REQ_FORM => $req_form,
	COMP => $comp,
    };

    Net::Z3950::FOLIO::_fetch_handler($argsCopy);
    pass("called _fetch_handler with $format/$comp");

    my $res = $argsCopy->{RECORD};
    if ($req_form eq Net::Z3950::FOLIO::FORMAT_USMARC) {
	my $marc = new_from_usmarc MARC::Record($res);
	$res = $marc->as_formatted() . "\n";
    }

    my $expected = readFile("t/data/fetch/$expectedFile");
    eq_or_diff($res, $expected, "$format/$comp record matched expected value");
}


sub mock_session {
    my $server = new Net::Z3950::FOLIO('t/data/config/foo');
    ok(defined $server, 'created Net::Z3950::FOLIO server object');

    my $session = $server->getSession('marcHoldings|postProcess');
    ok(defined $session, 'created session object');

    my $rs = mock_resultSet($session->{cfg});
    ok(defined $session, 'mocked result-set object');

    $session->{resultsets} = {};
    $session->{resultsets}->{$SETNAME} = $rs;

    return $session;
}


sub mock_resultSet {
    my ($config) = @_;

    my $rs = new Net::Z3950::FOLIO::ResultSet($SETNAME, 'title=water');
    $rs->total_count(1);
    my $inventoryRecord = decode_json(readFile('t/data/fetch/input-inventory1.json'));
    $rs->insert_records(0, [ { id => '123', holdingsRecords2 => [ $inventoryRecord ] } ]);

    my $marc = mock_marcRecord($config);
    $rs->insert_marcRecords({ 123 => $marc });

    return $rs;
}


sub mock_marcRecord {
    my ($config) = @_;

    my $json = readFile('t/data/fetch/input-marc1.json');
    my $sourceRecord = decode_json($json);
    return Net::Z3950::FOLIO::Session::_JSON_to_MARC($sourceRecord);
}


sub readFile {
    my($fileName) = @_;

    my $fh = IO::File->new();
    $fh->open("<$fileName") or die "can't read '$fileName': $!";
    my $data = join('', <$fh>);
    $fh->close();
    return $data;
}
