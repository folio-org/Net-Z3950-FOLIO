use strict;
use warnings;
use utf8;

use Test::More tests => 9;
BEGIN { use_ok('Net::Z3950::FOLIO') };

my $SETNAME = 'dummy';
my $session = mock_session();
ok(defined $session, 'mocked session');

my $args = {
    HANDLE => $session,
    SETNAME => $SETNAME,
    OFFSET => 1,
};

run_test($args, 'JSON', Net::Z3950::FOLIO::FORMAT_JSON, 'F', q[{
   "id" : "123"
}
]);
run_test($args, 'XML', Net::Z3950::FOLIO::FORMAT_XML, 'raw', q[<opt>
  <id>123</id>
</opt>
]);
# run_test($args, 'USMARC', Net::Z3950::FOLIO::FORMAT_USMARC, 'F', q[]);


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

  my $session = $server->getSession('bar');
  ok(defined $session, 'created session object');

  my $rs = mock_resultSet();
  ok(defined $session, 'mocked result-set object');

  $session->{resultsets} = {};
  $session->{resultsets}->{$SETNAME} = $rs;

  return $session;
}


sub mock_resultSet {
  my $rs = new Net::Z3950::FOLIO::ResultSet($SETNAME, 'title=water');
  $rs->total_count(1);
  $rs->insert_records(0, [{ id => '123' }]);

  # XXX This is not good enough
  my $marc = { title => 'The Lord of the Rings' };

  $rs->insert_marcRecords({ 123 => $marc });

  return $rs;
}
