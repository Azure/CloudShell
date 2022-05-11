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
FROM mcr.microsoft.com/cbl-mariner/base/core:1.0

SHELL ["/bin/bash","-c"]

COPY mariner/tdnfinstall.sh .

# Use mariner-repos-microsoft-preview
# till msodbcsql and sql-tools publish to
# Mariner 2.0 prod Microsoft repo
RUN tdnf update -y && bash ./tdnfinstall.sh \
  mariner-repos-extended \
  mariner-repos-microsoft-preview

RUN tdnf update -y && bash ./tdnfinstall.sh \
  apt-transport-https \
  curl \
  xz-utils \
  git \
  gpg \
  locales \
  wget \
  zip \
  zsh \
  python3 \
  python3-pip \
  jq

RUN tdnf update -y && bash ./tdnfinstall.sh \
  nodejs \
  azure-cli


RUN bash ./tdnfinstall.sh \
  golang

ENV GOROOT="/usr/lib/golang"
ENV PATH="$PATH:$GOROOT/bin:/opt/mssql-tools/bin"

RUN export INSTALL_DIRECTORY="$GOROOT/bin" \
  && curl -sSL https://raw.githubusercontent.com/golang/dep/master/install.sh | sh \
  && ln -sf INSTALL_DIRECTORY/dep /usr/bin/dep \
  && unset INSTALL_DIRECTORY

RUN bash ./tdnfinstall.sh \
  powershell

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