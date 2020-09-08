# Revision history for Perl extension Net::Z3950::FOLIO.

## 0.01  Thu Dec  6 13:03:26 2018
* Original version; created by `h2xs -X --name=Net::Z3950::FOLIO --compat-version=5.8.0 --omit-constant --skip-exporter --skip-ppport`

## To do

* Write code to hand-transform FOLIO holidings-and-items XML into YAZ's format.
* Configure `etc/yazgfs.xml` to return OPAC records based on this XML.
* Write a non-trivial version of `etc/folio2marcxml.xsl`.
* Determine FOLIO tenant from database name (and postpone initialisation and authentication until we know that).
* Write tests (ensuring query and record formats have not changed).
* Read FOLIO edge-module specifications and make whatever changes they require.
* Write `Dockerfile`.

## "Edge modules"

@Jakub writes:
Guys, “edge” module architecture is mixed up with the (Java) implementation, see https://github.com/folio-org/edge-common
GitHubGitHub
But certain concepts should be transferable — all edge module right now assume that a dedicated user is installed in the system (so-called institutional user) and the edge module connects to FOLIO as that particular user. That user has permissions specifically crafted to the APIs the module should be able to access in FOLIO (I would assume that in the Z server context it is selected mod-inventory APIs, right MIke, though it might be more complex because of graphql?)
The other thing is that edge module comes with a MD that lists the FOLIO API dependencies — think of it as a virtual package (edited)
