# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxb787066ec88f4e20ae65e42a858c42ca00.azurecr.io/official/cloudshell:base.master.cd63aa88.20241018.1
# Copy from base build
FROM ${IMAGE_LOCATION}

LABEL org.opencontainers.image.source="https://github.com/Azure/CloudShell"

RUN tdnf clean all && \
    tdnf repolist --refresh && \
    ACCEPT_EULA=Y tdnf update -y && \
    # Install latest Azure CLI package. CLI team drops latest (pre-release) package here prior to public release
    # We don't support using this location elsewhere - it may be removed or updated without notice
    wget https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-mariner2.0.rpm \
    && tdnf install -y ./azure-cli-latest-mariner2.0.rpm \
    && rm azure-cli-latest-mariner2.0.rpm && \
    tdnf clean all && \
    rm -rf /var/cache/tdnf/*

# Install any Azure CLI extensions that should be included by default.
RUN az extension add --system --name ai-examples -y \
    && az extension add --system --name ssh -y \
    && az extension add --system --name ml -y

# Install kubectl
RUN az aks install-cli \
    && chmod +x /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubelogin

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
