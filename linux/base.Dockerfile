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

RUN tdnf update -y --refresh && \
  bash ./tdnfinstall.sh \
  mariner-repos-extended && \
  tdnf repolist --refresh && \
  bash ./tdnfinstall.sh \
  nodejs18 \
  curl \
  xz \
  git \
  gpgme \
  gnupg2 \
  autoconf \
  ansible \
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
  dotnet-runtime-7.0 \
  dotnet-sdk-7.0 \
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
  msopenjdk-17 \
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
  msodbcsql18 \
  mssql-tools18 \
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
  zsh \
  maven3 \
  jx \
  cf-cli \
  golang \
  ruby \
  rubygems \
  packer \
  dcos-cli \
  ripgrep \
  helm \
  azcopy \
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
  xauth \
  screen \
  postgresql-devel \
  gh \
  redis \
  cpio \
  gettext && \
  tdnf clean all && \
  rm -rf /var/cache/tdnf/*

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_ENV production
ENV NODE_OPTIONS=--tls-cipher-list='ECDHE-RSA-AES128-GCM-SHA256:!RC4'

# Get latest version of Terraform.
# Customers require the latest version of Terraform.
RUN TF_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M ".current_version") \
  && wget -nv -O terraform.zip "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" \
  && wget -nv -O terraform.sha256 "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS" \
  && echo "$(grep "${TF_VERSION}_linux_amd64.zip" terraform.sha256 | awk '{print $1}')  terraform.zip" | sha256sum -c \
  && unzip terraform.zip \
  && mv terraform /usr/local/bin/terraform \
  && rm -f terraform.zip terraform.sha256 \
  && unset TF_VERSION

# Setup locale to en_US.utf8
RUN echo en_US UTF-8 >> /etc/locale.conf && locale-gen.sh
ENV LANG="en_US.utf8"

# Update pip and Install Service Fabric CLI
# Install mssql-scripter
RUN pip3 install --upgrade sfctl \
  && pip3 install --upgrade mssql-scripter \
  && rm -rf ~/.cache/pip/

# # BEGIN: Install Ansible in isolated Virtual Environment
COPY ./linux/ansible/ansible*  /usr/local/bin/
RUN chmod 755 /usr/local/bin/ansible* \
  && cd /opt \
  && virtualenv -p python3 ansible \
  && /bin/bash -c "source ansible/bin/activate && pip3 list --outdated --format=freeze | cut -d '=' -f1 | xargs -n1 pip3 install -U && pip3 install ansible && pip3 install pywinrm\>\=0\.2\.2 && deactivate" \
  && rm -rf ~/.local/share/virtualenv/ \
  && rm -rf ~/.cache/pip/ \
  && ansible-galaxy collection install azure.azcollection --force -p /usr/share/ansible/collections

# Install latest version of Istio
ENV ISTIO_ROOT /usr/local/istio-latest
RUN curl -sSL https://git.io/getLatestIstio | sh - \
  && mv $PWD/istio* $ISTIO_ROOT \
  && chmod -R 755 $ISTIO_ROOT
ENV PATH $PATH:$ISTIO_ROOT/bin

ENV GOROOT="/usr/lib/golang"
ENV PATH="$PATH:$GOROOT/bin:/opt/mssql-tools18/bin"

RUN gem install bundler --no-document --clear-sources --force \
  && bundle config set without 'development test' \
  && gem install rake --no-document --clear-sources --force \
  && gem install colorize --no-document --clear-sources --force \
  && gem install rspec --no-document --clear-sources --force \
  && rm -rf $(gem env gemdir)/cache/*.gem

ENV GEM_HOME=~/bundle
ENV BUNDLE_PATH=~/bundle
ENV PATH=$PATH:$GEM_HOME/bin:$BUNDLE_PATH/gems/bin

# PowerShell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL CloudShell
# don't tell users to upgrade, they can't
ENV POWERSHELL_UPDATECHECK Off

# Copy and run script to Install powershell modules
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && rm -rf ./powershell
