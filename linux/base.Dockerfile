FROM mcr.microsoft.com/cbl-mariner/base/core:2.0
LABEL org.opencontainers.image.source="https://github.com/Azure/CloudShell"

SHELL ["/bin/bash","-c"]
COPY linux/tdnfinstall.sh .

RUN tdnf update -y --refresh && \
  bash ./tdnfinstall.sh \
  mariner-repos-extended && \
  tdnf repolist --refresh && \
  bash ./tdnfinstall.sh \
  nodejs18 \
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
  dotnet-runtime-8.0 \
  dotnet-sdk-8.0 \
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
  mariadb \
  openssl \
  openssl-libs \
  openssl-devel \
  man-db \
  msodbcsql18 \
  mssql-tools18 \
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
  # Install latest Azure CLI package. CLI team drops latest (pre-release) package here prior to public release
  # We don't support using this location elsewhere - it may be removed or updated without notice
  wget https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-mariner2.0.rpm && \
  tdnf install -y ./azure-cli-latest-mariner2.0.rpm && \
  rm azure-cli-latest-mariner2.0.rpm && \
  #
  # Note: These set of cleanup steps should always be the last ones in this RUN statement.
  tdnf clean all && \
  rm -rf /var/cache/tdnf/* && \
  rm /var/opt/apache-maven/lib/guava-25.1-android.jar

# Install any Azure CLI extensions that should be included by default.
RUN az extension add --system --name ai-examples -y && \
  az extension add --system --name ssh -y && \
  az extension add --system --name ml -y && \
  #
  # Install kubectl
  az aks install-cli

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

# # BEGIN: Install Ansible in isolated Virtual Environment
COPY ./linux/ansible/ansible*  /usr/local/bin/
RUN chmod 755 /usr/local/bin/ansible* \
  && cd /opt \
  && virtualenv -p python3 ansible \
  && /bin/bash -c "source ansible/bin/activate && pip3 list --outdated --format=freeze | cut -d '=' -f1 | xargs -n1 pip3 install -U && pip3 install ansible && pip3 install pywinrm\>\=0\.2\.2 && deactivate" \
  && rm -rf ~/.local/share/virtualenv/ \
  && rm -rf ~/.cache/pip/ \
  && ansible-galaxy collection install azure.azcollection --force -p /usr/share/ansible/collections \
  # Temp: Proper fix is to use regular python for Ansible.
  && mkdir -p /usr/share/ansible/collections/ansible_collections/azure/azcollection/ \
  && wget -nv -q -O /usr/share/ansible/collections/ansible_collections/azure/azcollection/requirements.txt https://raw.githubusercontent.com/ansible-collections/azure/dev/requirements.txt \
  && /opt/ansible/bin/python -m pip install -r /usr/share/ansible/collections/ansible_collections/azure/azcollection/requirements.txt


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

# Install vscode
RUN wget -nv -O vscode.tar.gz "https://code.visualstudio.com/sha/download?build=insider&os=cli-alpine-x64" \
  && tar -xvzf vscode.tar.gz \
  && mv ./code-insiders /bin/vscode \
  && rm vscode.tar.gz

# Install azure-developer-cli (azd)
ENV AZD_IN_CLOUDSHELL=1 \
  AZD_SKIP_UPDATE_CHECK=1
RUN curl -fsSL https://aka.ms/install-azd.sh | bash && \
  #
  # Install Office 365 CLI templates
  #
  npm install -q -g @pnp/cli-microsoft365 && \
  #
  # Install Bicep CLI
  #
  curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
  && chmod +x ./bicep \
  && mv ./bicep /usr/local/bin/bicep \
  && bicep --help && \
  #
  # Add soft links
  #
  ln -s /usr/bin/python3 /usr/bin/python && \
  ln -s /usr/bin/node /usr/bin/nodejs

RUN mkdir -p /usr/cloudshell
WORKDIR /usr/cloudshell

# Powershell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL=CloudShell \
  # don't tell users to upgrade, they can't
  POWERSHELL_UPDATECHECK=Off

# Copy and run script to install Powershell modules and setup Powershell machine profile
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && \
  cp -r ./powershell/PSCloudShellUtility /usr/local/share/powershell/Modules/PSCloudShellUtility/ && \
  /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Top && \
  # Install Powershell warmup script
  mkdir -p linux/powershell && \
  cp powershell/Invoke-PreparePowerShell.ps1 linux/powershell/Invoke-PreparePowerShell.ps1 && \
  rm -rf ./powershell

# Remove su so users don't have su access by default.
RUN rm -f ./linux/Dockerfile && rm -f /bin/su

# Add user's home directories to PATH at the front so they can install tools which
# override defaults
# Add dotnet tools to PATH so users can install a tool using dotnet tools and can execute that command from any directory
ENV PATH ~/.local/bin:~/bin:~/.dotnet/tools:$PATH

ENV AZURE_CLIENTS_SHOW_SECRETS_WARNING True

# Set AZUREPS_HOST_ENVIRONMENT
ENV AZUREPS_HOST_ENVIRONMENT cloud-shell/1.0
