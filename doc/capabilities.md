# Capabilities of the FOLIO Z39.50 server

<!-- md2toc -l 2 capabilities.md -->
* [Overview](#overview)
* [Server deployment](#server-deployment)
    * [Running under Docker](#running-under-docker)
* [Z39.50](#z3950)
    * [Authentication](#authentication)
    * [Searching](#searching)
    * [Retrieval](#retrieval)
* [SRU](#sru)
    * [SRU searching](#sru-searching)
    * [SRU retrieval](#sru-retrieval)
* [SRW](#srw)
* [Appendix: developer notes](#appendix-developer-notes)



## Overview

The FOLIO Z39.50 server is [a FOLIO module](https://github.com/folio-org/Net-Z3950-FOLIO)) that provides access to the inventory information of a FOLIO tenant (bibliographic, holdings and item-level) by means of [the ANSI/NISO Z39.50 protocol](https://en.wikipedia.org/wiki/Z39.50) that is in widespread use in libraries and ILL solutions. Because it is based on [the YAZ Generic Frontend Server](https://software.indexdata.com/yaz/doc/server.html), is also supports [the REST-like SRU standard](https://www.loc.gov/standards/sru/) and [its SOAP-based equivalent SRW](https://www.loc.gov/standards/sru/companionSpecs/srw.html).

The server is implemented as a Perl module, [`Net::Z3950::FOLIO`](https://metacpan.org/pod/Net::Z3950::FOLIO), which is available on CPAN (the Perl software repository) like any other Perl module. (Perl was chosen because [the `Net::Z3950::SimpleServer` module](https://metacpan.org/pod/Net::Z3950::SimpleServer) makes it so much easier to implement a Z39.50 server than in other languages.)

The behaviour of the Z39.50 server is driven in part by [a configuration file](from-pod/Net-Z3950-FOLIO-Config.md). The server is distributed with [a standard configuration](../etc/config.json) which specifies things like how to determine what FOLIO servive to access, where to find the GraphQL query that extracts holdings information, and how Z39.50 queries are mapped into the CQL queries that FOLIO uses. It is possible to run the server with a different configuration, but this document describes capabilities such as the supported searches under the assumption that the standard configuration is in user. Standard disclaimers apply.



## Server deployment

Since the FOLIO Z39.50 server is strictly a client to the rest of FOLIO (it uses `mod-graphql` and `mod-source-record-storage`), it does not need to be installed as a part of FOLIO itself, and can run outside of a FOLIO installation provided it is furnished with the credentials for a user with all necessary permissions. However, it will typically be run as a FOLIO module itself, described by the provided [module descriptor](../ModuleDescriptor.json) and packaged to run as a contained by the provided [Docker file](../Dockerfile) (see [below](#running-under-docker)).

When using the standard configuration file (see above), it is necessary to provide four pieces of information as environment variables:

* `OKAPI_URL` &mdash; the URL of the Okapi service to contact for GraphQL and SRS services, i.e. the FOLIO whose inventory is to be accessed.
* `OKAPI_TENANT` &mdash; the tenant to use on that Okapi URL. (This is presently hardwired at configuration time, but in future will be taken from the Z39.50 database name.)
* `OKAPI_USER` &mdash; the user to act as: note that this user will need permissions to access GraphQL, inventory and SRS.
* `OKAPI_PASSWORD` &mdash; the password used to authenticate as the nominated user.

For example:

	env OKAPI_URL=https://indexdata-test-okapi.folio.indexdata.com \
	    OKAPI_TENANT=indexdata \
	    OKAPI_USER=id_admin \
	    OKAPI_PASSWORD=swordfish \
	    perl -I lib bin/z2folio -c etc/config.json -- -f etc/yazgfs.xml

By default, the server listens on port 9997 (using the same port for all three supported protocols). If necessary, this can be changed by editing [the YAZ GFS configuration file](../etc/yazgfs.xml): see [the documentation](https://software.indexdata.com/yaz/doc/server.vhosts.html) for details.

### Running under Docker

FOLIO modules are typically run as Docker containers. When running the Z39.50 server in this fashion, it is necessary to inject environment variables into the container to specify the FOLIO URL, tenant, etc. This is most conveniently done using Docker's `-e NAME=VALUE` command-line option:

	docker run -it --rm -p9997:9997 \
		-e OKAPI_URL=https://indexdata-test-okapi.folio.indexdata.com \
		-e OKAPI_TENANT=indexdata \
		-e OKAPI_USER=id_admin \
		-e OKAPI_PASSWORD=swordfish \
		--name run-zfolio zfolio

Note that this invocation also plumbs the container-internal TCP port 9997, where the server listens, to the host system's port 9997.

If it is necessary to provide a different main configuration file or YAZ GFS configuration, these can be injected into the Docker container as "volumes" using [the `--volume=hostFile:containerFile` command-line option](https://docs.docker.com/engine/reference/run/#volume-shared-filesystems):

	docker run --volume=localConfig.json:etc/config.json



## Z39.50

As a Z39.50 server, the software supports the following services:

* [Init](https://www.loc.gov/z3950/agency/markup/04.html#3.2.1.1), including authentication and diagnostics (see [below](#authentication))
* [Search](https://www.loc.gov/z3950/agency/markup/04.html#3.2.2.1), with support for Bath profile queries (see [below](#searching))
* [Present](https://www.loc.gov/z3950/agency/markup/04.html#3.2.3.1) in USMARC, OPAC and XML formats (see [below](#retrieval))
* [Delete](https://www.loc.gov/z3950/agency/markup/05.html#3.2.4.1)
* [Trigger Resource Control](https://www.loc.gov/z3950/agency/markup/05.html#3.2.6.2)

Support for
[Sort](https://www.loc.gov/z3950/agency/markup/05.html#3.2.7.1)
is incomplete; both sorting and
[Scan](https://www.loc.gov/z3950/agency/markup/05.html#3.2.8.1)
are possible features in future versions.
There are presently no plans to support
[Extended Services](https://www.loc.gov/z3950/agency/markup/06.html#3.2.9.1),
[Explain](https://www.loc.gov/z3950/agency/markup/07.html#3.2.10)
or the unloved
[Close](https://www.loc.gov/z3950/agency/markup/08.html#3.2.11.1)
service.

(The
[Segment](https://www.loc.gov/z3950/agency/markup/04.html#3.2.3.2),
[Access Control](https://www.loc.gov/z3950/agency/markup/05.html#3.2.5.1),
[Resource Control](https://www.loc.gov/z3950/agency/markup/05.html#3.2.6.1),
and
[Resource-report](https://www.loc.gov/z3950/agency/markup/05.html#3.2.6.3)
services are not supported by the underlying SimpleServer library, so there is no realistic prospect of supporting them in the FOLIO server; but there is no evidence that any client exists that can use these services.)


### Authentication

If no default username and password are specified in the server's configuration, or if the user has reason to want to authenticate onto FOLIO as a differet user, these tokens can be provided in the Z39.50 Init request as a single "open" authentication string, separated by a forward slash (`/`). (In the YAZ command-line client, this can be done using the command `auth user/pass`. If authentication onto FOLIO is rejected &mdash; because of incorrect tokens or for any other reason &mdash; the Z39.50 server will reject the Init request, with the response including a diagnostic `otherInfo` unit.

Here's how that looks using the YAZ command-line client:

	Z> open @:9997
	Connecting...OK.
	Sent initrequest.
	Connection rejected by v3 target.
	ID     : 81/81
	Name   : z2folio gateway/GFS/YAZ
	Version: 1.2/5.30.3 2af59bc45cf4508d5c84f350ee99804c4354b3b3
	Init response contains 1 otherInfo unit:
	  1: otherInfo unit contains 1 diagnostic:
	    1: code=1014 (Init/AC: Authentication System error),
		addinfo='Password does not match'
	Z> auth mike/swordfish
	Authentication set to Open (mike/swordfish)
	Z> open @:9997
	Connecting...OK.
	Sent initrequest.
	Connection accepted by v3 target.
	ID     : 81/81
	Name   : z2folio gateway/GFS/YAZ
	Version: 1.2/5.30.3 2af59bc45cf4508d5c84f350ee99804c4354b3b3
	Options: search present delSet triggerResourceCtrl sort namedResultSets
	Z> 

Usually, the Z39.50 server will be configured to default to logging in as a specied user (see the discussion of `OKAPI_USER` and `OKAPI_PASSWORD` [above](#server-deployment)).


### Searching

XXX


### Retrieval

XXX



## SRU

XXX sorting _is_ supported, unlike Z39.50!

XXX When building new clients to integrate with this server, SRU may be easier to use then Z39.50 because it is defined as in terms of XML and HTTP, a format and protocol for which there are many libriaries available in many languages.


### SRU searching

XXX


### SRU retrieval

XXX



## SRW

XXX



## Appendix: developer notes

XXX version number is two-part in Perl, and always x.y.0 in FOLIO.

XXX Release process involves updating version number in FOLIO.pm, ModuleDescriptor.json and possibly Changes.md



