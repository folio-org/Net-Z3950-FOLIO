package Net::Z3950::FOLIO;

use 5.008000;
use strict;
use warnings;

use IO::File;
use Cpanel::JSON::XS qw(decode_json encode_json);
use Net::Z3950::SimpleServer;
use ZOOM; # For ZOOM::Exception
use LWP::UserAgent;
use MARC::Record;

our $VERSION = '0.01';

1;


=head1 NAME

Net::Z3950::FOLIO - Z39.50 server for FOLIO bibliographic data

=head1 SYNOPSIS

 use Net::Z3950::FOLIO;
 $service = new Net::Z3950::FOLIO('config.json');
 $service->launch_server("someServer", @ARGV);

=head1 DESCRIPTION

The C<Net::Z3950::FOLIO> module provides all the application logic of
a Z39.50 server that allows searching in and retrieval from the
inventory module of FOLIO.  It is used by the C<z2folio> program, and
there is probably no good reason to make any other program to use it.

The library has only two public entry points: the C<new()> constructor
and the C<launch_server()> method.  The synopsis above shows how they
are used: a Net::Z3950::FOLIO object is created using C<new()>, then
the C<launch_server()> method is invoked on it to start the server.
(In fact, this synopsis is essentially the whole of the code of the
C<simple2zoom> program.  All the work happens inside the library.)

=head1 METHODS

=head2 new($configFile)

 $s2z = new Net::Z3950::FOLIO('config.json');

Creates and returns a new Net::Z3950::FOLIO object, configured according to
the JSON file C<$configFile> that is the only argument.  The format of
this file is described in C<Net::Z3950::FOLIO::Config>.

=cut

sub new {
    my $class = shift();
    my($cfgfile) = @_;

    my $this = bless {
	cfgfile => $cfgfile || 'config.json',
	cfg => undef,
    }, $class;

    $this->_reload_config_file();

    $this->{server} = Net::Z3950::SimpleServer->new(
	GHANDLE => $this,
	INIT =>    \&_init_handler,
	SEARCH =>  \&_search_handler,
	PRESENT => \&_present_handler,
	FETCH =>   \&_fetch_handler,
	SCAN =>    \&_scan_handler,
	DELETE =>  \&_delete_handler,
	SORT   =>  \&_sort_handler,
    );

    return $this;
}


sub _reload_config_file {
    my $this = shift();

    my $cfgfile = $this->{cfgfile};
    my $fh = new IO::File("<$cfgfile")
	or die "$0: can't open config file '$cfgfile': $!";
    my $json; { local $/; $json = <$fh> };
    $fh->close();

    $this->{cfg} = decode_json($json);
}


sub _init_handler {
    my($args) = @_;
    my $gh = $args->{GHANDLE};

    $gh->_reload_config_file();

    my $user = $args->{USER};
    my $pass = $args->{PASS};
    $args->{HANDLE} = {
	ua => new LWP::UserAgent(),
	username => $user || '',
	password => $pass || '',
	resultsets => {},  # result sets, indexed by setname
    };

    $args->{IMP_ID} = '81';
    $args->{IMP_VER} = $Net::Z3950::FOLIO::VERSION;
    $args->{IMP_NAME} = 'z2folio gateway';

    my $cfg = $gh->{cfg};
    my $login = $cfg->{login};
    my $username = $user || $login->{username};
    my $password = $pass || $login->{password};
    _throw(1014, "credentials not supplied")
	if !defined $username || !defined $password;

    my $url = $cfg->{okapi}->{url} . '/bl-users/login';
    my $ua = new LWP::UserAgent();
    $ua->agent("z2folio $VERSION");
    my $req = new HTTP::Request(POST => $url);
    $req->header('x-okapi-tenant' => $cfg->{okapi}->{tenant});
    $req->header('Content-type' => 'application/json');
    $req->header('Accept' => 'application/json');
    $req->content(qq[{ "username": "$username", "password": "$password" }]);
    # warn "req=", $req->content();
    my $res = $ua->request($req);
    # warn "res=", $res->content();
    _throw(1014, $res->content())
	if !$res->is_success();
}


sub _throw {
    my($code, $addinfo, $diagset) = @_;
    $diagset ||= "Bib-1";

    # HTTP body for errors is sometimes a plain string, sometimes a JSON structure
    if ($addinfo =~ /^{/) {
	my $obj = decode_json($addinfo);
	$addinfo = $obj->{errorMessage};
    }

    die new ZOOM::Exception($code, undef, $addinfo, $diagset);
}


=head2 launch_server($label, @ARGV)

 $s2z->launch_server("someServer", @ARGV);

Launches the Net::Z3950::FOLIO server: this method never returns.  The
C<$label> string is used in logging, and the C<@ARGV> vector of
command-line arguments is interpreted by the YAZ backend server as
described at
https://software.indexdata.com/yaz/doc/server.invocation.html

=cut

sub launch_server {
    my $this = shift();
    my($label, @argv) = @_;

    return $this->{server}->launch_server($label, @argv);
}

=head1 SEE ALSO

=over 4

=item The C<z2folio> script conveniently launches the server.

=item C<Net::Z3950::FOLIO::Config> describes the configuration-file format.

=item The C<Net::Z3950::SimpleServer> handles the Z39.50 service.

=back

=head1 AUTHOR

Mike Taylor, E<lt>mike@indexdata.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by Index Data

This library is free software; you can redistribute it and/or modify
it under the terms of the Apache Licence 2.0: see the LICENSE file.

=cut
    
