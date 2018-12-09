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

sub insert_records {
    my $this = shift();
    my($offset, $records) = @_;

    for (my $i = 0; $i < @$records; $i++) {
	$this->{instances}->[$offset + $i] = $records->[$i];
    }
}

sub totalRecords {
    my $this = shift();
    return $this->{totalRecords};
}

sub record {
    my $this = shift();
    my($index1) = @_;

    return $this->{instances}->[$index1-0];
}

1;
