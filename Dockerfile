FROM debian:trixie AS base

WORKDIR /usr/src/app

RUN  rm -rf /var/lib/apt/lists/* \
  && apt clean \
  && apt update \
  && apt install -y \
      apt-transport-https \
      ca-certificates \
      gnupg \
      wget

RUN mkdir -p /etc/apt/keyrings \
  && wget https://ftp.indexdata.com/debian/indexdata.asc -O /etc/apt/keyrings/indexdata.asc \
  && echo 'deb [signed-by=/etc/apt/keyrings/indexdata.asc] https://download.indexdata.com/debian trixie main' > /etc/apt/sources.list.d/indexdata.list \
  && rm -rf /var/lib/apt/lists/* \
  && apt clean \
  && apt update \
  # && apt upgrade -y \
  && apt install -y \
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
      libxml-xslt-perl 

RUN cpan Mozilla::CA \
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

