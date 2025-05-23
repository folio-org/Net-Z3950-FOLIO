use strict;
use warnings;
use Test::More tests => 28;
BEGIN { use_ok('Net::Z3950::FOLIO::Config') };

my $cfg = new Net::Z3950::FOLIO::Config('t/data/config/foo', 'bar');
ok(defined $cfg, 'parsed stacked foo->bar config');
is($cfg->{foo}, 42, "Base value, not overriden");
is($cfg->{bar}, 4, "Overrides base value");
is($cfg->{baz}, 'herring', "New value, not in base");
is($cfg->{quux}, undef, "Absent from base and override");
is($cfg->{indexMap}->{1}, 'contributors/@name', "index-map entry overridden");
is($cfg->{indexMap}->{4}, "title", "index-map entry from base");
is($cfg->{indexMap}->{21}, "subject", "index-map entry not in base");

$cfg = new Net::Z3950::FOLIO::Config('t/data/config/foo', 'bar', 'baz');
ok(defined $cfg, 'parsed stacked foo->bar->baz config');
is($cfg->{foo}, 42, "Base value, not overriden");
is($cfg->{bar}, 4, "Overridden in first override");
is($cfg->{baz}, 'thricken', "Overridden in second override");
is($cfg->{quux}, 99, "Present only in second override");

$cfg = new Net::Z3950::FOLIO::Config('t/data/config/foo', 'marcHoldings');
ok(defined $cfg, 'parsed stacked foo->marcHoldings config');
is($cfg->{marcHoldings}->{field}, "952", "Base value, not overriden");
is($cfg->{marcHoldings}->{fieldPerItem}, undef, "Absent base value (fieldPerItem)");
is($cfg->{marcHoldings}->{holdingsInEachItem}, undef, "Absent base value (holdingsInEachItem)");

$cfg = new Net::Z3950::FOLIO::Config('t/data/config/foo', 'marcHoldings', 'fieldPerItem', 'holdingsInEachItem');
ok(defined $cfg, 'parsed stacked foo->marcHoldings->fieldPerItem->holdingsInEachItem config');
is($cfg->{marcHoldings}->{field}, "952", "Base value, not overriden");
is($cfg->{marcHoldings}->{fieldPerItem}, 1, "fieldPerItem overriden");
is($cfg->{marcHoldings}->{holdingsInEachItem}, 1, "holdingsInEachItem overriden");
is($cfg->{fieldDefinitions}->{circulation}->{dummy}, "someField", "Present base value (dummy)");
is($cfg->{fieldDefinitions}->{circulation}->{availableThru}, undef, "Absent base value (availableThru)");

$cfg = new Net::Z3950::FOLIO::Config('t/data/config/foo', 'marcHoldings', 'fieldPerItem', 'atplt');
ok(defined $cfg, 'parsed stacked foo->marcHoldings->fieldPerItem->atplt config');
is($cfg->{marcHoldings}->{field}, "952", "Base value, not overriden");
is($cfg->{fieldDefinitions}->{circulation}->{dummy}, "someField", "Present base value (dummy)");
is($cfg->{fieldDefinitions}->{circulation}->{availableThru}, "permanentLoanType", "availableThru overriden");
