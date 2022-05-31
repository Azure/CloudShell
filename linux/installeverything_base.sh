#!/bin/bash
start=`date +%s`

# PostGresSQL
apt-get update
curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /postgresql.gpg \
  && mv /postgresql.gpg /etc/apt/trusted.gpg.d/postgresql.gpg \
  && sh -c 'echo "deb [arch=amd64] https://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/postgresql.list'

# Install .NET 6
# The Microsoft repository GPG keys are already registered in previous step (Install PowerShell)
# Install .NET 6 runtime, ASP.NET Core runtime and SDK using apt-get

curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
bash /aptinstall.sh \
  dotnet-runtime-6.0 \
  dotnet-sdk-6.0 \
  autoconf \
  azure-functions-core-tools \
  bash-completion \
  build-essential \
  cifs-utils \
  dnsutils \
  dos2unix \
  emacs \
  iptables \
  iputils-ping \
  java-common \
  less \
  libffi-dev \
  libssl-dev \
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
  python3-venv \
  python3.7-dev \
  python-dev \
  puppet \
  rsync \
  ssl-cert \
  software-properties-common \
  tmux \
  unixodbc-dev \
  unzip \
  vim

# Install Maven from Apache mirrors directly and override just the maven installer from CBL-D
# RUN bash /installMaven.sh
# ENV M2_HOME /opt/maven
# ENV MAVEN_HOME /opt/maven
# ENV PATH $PATH:/opt/maven/bin
# ENV JAVA_HOME /usr/lib/jvm/msopenjdk-17-amd64

# Install Jenkins X client
curl -sSL https://github.com/jenkins-x/jx/releases/download/v1.3.107/jx-linux-amd64.tar.gz > jx.tar.gz \
  && echo f3e31816a310911c7b79a90281182a77d1ea1c9710b4e0bb29783b78cc99a961 jx.tar.gz | sha256sum -c \
  && tar -xf jx.tar.gz \
  && mv jx /usr/local/bin \
  && rm -rf jx.tar.gz

# # Install CloudFoundry CLI
wget -nv -O cf-cli_install.deb https://cli.run.pivotal.io/stable?release=debian64 \
  && dpkg -i cf-cli_install.deb \
  && apt-get install -f \
  && rm -f cf-cli_install.deb

ln -s -f /usr/bin/python3 /usr/bin/python \
  && sed -i 's/usr\/bin\/python/usr\/bin\/python2/' /usr/bin/pip2 \
  && pip2 install --upgrade pip && pip3 install --upgrade pip \
  && pip3 install --upgrade sfctl \
  && pip3 install mssql-scripter

# # Install the deprecated Python2 packages. Will be removed in a future update
# bash ./aptinstall.sh \
#   python-dev \
#   python \
#   python-pip

# #Install Blobxfer and Batch-Shipyard in isolated virtualenvs
cp /usr/cloudshell/linux/blobxfer /usr/local/bin
chmod 755 /usr/local/bin/blobxfer \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 blobxfer \
  && /bin/bash -c "source blobxfer/bin/activate && pip3 install blobxfer && deactivate"

# # Some hacks to install.sh
# # update os-release to pretend we are Debian
# # depend on python3.7-dev instead of python3-dev (cbl-d bug?)
curl -fSsL `curl -fSsL https://api.github.com/repos/Azure/batch-shipyard/releases/latest | grep tarball_url | cut -d'"' -f4` | tar -zxvpf - \
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


# # # BEGIN: Install Ansible in isolated Virtual Environment
cp /usr/cloudshell/linux/ansible/ansible*  /usr/local/bin/
chmod 755 /usr/local/bin/ansible* \
  && pip3 install virtualenv \
  && cd /opt \
  && virtualenv -p python3 ansible \
  && /bin/bash -c "source ansible/bin/activate && pip3 install ansible && pip3 install pywinrm>=0.2.2 && deactivate" \
  && ansible-galaxy collection install azure.azcollection

# # Install latest version of Istio
export ISTIO_ROOT=/usr/local/istio-latest
curl -sSL https://git.io/getLatestIstio | sh - \
  && mv $PWD/istio* $ISTIO_ROOT \
  && chmod -R 755 $ISTIO_ROOT
export PATH=$PATH:$ISTIO_ROOT/bin

# # Install latest version of Linkerd
export INSTALLROOT=/usr/local/linkerd \
  && mkdir -p $INSTALLROOT \
  && curl -sSL https://run.linkerd.io/install | sh - 
export PATH=$PATH:/usr/local/linkerd/bin

# # Install Puppet-Bolt
wget -nv -O puppet-tools.deb https://apt.puppet.com/puppet-tools-release-buster.deb \
  && dpkg -i puppet-tools.deb \
  && apt-get update \
  && bash ./aptinstall.sh puppet-bolt \
  && rm -f puppet-tools.deb

gem update --system 2.7.7 \
  && gem install bundler --version 1.16.4 --force \
  && gem install rake --version 12.3.0 --no-document --force \
  && gem install colorize --version 0.8.1 --no-document --force \
  && gem install rspec --version 3.7.0 --no-document --force \
  && rm -r /root/.gem/

export GEM_HOME=~/bundle
export BUNDLE_PATH=~/bundle
export PATH=$PATH:$GEM_HOME/bin:$BUNDLE_PATH/gems/bin

# # Download and Install the latest packer (AMD64)
PACKER_VERSION=$(curl -sSL https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r -M ".current_version") \
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

# # Install dcos
wget -nv -O dcos https://downloads.dcos.io/binaries/cli/linux/x86-64/latest/dcos \
  && echo c79285f23525e21f71473649c742af14917c9da7ee2b707ccc27e92da4838ec4 dcos | sha256sum -c \
  && mv dcos /usr/local/bin \
  && chmod +x /usr/local/bin/dcos

# # Install Chef Workstation
wget -nv -O chef-workstation_amd64.deb https://packages.chef.io/files/stable/chef-workstation/20.9.158/debian/10/chef-workstation_20.9.158-1_amd64.deb \
  && echo af67dfbf705959eb0e4d4b663142a66b2a220b33aefc54b83197ad3f535b69ba chef-workstation_amd64.deb | sha256sum -c \
  && dpkg -i chef-workstation_amd64.deb \
  && rm -f chef-workstation_amd64.deb

# # Install ripgrep
curl -sSLO https://github.com/BurntSushi/ripgrep/releases/download/12.1.1/ripgrep_12.1.1_amd64.deb \
  && echo 18ef498312073da55d2f2f65c6a906085c68368a23c9a45a87fcb8539be96608 ripgrep_12.1.1_amd64.deb | sha256sum -c \
  && dpkg -i ripgrep_12.1.1_amd64.deb \
  && rm -f ripgrep_12.1.1_amd64.deb

# # Install docker-machine
curl -sSL https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-`uname -s`-`uname -m` > /tmp/docker-machine \
  && echo a7f7cbb842752b12123c5a5447d8039bf8dccf62ec2328853583e68eb4ffb097 /tmp/docker-machine | sha256sum -c \
  && chmod +x /tmp/docker-machine \
  && mv /tmp/docker-machine /usr/local/bin/docker-machine

# # Copy and run the Helm install script, which fetches the latest release of Helm.
bash /helmInstall.sh && rm -f ./helmInstall.sh

# # Copy and run the Draft install script, which fetches the latest release of Draft with
# # optimizations for running inside cloud shell.
bash /draftInstall.sh && rm -f ./draftInstall.sh

# # Install Yeoman Generator and predefined templates
npm install -g yo \
  && npm install -g generator-az-terra-module

# # Download and install AzCopy SCD of linux-x64
curl -sSL https://aka.ms/downloadazcopy-v10-linux -o azcopy-netcore_linux_x64.tar.gz \
  && mkdir azcopy \
  && tar xf azcopy-netcore_linux_x64.tar.gz -C azcopy --strip-components 1 \
  && mv azcopy/azcopy /usr/local/bin/azcopy \
  && chmod a+x /usr/local/bin/azcopy \
  && rm -f azcopy-netcore_linux_x64.tar.gz && rm -rf azcopy

end=`date +%s`
runtime=$((end-start))
echo "Total time taken: " $runtime "seconds"