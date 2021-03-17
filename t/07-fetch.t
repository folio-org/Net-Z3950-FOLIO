use strict;
use warnings;
use utf8;

use Test::More tests => 5;

BEGIN { use_ok('Net::Z3950::FOLIO') };

my $server = new Net::Z3950::FOLIO('t/data/config/foo');
ok(defined $server, 'created Net::Z3950::FOLIO server object');

my $session = $server->getSession('bar');
ok(defined $session, 'created session object');

my $SETNAME = 'dummy';
my $rs = new Net::Z3950::FOLIO::ResultSet($SETNAME, 'title=water');
$rs->total_count(1);
$rs->insert_records(0, [{ id => '123' }]);

$session->{resultsets} = {};
$session->{resultsets}->{$SETNAME} = $rs;

my $args = {
    HANDLE => $session,
    SETNAME => $SETNAME,
    OFFSET => 1,
    REQ_FORM => Net::Z3950::FOLIO::FORMAT_JSON,
    COMP => 'F',
};

Net::Z3950::FOLIO::_fetch_handler($args);
ok(1, 'called _fetch_handler');

my $res = $args->{RECORD};
is($res, q[{
   "id" : "123"
}
], 'JSON record matched expected value');
