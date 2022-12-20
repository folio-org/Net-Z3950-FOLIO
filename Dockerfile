FROM perl:5-slim as base

WORKDIR /usr/src/app

RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y \
      apt-transport-https \
      build-essential \
      ca-certificates \
      gcc \
      gnupg \
      libexpat1-dev \
      software-properties-common \
      wget \
 && mkdir /etc/apt/keyrings \
 && wget https://ftp.indexdata.com/debian/indexdata.asc -O /etc/apt/keyrings/indexdata.asc \
 && echo 'deb [signed-by=/etc/apt/keyrings/indexdata.asc] http://ftp.indexdata.dk/debian bullseye main' > /etc/apt/sources.list.d/indexdata.list \
 && apt-get update \
 && apt-get install -y \
      libyaz5-dev \
      yaz \
 && cpan XML::Simple \
# Tests fail
 && cpan -f -i MARC::File::XML \
 && cpan Cpanel::JSON::XS \
 && cpan LWP::UserAgent \
 && cpan LWP::Protocol::https \
 && cpan Mozilla::CA \
 && cpan MARC::Record \
 && cpan Net::Z3950::PQF \
 && cpan Unicode::Diacritic::Strip \
# Tests are very very slow AND sometimes time out
 && cpan -T -f -i Net::Z3950::ZOOM \
 && cpan Net::Z3950::SimpleServer \
 && apt-get autoremove -y --purge \
      build-essential \
      gcc \
      gnupg \
      software-properties-common \
      wget \
 && rm -rf /var/lib/apt/lists/* /tmp/* /root/.cpanm/

FROM base as test
RUN cpan Test::Differences
COPY Makefile.PL .
COPY etc/ etc/
COPY lib/ lib/
COPY t/ t/
RUN perl Makefile.PL \
 && make test

FROM base as runtime
COPY . .
EXPOSE 9997
# Since we often run under Kubernetes, which probes the port repeatedly, session-logging becomes noise, hence -v-session
CMD perl -I lib bin/z2folio -c etc/config -- -f etc/yazgfs.xml -v-session

