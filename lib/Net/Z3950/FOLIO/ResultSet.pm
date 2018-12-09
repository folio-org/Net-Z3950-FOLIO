package Net::Z3950::FOLIO::ResultSet;

sub new {
    my $class = shift();
    my($setname, $cql) = @_;

    return bless {
	setname => $setname,
	cql => $cql,
	totalRecords => undef,
	records => [],
    }, $class;
}

sub insert_records {
    my $this = shift();
    my($offset, $records) = @_;

    for (my $i = 0; $i < @$records; $i++) {
	$this->{records}->[$offset + $i] = $records->[$i];
    }
}

sub totalRecords {
    my $this = shift();
    my($newVal) = @_;

    my $old = $this->{totalRecords};
    $this->{totalRecords} = $newVal if defined $newVal;
    return $old;
}

sub record {
    my $this = shift();
    my($index1) = @_;

    return $this->{records}->[$index1-0];
}

1;
