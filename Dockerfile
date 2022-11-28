FROM perl:5
WORKDIR /usr/src/app
COPY . .
RUN cpan XML::Simple
RUN cpan -f MARC::File::XML # Tests fail
RUN cpan Cpanel::JSON::XS
RUN cpan LWP::UserAgent
RUN cpan LWP::Protocol::https
RUN cpan Mozilla::CA
RUN cpan MARC::Record
RUN cpan Net::Z3950::PQF
RUN cpan Unicode::Diacritic::Strip
RUN apt-get update
RUN apt-get -y install software-properties-common apt-transport-https ca-certificates
RUN wget https://ftp.indexdata.com/debian/indexdata.asc
RUN apt-key add indexdata.asc
RUN add-apt-repository 'deb http://ftp.indexdata.dk/debian bullseye main'
RUN apt-get update
RUN apt-get -y install yaz libyaz5-dev
RUN cpan -T -f Net::Z3950::ZOOM # Tests are very very slow AND sometimes time out
RUN cpan Net::Z3950::SimpleServer
EXPOSE 9997
# Since we often run under Kubernetes, which probes the port repeatedly, session-logging becomes noise, hence -v-session
CMD perl -I lib bin/z2folio -c etc/config -- -f etc/yazgfs.xml -v-session

