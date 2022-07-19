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

# Use mariner-repos-microsoft-preview
# till msodbcsql and sql-tools publish to
# Mariner 2.0 prod Microsoft repo
RUN tdnf update -y && bash ./tdnfinstall.sh \
  mariner-repos-extended \
  mariner-repos-microsoft-preview

RUN tdnf update -y
RUN bash ./tdnfinstall.sh curl


RUN tdnf update -y && bash ./tdnfinstall.sh \
  curl \
  xz \
  git \
  gpgme \
  gnupg2

# Install nodejs
RUN tdnf update -y && bash ./tdnfinstall.sh \
  nodejs

COPY linux/mariner-microsoft-dotnetcore.repo /etc/yum.repos.d

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_VERSION 8.16.0
ENV NODE_ENV production
ENV NODE_OPTIONS=--tls-cipher-list='ECDHE-RSA-AES128-GCM-SHA256:!RC4'

RUN tdnf update -y && bash ./tdnfinstall.sh \
  autoconf \
  ansible \
  azure-cli \
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
# emacs \
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
# locales \
  man-db \
# maven \
  moby-cli \
  moby-engine \
  msodbcsql17 \
  mssql-tools \
  mysql \
  nano \
  net-tools \
  parallel \
  patch \
#  pkg-config \
  postgresql-libs \
  postgresql \
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
  zip \
  powershell \
  which
#  zsh

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
RUN curl -sSL https://github.com/jenkins-x/jx/releases/download/v1.3.107/jx-linux-amd64.tar.gz > jx.tar.gz \
  && echo f3e31816a310911c7b79a90281182a77d1ea1c9710b4e0bb29783b78cc99a961 jx.tar.gz | sha256sum -c \
  && tar -xf jx.tar.gz \
  && mv jx /usr/local/bin \
  && rm -rf jx.tar.gz

# Install CloudFoundry CLI
RUN wget -nv -O cf-cli_install.rpm https://cli.run.pivotal.io/stable?release=redhat64 \
  && rpm -ivh cf-cli_install.rpm \
  && rm -f cf-cli_install.rpm

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

RUN export INSTALL_DIRECTORY="$GOROOT/bin" \
  && curl -sSL https://raw.githubusercontent.com/golang/dep/master/install.sh | sh \
  && ln -sf INSTALL_DIRECTORY/dep /usr/bin/dep \
  && unset INSTALL_DIRECTORY

RUN gem update --system 3.3.3 \
  && gem install bundler --version 1.16.4 --force \
  && gem install rake --version 12.3.0 --no-document --force \
  && gem install colorize --version 0.8.1 --no-document --force \
  && gem install rspec --version 3.7.0 --no-document --force

ENV GEM_HOME=~/bundle
ENV BUNDLE_PATH=~/bundle
ENV PATH=$PATH:$GEM_HOME/bin:$BUNDLE_PATH/gems/bin

# Download and Install the latest packer (AMD64)
# RUN PACKER_VERSION=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r -M ".current_version") \
#   && wget -nv -O packer.zip https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip \
#   && wget -nv -O packer.sha256 https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS \
#   && wget -nv -O packer.sha256.sig https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS.sig \
#   && curl -s https://keybase.io/hashicorp/pgp_keys.asc | gpg --import \
#   && gpg --verify packer.sha256.sig packer.sha256 \
#   && echo $(grep -Po "[[:xdigit:]]{64}(?=\s+packer_${PACKER_VERSION}_linux_amd64.zip)" packer.sha256) packer.zip | sha256sum -c \
#   && unzip packer.zip \
#   && mv packer /usr/local/bin \
#   && chmod a+x /usr/local/bin/packer \
#   && rm -f packer packer.zip packer.sha256 packer.sha256.sig \
#   && unset PACKER_VERSION

# Install dcos
RUN wget -nv -O dcos https://downloads.dcos.io/binaries/cli/linux/x86-64/latest/dcos \
  && echo c79285f23525e21f71473649c742af14917c9da7ee2b707ccc27e92da4838ec4 dcos | sha256sum -c \
  && mv dcos /usr/local/bin \
  && chmod +x /usr/local/bin/dcos

# Work around to use 2.0 preview repo till we get
# PowerShell back in Mariner 2.0 prod repo
# Install PowerShell
# RUN tdnf -y install mariner-repos-preview

# RUN tdnf -y install powershell

# RUN tdnf -y remove mariner-repos-preview

RUN curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.2.3/powershell-7.2.3-linux-x64.tar.gz \
  && mkdir -p /opt/microsoft/powershell/7 \
  && tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 \
  && chmod +x /opt/microsoft/powershell/7/pwsh \
  && ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

# PowerShell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL CloudShell
# don't tell users to upgrade, they can't
ENV POWERSHELL_UPDATECHECK Off

# Install Chef Workstation
RUN wget -nv -O chef-workstation_x86_64.rpm https://packages.chef.io/files/stable/chef-workstation/22.2.807/el/8/chef-workstation-22.2.807-1.el8.x86_64.rpm \
 && echo 7b93c2826fca17aace7711c759e7cb0d4b7dd8498f9040f6a544c19ffc9ea679 chef-workstation_x86_64.rpm | sha256sum -c \
 && rpm -ivh chef-workstation_x86_64.rpm \
 && rm -f chef-workstation_x86_64.rpm

# Install ripgrep
RUN bash ./tdnfinstall.sh \
  ripgrep

# Install docker-machine
RUN curl -sSL https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-`uname -s`-`uname -m` > /tmp/docker-machine \
  && echo a7f7cbb842752b12123c5a5447d8039bf8dccf62ec2328853583e68eb4ffb097 /tmp/docker-machine | sha256sum -c \
  && chmod +x /tmp/docker-machine \
  && mv /tmp/docker-machine /usr/local/bin/docker-machine

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
RUN curl -sSL https://aka.ms/downloadazcopy-v10-linux -o azcopy-netcore_linux_x64.tar.gz \
  && mkdir azcopy \
  && tar xf azcopy-netcore_linux_x64.tar.gz -C azcopy --strip-components 1 \
  && mv azcopy/azcopy /usr/local/bin/azcopy \
  && chmod a+x /usr/local/bin/azcopy \
  && rm -f azcopy-netcore_linux_x64.tar.gz && rm -rf azcopy

# Copy and run script to Install powershell modules
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && rm -rf ./powershell