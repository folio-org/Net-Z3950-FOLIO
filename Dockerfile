# ---- Base image -----------------------------------------------------------
FROM perl:5.38-slim AS base

# System packages commonly needed to build CPAN modules with XS/C dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      libssl-dev \
      libexpat1-dev \
      ca-certificates \
      && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# cpanminus makes dependency installs faster and quieter than plain cpan
RUN cpan App::cpanminus

# ---- Dependencies (cached layer) ------------------------------------------
# Copying only the manifest first means this layer is reused whenever your
# app code changes but your dependencies don't.
COPY cpanfile ./
RUN cpanm --notest --installdeps .

# ---- Application ------------------------------------------------------------
COPY . .


EXPOSE 9997
# Since we often run under Kubernetes, which probes the port repeatedly, session-logging becomes noise, hence -v-session
CMD ["perl", "-I", "lib", "bin/z2folio", "-c", "etc/config", "--", "-f", "etc/yazgfs.xml", "-v-session"]

