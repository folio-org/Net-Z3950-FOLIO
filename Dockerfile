# ---- Base image ---------
FROM debian:trixie AS base

WORKDIR /app

# System packages commonly needed to build CPAN modules with XS/C dependencies
RUN   apt-get update && apt-get install -y \
      apt-transport-https \
      ca-certificates \
      gnupg \
      wget \
  && apt-get update && apt-get upgrade -y && apt-get install -y \
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
      libxml-xslt-perl

# cpanminus makes dependency installs faster and quieter than plain cpan
COPY cpanfile ./
RUN cpan App::cpanminus && cpanm --notest --installdeps .

# ----- Test -------
FROM base AS test

COPY Makefile.PL .
COPY etc/ etc/
COPY lib/ lib/
COPY t/ t/
RUN perl Makefile.PL && make test

# ---- Runtime -------
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

