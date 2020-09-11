FROM perl:5.20
WORKDIR /usr/src/app
COPY . .
RUN cpan XML::Simple
RUN cpan -f MARC::File::XML # Tests fail
RUN cpan Cpanel::JSON::XS
RUN cpan LWP::UserAgent
RUN cpan LWP::Protocol::https
RUN apt-get update
RUN apt-get -y install software-properties-common
RUN wget http://ftp.indexdata.dk/debian/indexdata.asc
RUN apt-key add indexdata.asc
RUN add-apt-repository 'deb http://ftp.indexdata.dk/debian jessie main'
RUN apt-get update
RUN apt-get -y install yaz libyaz5-dev
RUN cpan -T -f Net::Z3950::ZOOM # Tests are very very slow AND sometimes time out
RUN cpan Net::Z3950::SimpleServer
EXPOSE 9997
CMD perl -I lib bin/z2folio -c etc/config.json -- -f etc/yazgfs.xml
