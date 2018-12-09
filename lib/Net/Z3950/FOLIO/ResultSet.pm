package Net::Z3950::FOLIO::ResultSet;

sub new {
    my $class = shift();
    my($setname, $cql, $totalRecords) = @_;

    return bless {
	setname => $setname,
	cql => $cql,
	totalRecords => $totalRecords,
	instances => [],
    }, $class;
}

sub totalRecords {
    my $this = shift();
    return $this->{totalRecords};
}

1;
