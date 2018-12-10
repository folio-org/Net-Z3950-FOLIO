package Net::Z3950::FOLIO::ResultSet;

use strict;
use warnings;

sub new {
    my $class = shift();
    my($setname, $cql) = @_;

    return bless {
	setname => $setname,
	cql => $cql,
	total_count => undef,
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

sub total_count {
    my $this = shift();
    my($newVal) = @_;

    my $old = $this->{total_count};
    $this->{total_count} = $newVal if defined $newVal;
    return $old;
}

sub record {
    my $this = shift();
    my($index1) = @_;

    return $this->{records}->[$index1-1];
}

1;
