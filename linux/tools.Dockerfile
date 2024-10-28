# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxb787066ec88f4e20ae65e42a858c42ca00.azurecr.io/official/cloudshell:base.master.cd63aa88.20241018.1
# Copy from base build
FROM ${IMAGE_LOCATION}

LABEL org.opencontainers.image.source="https://github.com/Azure/CloudShell"

# ---------------------- Installation same as base image ----------------------
# Copy and run script to install Powershell modules and setup Powershell machine
# profile
COPY ./linux/powershell/ powershell

# Install latest Azure CLI package. CLI team drops latest (pre-release) package
# here prior to public release We don't support using this location elsewhere -
# it may be removed or updated without notice.
RUN INSTALLED_VERSION=$(az version --output json 2>/dev/null | jq -r '."azure-cli"') && \
  wget https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-mariner2.0.rpm && \
  # Get the version of the downloaded Azure CLI
  DOWNLOADED_VERSION=$(rpm --queryformat="%{VERSION}" -qp ./azure-cli-latest-mariner2.0.rpm) && \
  #
  # If the installed Azure CLI and the downloaded Azure CLI are different, then
  # install the downloaded Azure CLI.
  if [ "$DOWNLOADED_VERSION" != "$INSTALLED_VERSION" ]; then \
  tdnf clean all && \
  tdnf repolist --refresh && \
  tdnf remove powershell -y && \
  rm -rf /opt/microsoft/powershell && \
  rm -rf /usr/local/share/powershell && \
  ACCEPT_EULA=Y tdnf update -y && \
  tdnf install -y ./azure-cli-latest-mariner2.0.rpm && \
  tdnf install -y powershell && \
  tdnf clean all && \
  rm -rf /var/cache/tdnf/* && \
  #
  # Install any Azure CLI extensions that should be included by default.
  az extension add --system --name ai-examples -y && \
  az extension add --system --name ssh -y && \
  az extension add --system --name ml -y && \
  #
  # Install kubectl
  az aks install-cli && \
  #
  # Powershell installation and setup
  /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && \
  cp -r ./powershell/PSCloudShellUtility /usr/local/share/powershell/Modules/PSCloudShellUtility/ && \
  /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Top && \
  # Install Powershell warmup script
  mkdir -p linux/powershell && \
  cp powershell/Invoke-PreparePowerShell.ps1 linux/powershell/Invoke-PreparePowerShell.ps1; \
  fi && \
  rm azure-cli-latest-mariner2.0.rpm && \
  rm -rf ./powershell
