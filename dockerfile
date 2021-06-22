FROM python:3.6-slim-buster

# python and matlab version should match; see python/matab compatibility
#   - https://www.mathworks.com/content/dam/mathworks/mathworks-dot-com/support/sysreq/files/python-compatibility.pdf
# List of matlab mcr urls:
#   - https://github.com/pwighton/neurodocker/blob/20210513-fs-source-and-infant-merge/neurodocker/templates/matlabmcr.yaml
# Choosing:
#   - python 3.6
#   - Matlab MCR R2018b

# Enable all (including non-free) neurodebian repos,
# see:
#  - https://github.com/neurodebian/dockerfiles/blob/master/dockerfiles/buster-non-free/Dockerfile
# =========================================================================
# https://bugs.debian.org/830696 (apt uses gpgv by default in newer releases, rather than gpg)
RUN set -x \
	&& apt-get update \
	&& { \
		which gpg \
		|| apt-get install -y --no-install-recommends gnupg \
	; } \
# Ubuntu includes "gnupg" (not "gnupg2", but still 2.x), but not dirmngr, and gnupg 2.x requires dirmngr
# so, if we're not running gnupg 1.x, explicitly install dirmngr too
	&& { \
		gpg --version | grep -q '^gpg (GnuPG) 1\.' \
		|| apt-get install -y --no-install-recommends dirmngr \
	; } \
	&& rm -rf /var/lib/apt/lists/*
# apt-key is a bit finicky during "docker build" with gnupg 2.x, so install the repo key the same way debian-archive-keyring does (/etc/apt/trusted.gpg.d)
# this makes "apt-key list" output prettier too!
RUN set -x \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys DD95CC430502E37EF840ACEEA5D32F012649A5A9 \
	&& gpg --batch --export DD95CC430502E37EF840ACEEA5D32F012649A5A9 > /etc/apt/trusted.gpg.d/neurodebian.gpg \
	&& rm -rf "$GNUPGHOME" \
	&& apt-key list | grep neurodebian
RUN { \
	echo 'deb http://neuro.debian.net/debian buster main'; \
	echo 'deb http://neuro.debian.net/debian data main'; \
	echo '#deb-src http://neuro.debian.net/debian-devel buster main'; \
} > /etc/apt/sources.list.d/neurodebian.sources.list
# Minimalistic package to assist with freezing the APT configuration
# which would be coming from neurodebian repo.
# Also install and enable eatmydata to be used for all apt-get calls
# to speed up docker builds.
RUN set -x \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends neurodebian-freeze eatmydata \
	&& ln -s /usr/bin/eatmydata /usr/local/bin/apt-get \
	&& rm -rf /var/lib/apt/lists/*
RUN sed -i -e 's,main *$,main contrib non-free,g' /etc/apt/sources.list.d/neurodebian.sources.list /etc/apt/sources.list

# Download a few utils and pre-reqs
# for Matlab MCR
# =========================================================================
RUN apt-get -q update && \
    apt-get install -q -y --no-install-recommends \
      xorg \
      unzip \
      wget \
      curl

# Install matlab runtime
# https://github.com/demartis/matlab_runtime_docker/blob/master/R2020a-u0/Dockerfile
# =========================================================================
# Download the MCR from MathWorks site an install with -mode silent
RUN mkdir -p /install/mcr-install && \
    mkdir -p /opt/mcr && \
    cd /install/mcr-install && \
    wget --no-check-certificate -q https://ssd.mathworks.com/supportfiles/downloads/R2018b/deployment_files/R2018b/installers/glnxa64/MCR_R2018b_glnxa64_installer.zip && \
    unzip -q MCR_R2018b_glnxa64_installer.zip && \
    rm -f MMCR_R2018b_glnxa64_installer.zip && \
    ./install -destinationFolder /opt/mcr -agreeToLicense yes -mode silent

# Install debian packacges
# =========================================================================
RUN apt-get install -q -y \
      dcm2niix \
      dcmtk
      
# Install python packacges
# =========================================================================
RUN pip install --no-cache-dir --upgrade pip && \
     pip install --no-cache-dir \
       nibabel \
       pydicom \
       ecatdump

# Configure environment variables for MCR
# - setting `LD_LIBRABY_PATH` breaks pip3, so this is deferred
# =========================================================================
# ENV LD_LIBRARY_PATH /opt/mcr/v95/runtime/glnxa64:/opt/mcr/v95/bin/glnxa64:/opt/mcr/v95/sys/os/glnxa64:/opt/mcr/v95/#extern/bin/glnxa64
# ENV XAPPLRESDIR /etc/X11/app-defaults

# Cleanup omitted for now..
#    - apt-get clean
#    - rm -rf /var/lib/apt/lists/*`
#    - rm -rf /install
