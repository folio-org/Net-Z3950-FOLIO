use strict;
use warnings;
use utf8;
use IO::File;
use Cpanel::JSON::XS qw(decode_json);

use Test::More tests => 18;
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

run_test($args, 'JSON', Net::Z3950::FOLIO::FORMAT_JSON, 'F', qq[{\n   "id" : "123"\n}\n]);
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'raw', qq[<opt>\n  <id>123</id>\n</opt>\n]);
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'usmarc', readFile('t/data/fetch/marc1.xml'));
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'opac', readFile('t/data/fetch/marc1.opac.xml'));
run_test($args, 'USMARC', Net::Z3950::FOLIO::FORMAT_USMARC, 'F', readFile('t/data/fetch/marc1.usmarc'));
run_test($args, 'USMARC', Net::Z3950::FOLIO::FORMAT_USMARC, 'b', readFile('t/data/fetch/marc1.usmarc'));


sub run_test {
    my($args, $format, $req_form, $comp, $expected) = @_;

    my $argsCopy = {
	%$args,
	REQ_FORM => $req_form,
	COMP => $comp,
    };

    Net::Z3950::FOLIO::_fetch_handler($argsCopy);
    ok(1, "called _fetch_handler with $format/$comp");

    my $res = $argsCopy->{RECORD};
    is($res, $expected, "$format/$comp record matched expected value");
}


sub mock_session {
    my $server = new Net::Z3950::FOLIO('t/data/config/foo');
    ok(defined $server, 'created Net::Z3950::FOLIO server object');

    my $session = $server->getSession('marcHoldings');
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
    $rs->insert_records(0, [ decode_json(readFile('t/data/fetch/inventory1.json')) ]);

    my $marc = mock_marcRecord($config);
    $rs->insert_marcRecords({ 123 => $marc });

    return $rs;
}


sub mock_marcRecord {
    my ($config) = @_;

    my $json = readFile('t/data/fetch/marc1.json');
    my $sourceRecord = decode_json($json);
    my $record = postProcess(($config->{postProcessing} || {})->{marc}, $sourceRecord);
    return Net::Z3950::FOLIO::Session::_JSON_to_MARC($record);
}


sub readFile {
    my($fileName) = @_;

    my $fh = IO::File->new();
    $fh->open("<$fileName") or die "can't read '$fileName': $!";
    my $data = join('', <$fh>);
    $fh->close();
    return $data;
}
