# base.Dockerfile contains components which are large and change less frequently. 
# tools.Dockerfile contains the smaller, more frequently-updated components. 

# Within Azure, the image layers
# built from this file are cached in a number of locations to speed up container startup time. A manual
# step needs to be performed to refresh these locations when the image changes. For this reason, we explicitly
# split the base and the tools docker files into separate files and base the tools file from a version
# of the base docker file stored in a container registry. This avoids accidentally introducing a change in
# the base image

# CBL-Mariner is an internal Linux distribution for Microsoft’s cloud infrastructure and edge products and services.
# CBL-Mariner is designed to provide a consistent platform for these devices and services and will enhance Microsoft’s
# ability to stay current on Linux updates.
# https://github.com/microsoft/CBL-Mariner
FROM mcr.microsoft.com/cbl-mariner/base/core:2.0

SHELL ["/bin/bash","-c"]

COPY linux/tdnfinstall.sh .

RUN tdnf repolist --refresh

RUN tdnf update -y && bash ./tdnfinstall.sh \
  mariner-repos-extended

RUN tdnf update -y && bash ./tdnfinstall.sh \
  curl \
  xz \
  git \
  gpgme \
  gnupg2

# Install nodejs
RUN tdnf update -y && bash ./tdnfinstall.sh \
  nodejs

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_VERSION 8.16.0
ENV NODE_ENV production
ENV NODE_OPTIONS=--tls-cipher-list='ECDHE-RSA-AES128-GCM-SHA256:!RC4'

RUN tdnf update -y && bash ./tdnfinstall.sh \
  autoconf \
  ansible \
# azure-functions-core-tools \
  bash-completion \
  build-essential \
  binutils \
  ca-certificates \
  ca-certificates-legacy \
  chkconfig \
  cifs-utils \
  curl \
  bind-utils \
  dos2unix \
  dotnet-runtime-6.0 \
  dotnet-sdk-6.0 \
  e2fsprogs \
  emacs \
  gawk \
  glibc-lang \
  glibc-i18n \
  grep \
  gzip \
  initscripts \
  iptables \
  iputils \
  msopenjdk-11 \
  jq \
  less \
  libffi \
  libffi-devel \
  libtool \
  lz4 \
  openssl \
  openssl-libs \
  openssl-devel \
  man-db \
  moby-cli \
  moby-engine \
  msodbcsql17 \
  mssql-tools \
  mysql \
  nano \
  net-tools \
  parallel \
  patch \
  pkg-config \
  postgresql-libs \
  postgresql \
  powershell \
  python3 \
  python3-pip \
  python3-virtualenv \
  python3-libs \
  python3-devel \
  puppet \
  rpm \
  rsync \
  sed \
  sudo \
  tar \
  tmux \
  unixODBC \
  unzip \
  util-linux \
  vim \
  wget \
  which \
  zip \
  zsh

# Install Maven
RUN tdnf update -y && bash ./tdnfinstall.sh maven

RUN tdnf clean all

# Additional packages required for Mariner to be closer to parity with CBL-D
RUN tdnf update -y && bash ./tdnfinstall.sh \
  apparmor-parser \
  apparmor-utils \
  cronie \
  ebtables-legacy \
  fakeroot \
  file \
  lsb-release \
  ncompress \
  pigz \
  psmisc \
  procps \
  shared-mime-info \
  sysstat \
  xauth

# Install azure-functions-core-tools
RUN wget -nv -O Azure.Functions.Cli.linux-x64.4.0.3971.zip https://github.com/Azure/azure-functions-core-tools/releases/download/4.0.3971/Azure.Functions.Cli.linux-x64.4.0.3971.zip \
  && unzip -d azure-functions-cli Azure.Functions.Cli.linux-x64.4.0.3971.zip \
  && chmod +x azure-functions-cli/func \
  && chmod +x azure-functions-cli/gozip \
  && mv azure-functions-cli /opt \
  && ln -sf /opt/azure-functions-cli/func /usr/bin/func \
  && ln -sf /opt/azure-functions-cli/gozip /usr/bin/gozip \
  && rm -r Azure.Functions.Cli.linux-x64.4.0.3971.zip

# Install Jenkins X client
RUN tdnf update -y && bash ./tdnfinstall.sh jx

# Install CloudFoundry CLI
RUN tdnf update -y && bash ./tdnfinstall.sh cf-cli


# Setup locale to en_US.utf8
RUN echo en_US UTF-8 >> /etc/locale.conf && locale-gen.sh
ENV LANG="en_US.utf8"

# Update pip and Install Service Fabric CLI
# Install mssql-scripter
RUN pip3 install --upgrade pip \
  && pip3 install --upgrade sfctl \
  && pip3 install --upgrade mssql-scripter

# Install Blobxfer and Batch-Shipyard in isolated virtualenvs
COPY ./linux/blobxfer /usr/local/bin
RUN chmod 755 /usr/local/bin/blobxfer \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 blobxfer \
  && /bin/bash -c "source blobxfer/bin/activate && pip3 install blobxfer && deactivate"

# Mariner distro required patch
# mariner-batch-shipyard.patch
# python3 is default in CBL-Mariner
# Some hacks to install.sh install-tweaked.sh
RUN curl -fSsL `curl -fSsL https://api.github.com/repos/Azure/batch-shipyard/releases/latest | grep tarball_url | cut -d'"' -f4` | tar -zxvpf - \
  && mkdir /opt/batch-shipyard \
  && mv Azure-batch-shipyard-*/* /opt/batch-shipyard \
  && rm -r Azure-batch-shipyard-* \
  && cd /opt/batch-shipyard \
  && sed 's/rhel/mariner/' < install.sh > install-tweaked.sh \
  && sed -i '/$PYTHON == /s/".*"/"python3"/' install-tweaked.sh \
  && sed -i 's/rsync $PYTHON_PKGS/rsync python3-devel/' install-tweaked.sh \
  && chmod +x ./install-tweaked.sh \
  && ./install-tweaked.sh -c \
  && /bin/bash -c "source cloudshell/bin/activate && python3 -m compileall -f /opt/batch-shipyard/shipyard.py /opt/batch-shipyard/convoy && deactivate" \
  && ln -sf /opt/batch-shipyard/shipyard /usr/local/bin/shipyard

# # BEGIN: Install Ansible in isolated Virtual Environment
COPY ./linux/ansible/ansible*  /usr/local/bin/
RUN chmod 755 /usr/local/bin/ansible* \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 ansible \
  && /bin/bash -c "source ansible/bin/activate && pip3 install ansible && pip3 install pywinrm\>\=0\.2\.2 && deactivate" \
  && ansible-galaxy collection install azure.azcollection -p /usr/share/ansible/collections

# Install latest version of Istio
ENV ISTIO_ROOT /usr/local/istio-latest
RUN curl -sSL https://git.io/getLatestIstio | sh - \
  && mv $PWD/istio* $ISTIO_ROOT \
  && chmod -R 755 $ISTIO_ROOT
ENV PATH $PATH:$ISTIO_ROOT/bin

# Install latest version of Linkerd
RUN export INSTALLROOT=/usr/local/linkerd \
  && mkdir -p $INSTALLROOT \
  && curl -sSL https://run.linkerd.io/install | sh - 
ENV PATH $PATH:/usr/local/linkerd/bin

# install go
RUN bash ./tdnfinstall.sh \
  golang

ENV GOROOT="/usr/lib/golang"
ENV PATH="$PATH:$GOROOT/bin:/opt/mssql-tools/bin"

# RUN export INSTALL_DIRECTORY="$GOROOT/bin" \
#   && curl -sSL https://raw.githubusercontent.com/golang/dep/master/install.sh | sh \
#   && ln -sf INSTALL_DIRECTORY/dep /usr/bin/dep \
#   && unset INSTALL_DIRECTORY

RUN tdnf update -y && bash ./tdnfinstall.sh \
  ruby \
  rubygems

RUN gem install bundler --version 1.16.4 --force \
  && gem install rake --version 12.3.0 --no-document --force \
  && gem install colorize --version 0.8.1 --no-document --force \
  && gem install rspec --version 3.7.0 --no-document --force

ENV GEM_HOME=~/bundle
ENV BUNDLE_PATH=~/bundle
ENV PATH=$PATH:$GEM_HOME/bin:$BUNDLE_PATH/gems/bin

# Download and Install the latest packer (AMD64)
RUN tdnf update -y && bash ./tdnfinstall.sh packer

# Install dcos
RUN tdnf update -y && bash ./tdnfinstall.sh dcos-cli

# PowerShell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL CloudShell
# don't tell users to upgrade, they can't
ENV POWERSHELL_UPDATECHECK Off

# Install ripgrep
RUN bash ./tdnfinstall.sh \
  ripgrep

# Install Helm
RUN bash ./tdnfinstall.sh \
  helm

# Copy and run the Draft install script, which fetches the latest release of Draft with
# optimizations for running inside cloud shell.
COPY ./linux/draftInstall.sh .
RUN bash ./draftInstall.sh && rm -f ./draftInstall.sh

# Install Yeoman Generator and predefined templates
RUN npm install -g yo \
  && npm install -g generator-az-terra-module

# Download and install AzCopy SCD of linux-x64
RUN tdnf update -y && bash ./tdnfinstall.sh azcopy


# Copy and run script to Install powershell modules
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && rm -rf ./powershell