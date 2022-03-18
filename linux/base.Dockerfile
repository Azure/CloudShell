# base.Dockerfile contains components which are large and change less frequently. 
# tools.Dockerfile contains the smaller, more frequently-updated components. 

# Within Azure, the image layers
# built from this file are cached in a number of locations to speed up container startup time. A manual
# step needs to be performed to refresh these locations when the image changes. For this reason, we explicitly
# split the base and the tools docker files into separate files and base the tools file from a version
# of the base docker file stored in a container registry. This avoids accidentally introducing a change in
# the base image

# CBL-D (Common Base Linux - Delridge) is not a standalone Linux distribution, but tracks Debian very closely. 
# The primary difference between Debian and CBL-D is that Microsoft compiles all the packages 
# included in the CBL-D repository internally. 
# This helps guard against supply chain attacks (https://en.wikipedia.org/wiki/Supply_chain_attack). 
# 'Quinault' is almost identical to Debian 10 (Buster) 
FROM sbidprod.azurecr.io/quinault

SHELL ["/bin/bash","-c"] 

COPY linux/aptinstall.sh .

# The universe repository is only currently required for Python2
RUN echo "deb https://packages.microsoft.com/repos/cbl-d quinault-universe main" >> /etc/apt/sources.list

RUN apt-get update && bash ./aptinstall.sh \
  apt-transport-https \
  curl \
  xz-utils \
  git \
  gpg

RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > postgresql.gpg \
  && mv postgresql.gpg /etc/apt/trusted.gpg.d/postgresql.gpg \
  && sh -c 'echo "deb [arch=amd64] https://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/postgresql.list'

# BEGIN: provision nodejs

# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
  4ED778F539E3634C779C87C6D7062848A1AB005C \
  71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
  77984A986EBC2AA786BC0F66B01FBB92821C587A \
  8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
  94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
  A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
  B9AE9905FFD7803F25714661B63B535A4C206CA9 \
  B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
  FD3A5288F042B6850C66B31F09FE44734EB7990E \
  ; do \
  gpg --keyserver pool.sks-keyservers.net --recv-keys "$key" || \
  gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" || \
  gpg --keyserver pgp.mit.edu --recv-keys "$key" || \
  gpg --keyserver keyserver.pgp.com --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL warn
ENV NODE_VERSION 8.16.0
ENV NODE_ENV production

RUN curl -sSLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -sSLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs
# END: provision nodejs

# Azure CLI keys
RUN echo "deb https://apt-mo.trafficmanager.net/repos/azure-cli/ buster main" | tee /etc/apt/sources.list.d/azure-cli.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B02C46DF417A0893

RUN curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

RUN apt-get update && bash ./aptinstall.sh \
  autoconf \
  azure-functions-core-tools \
  bash-completion \
  build-essential \
  cifs-utils \
  dnsutils \
  dos2unix \
  dotnet-runtime-3.1 \
  dotnet-sdk-3.1 \
  emacs \
  iptables \
  iputils-ping \
  java-common \
  jq \
  less \
  libffi-dev \
  libssl-dev \
  libpq-dev \
  locales \
  man-db \
  maven \
  moby-cli \
  moby-engine \
  msodbcsql17 \ 
  mssql-tools \
  default-mysql-client \
  nano \
  net-tools \
  parallel \
  postgresql-client \
  python3 \
  python3-pip \
  python3-venv \
  python3.7-dev \
  puppet \
  rsync \
  ssl-cert \
  software-properties-common \
  tmux \
  unixodbc-dev \
  unzip \
  vim \
  wget \
  zip \
  zsh

# Install the deprecated Python2 packages. Will be removed in a future update
RUN bash ./aptinstall.sh \
  python-dev \
  python \
  python-pip

# Install Jenkins X client
RUN curl -sSL https://github.com/jenkins-x/jx/releases/download/v1.3.107/jx-linux-amd64.tar.gz > jx.tar.gz \
  && echo f3e31816a310911c7b79a90281182a77d1ea1c9710b4e0bb29783b78cc99a961 jx.tar.gz | sha256sum -c \
  && tar -xf jx.tar.gz \
  && mv jx /usr/local/bin \
  && rm -rf jx.tar.gz

# Install CloudFoundry CLI
RUN wget -nv -O cf-cli_install.deb https://cli.run.pivotal.io/stable?release=debian64 \
  && dpkg -i cf-cli_install.deb \
  && apt-get install -f \
  && rm -f cf-cli_install.deb

# Setup locale to en_US.utf8
RUN echo en_US UTF-8 >> /etc/locale.gen && locale-gen
ENV LANG="en_US.utf8"

# Redirect python3 as default and path pip2
# Update pip and Install Service Fabric CLI
# Install mssql-scripter
RUN ln -s -f /usr/bin/python3 /usr/bin/python \
  && sed -i 's/usr\/bin\/python/usr\/bin\/python2/' /usr/bin/pip2 \
  && pip2 install --upgrade pip && pip3 install --upgrade pip \
  && pip3 install --upgrade sfctl \
  && pip3 install mssql-scripter

# Install Blobxfer and Batch-Shipyard in isolated virtualenvs
COPY ./linux/blobxfer /usr/local/bin
RUN chmod 755 /usr/local/bin/blobxfer \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 blobxfer \
  && /bin/bash -c "source blobxfer/bin/activate && pip3 install blobxfer && deactivate"

# Some hacks to install.sh
# update os-release to pretend we are Debian
# depend on python3.7-dev instead of python3-dev (cbl-d bug?)
RUN curl -fSsL `curl -fSsL https://api.github.com/repos/Azure/batch-shipyard/releases/latest | grep tarball_url | cut -d'"' -f4` | tar -zxvpf - \
  && mv Azure-batch-shipyard-* /opt/batch-shipyard \
  && cd /opt/batch-shipyard \
  && cp /etc/os-release /etc/os-release.bak \
  && sed 's/ID=cbld/ID=debian/' < /etc/os-release.bak \
  && sed 's/ID=cbld/ID=debian/' < /etc/os-release.bak  > /etc/os-release \
  && sed 's/PYTHON_PKGS="libpython3-dev python3-dev"/PYTHON_PKGS="libpython3.7-dev python3.7-dev"/' < install.sh > install-tweaked.sh \
  && chmod +x ./install-tweaked.sh \
  && ./install-tweaked.sh -c \
  && /bin/bash -c "source cloudshell/bin/activate && python3 -m compileall -f /opt/batch-shipyard/shipyard.py /opt/batch-shipyard/convoy && deactivate" \
  && ln -sf /opt/batch-shipyard/shipyard /usr/local/bin/shipyard \
  && cp /etc/os-release.bak /etc/os-release


# # BEGIN: Install Ansible in isolated Virtual Environment
COPY ./linux/ansible/ansible*  /usr/local/bin/
RUN chmod 755 /usr/local/bin/ansible* \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 ansible \
  && /bin/bash -c "source ansible/bin/activate && pip3 install ansible && pip3 install pywinrm>=0.2.2 && deactivate" \
  && ansible-galaxy collection install azure.azcollection

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

# Install Puppet-Bolt
RUN wget -nv -O puppet-tools.deb https://apt.puppet.com/puppet-tools-release-buster.deb \
  && dpkg -i puppet-tools.deb \
  && apt-get update \
  && bash ./aptinstall.sh puppet-bolt \
  && rm -f puppet-tools.deb

# install go
RUN wget -nv -O go.tar.gz https://dl.google.com/go/go1.13.7.linux-amd64.tar.gz \
  && echo b3dd4bd781a0271b33168e627f7f43886b4c5d1c794a4015abf34e99c6526ca3 go.tar.gz | sha256sum -c \
  && tar -xf go.tar.gz \
  && mv go /usr/local \
  && rm -f go.tar.gz

ENV GOROOT="/usr/local/go"
ENV PATH="$PATH:$GOROOT/bin:/opt/mssql-tools/bin"

RUN export INSTALL_DIRECTORY="$GOROOT/bin" \
  && curl -sSL https://raw.githubusercontent.com/golang/dep/master/install.sh | sh \
  && unset INSTALL_DIRECTORY

RUN gem update --system 2.7.7 \
  && gem install bundler --version 1.16.4 --force \
  && gem install rake --version 12.3.0 --no-document --force \
  && gem install colorize --version 0.8.1 --no-document --force \
  && gem install rspec --version 3.7.0 --no-document --force \
  && rm -r /root/.gem/

ENV GEM_HOME=~/bundle
ENV BUNDLE_PATH=~/bundle
ENV PATH=$PATH:$GEM_HOME/bin:$BUNDLE_PATH/gems/bin

# Download and Install the latest packer (AMD64)
RUN PACKER_VERSION=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r -M ".current_version") \
  && wget -nv -O packer.zip https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip \
  && wget -nv -O packer.sha256 https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS \
  && wget -nv -O packer.sha256.sig https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_SHA256SUMS.sig \
  && curl -s https://keybase.io/hashicorp/pgp_keys.asc | gpg --import \
  && gpg --verify packer.sha256.sig packer.sha256 \
  && echo $(grep -Po "[[:xdigit:]]{64}(?=\s+packer_${PACKER_VERSION}_linux_amd64.zip)" packer.sha256) packer.zip | sha256sum -c \
  && unzip packer.zip \
  && mv packer /usr/local/bin \
  && chmod a+x /usr/local/bin/packer \
  && rm -f packer packer.zip packer.sha256 packer.sha256.sig \
  && unset PACKER_VERSION

# Install dcos
RUN wget -nv -O dcos https://downloads.dcos.io/binaries/cli/linux/x86-64/latest/dcos \
  && echo c79285f23525e21f71473649c742af14917c9da7ee2b707ccc27e92da4838ec4 dcos | sha256sum -c \
  && mv dcos /usr/local/bin \
  && chmod +x /usr/local/bin/dcos

# Install PowerShell
# Register the Microsoft repository GPG keys and Install PowerShell Core
RUN wget -nv -q https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && apt update \
  && bash ./aptinstall.sh powershell 

# Install .NET 6
# The Microsoft repository GPG keys are already registered in previous step (Install PowerShell)
# Install .NET 6 runtime, ASP.NET Core runtime and SDK using apt-get
RUN bash ./aptinstall.sh \
  dotnet-runtime-6.0 \
  dotnet-sdk-6.0

# PowerShell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL CloudShell
# don't tell users to upgrade, they can't
ENV POWERSHELL_UPDATECHECK Off

# Install Chef Workstation
RUN wget -nv -O chef-workstation_amd64.deb https://packages.chef.io/files/stable/chef-workstation/20.9.158/debian/10/chef-workstation_20.9.158-1_amd64.deb \
  && echo af67dfbf705959eb0e4d4b663142a66b2a220b33aefc54b83197ad3f535b69ba chef-workstation_amd64.deb | sha256sum -c \
  && dpkg -i chef-workstation_amd64.deb \
  && rm -f chef-workstation_amd64.deb

# Install ripgrep
RUN curl -sSLO https://github.com/BurntSushi/ripgrep/releases/download/12.1.1/ripgrep_12.1.1_amd64.deb \
  && echo 18ef498312073da55d2f2f65c6a906085c68368a23c9a45a87fcb8539be96608 ripgrep_12.1.1_amd64.deb | sha256sum -c \
  && dpkg -i ripgrep_12.1.1_amd64.deb \
  && rm -f ripgrep_12.1.1_amd64.deb

# Install docker-machine
RUN curl -sSL https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-`uname -s`-`uname -m` > /tmp/docker-machine \
  && echo a7f7cbb842752b12123c5a5447d8039bf8dccf62ec2328853583e68eb4ffb097 /tmp/docker-machine | sha256sum -c \
  && chmod +x /tmp/docker-machine \
  && mv /tmp/docker-machine /usr/local/bin/docker-machine

# Copy and run the Helm install script, which fetches the latest release of Helm.
COPY ./linux/helmInstall.sh .
RUN bash ./helmInstall.sh && rm -f ./helmInstall.sh

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
