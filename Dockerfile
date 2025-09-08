FROM debian:bullseye as base

WORKDIR /usr/src/app

RUN  apt-get update \
  && apt-get install -y \
      apt-transport-https \
      ca-certificates \
      gnupg \
      software-properties-common \
      wget \
  && mkdir -p /etc/apt/keyrings \
  && wget https://ftp.indexdata.com/debian/indexdata.asc -O /etc/apt/keyrings/indexdata.asc \
  && echo 'deb [signed-by=/etc/apt/keyrings/indexdata.asc] http://ftp.indexdata.dk/debian bullseye main' > /etc/apt/sources.list.d/indexdata.list \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
      build-essential \
      gcc \
      libexpat1-dev \
      libyaz5-dev \
      yaz \
      libparams-validationcompiler-perl \
      libxml-simple-perl \
      libmarc-xml-perl \
      libcpanel-json-xs-perl \
      libwww-perl \
      liblwp-protocol-https-perl \
      libhttp-cookies-perl \
      libdatetime-perl \
      libmarc-record-perl \
      libtest-differences-perl \
      libxml-xslt-perl \
  && cpan Mozilla::CA \
  && cpan Unicode::Diacritic::Strip \
  && cpan Net::Z3950::PQF \
  && cpan Net::Z3950::ZOOM \
  && cpan Net::Z3950::SimpleServer 

FROM base as test
COPY Makefile.PL .
COPY etc/ etc/
COPY lib/ lib/
COPY t/ t/
RUN perl Makefile.PL \
 && make test

FROM base as runtime
RUN apt-get autoremove -y --purge \
      build-essential \
      gcc \
      gnupg \
      software-properties-common \
      wget \
 && rm -rf /var/lib/apt/lists/* /tmp/* /root/.cpanm/
COPY . .
EXPOSE 9997
# Since we often run under Kubernetes, which probes the port repeatedly, session-logging becomes noise, hence -v-session
CMD perl -I lib bin/z2folio -c etc/config -- -f etc/yazgfs.xml -v-session

