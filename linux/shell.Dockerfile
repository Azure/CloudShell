FROM sbidprod.azurecr.io/quinault
SHELL ["/bin/bash","-c"] 
COPY linux/aptinstall.sh .
COPY linux/watchUpdate.sh .
COPY linux/entrypoint.sh .
COPY linux/helmInstall.sh .
COPY linux/draftInstall.sh .
COPY linux/ansible/ansible*  /usr/local/bin/
RUN echo "deb https://packages.microsoft.com/repos/cbl-d quinault-universe main" >> /etc/apt/sources.list
RUN apt-get update && bash ./aptinstall.sh \
  apt-transport-https \
  curl \
  xz-utils \
  git \
  gpg \
  inotify-tools \
  locales \
  wget \
  zip \
  zsh \
  python3 \
  python3-pip \
  jq

# Begin provision Node.js
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

# Install latest Azure CLI package. CLI team drops latest (pre-release) package here prior to public release
# We don't support using this location elsewhere - it may be removed or updated without notice
RUN wget -nv https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-buster.deb \
    && dpkg -i azure-cli-latest-buster.deb \
    && rm -f azure-cli-latest-buster.deb

# Setup locale to en_US.utf8
RUN echo en_US UTF-8 >> /etc/locale.gen && locale-gen
ENV LANG="en_US.utf8"

# Install Go
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

# Install PowerShell
# Register the Microsoft repository GPG keys and Install PowerShell Core
RUN wget -nv -q https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && apt update \
  && bash ./aptinstall.sh powershell 

# PowerShell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL CloudShell
# don't tell users to upgrade, they can't
ENV POWERSHELL_UPDATECHECK Off

# Copy and run script to Install powershell modules
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && rm -rf ./powershell
RUN mkdir -p /usr/cloudshell
WORKDIR /usr/cloudshell

# Copy and run script to Install powershell modules and setup Powershell machine profile
COPY ./linux/powershell/PSCloudShellUtility/ /usr/local/share/powershell/Modules/PSCloudShellUtility/
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Top && rm -rf ./powershell

# install powershell warmup script
COPY ./linux/powershell/Invoke-PreparePowerShell.ps1 linux/powershell/Invoke-PreparePowerShell.ps1

# Remove su so users don't have su access by default. 
RUN rm -f ./linux/Dockerfile && rm -f /bin/su

# Add user's home directories to PATH at the front so they can install tools which
# override defaults
# Add dotnet tools to PATH so users can install a tool using dotnet tools and can execute that command from any directory
ENV PATH ~/.local/bin:~/bin:~/.dotnet/tools:$PATH

# Set AZUREPS_HOST_ENVIRONMENT 
ENV AZUREPS_HOST_ENVIRONMENT cloud-shell/1.0

# Start a inotify watcher
RUN mkdir -p /tmp/cloudshellpkgs && cd / && chmod +x watchUpdate.sh && chmod +x entrypoint.sh
#CMD ["cd / && bash -c watcher.sh /tmp/cloudshellpkgs && sleep 4"]
ENTRYPOINT [ "/entrypoint.sh" ]