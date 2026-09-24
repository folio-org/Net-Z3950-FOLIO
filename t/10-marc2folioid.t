use strict;
use warnings;

use Net::Z3950::FOLIO::Record qw(_marc2folioId);
use Test::More tests => 2;

# 999		$a test $s Y $i 31144005998793 
# 999 ff	$i 4b8e9697-8bb2-4345-bf81-9cd0d52ce334 $s 877a1ec9-9f62-4959-b5de-c58ff41f7e2f

sub makeMarcRecord {
    my @fields;
    push @fields, new MARC::Field('999', '', '', a => 'test', s => 'Y', i => '31144005998793');
    push @fields, new MARC::Field('999', 'f', 'f', i => '4b8e9697-8bb2-4345-bf81-9cd0d52ce334', s => '877a1ec9-9f62-4959-b5de-c58ff41f7e2f');
    my $marc = new MARC::Record();
    $marc->append_fields(@fields);
    # warn $marc->as_formatted();
    return $marc;
}

my $marc = makeMarcRecord();
ok(defined $marc, 'created marc record');
my $id = _marc2folioId($marc);
is($id, '4b8e9697-8bb2-4345-bf81-9cd0d52ce334', 'extracted correct FOLIO ID');
