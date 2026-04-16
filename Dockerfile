FROM debian:trixie AS base

WORKDIR /usr/src/app

RUN  apt-get update \
  && apt-get install -y \
      apt-transport-https \
      ca-certificates \
      gnupg \
      wget \
  && apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y \
      build-essential \
      gcc \
      libexpat1-dev \
      libyaz-dev \
      yaz \
      pkg-config \
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

FROM base AS test
COPY Makefile.PL .
COPY etc/ etc/
COPY lib/ lib/
COPY t/ t/
RUN perl Makefile.PL \
 && make test

FROM base AS runtime
RUN apt-get autoremove -y --purge \
      build-essential \
      gcc \
      gnupg \
      wget \
 && rm -rf /var/lib/apt/lists/* /tmp/* /root/.cpanm/
COPY . .
EXPOSE 9997
# Since we often run under Kubernetes, which probes the port repeatedly, session-logging becomes noise, hence -v-session
CMD ["perl", "-I", "lib", "bin/z2folio", "-c", "etc/config", "--", "-f", "etc/yazgfs.xml", "-v-session"]

