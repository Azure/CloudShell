# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxb787066ec88f4e20ae65e42a858c42ca00.azurecr.io/official/cloudshell:base.master.7df1b379.20250423.1
# Copy from base build
FROM ${IMAGE_LOCATION}

LABEL org.opencontainers.image.source="https://github.com/Azure/CloudShell"

# Temporarily add in this code. We can remove it once we cache the base image.
RUN tdnf update -y --refresh && \
    bash ./tdnfinstall.sh \
    azurelinux-repos-cloud-native \
    azurelinux-repos-extended \
    azurelinux-repos-ms-non-oss-3.0 && \
    tdnf repolist --refresh && \
    bash ./tdnfinstall.sh \
    msodbcsql18 \
    mssql-tools18 \
    kubectl-gadget \
    ig && \
    tdnf clean all && \
    rm -rf /var/cache/tdnf/*
        

RUN tdnf clean all && \
    tdnf repolist --refresh && \
    ACCEPT_EULA=Y tdnf update -y && \
    # Install latest Azure CLI package. CLI team drops latest (pre-release) package here prior to public release
    # We don't support using this location elsewhere - it may be removed or updated without notice
    wget https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-azurelinux3.0.rpm \
    && tdnf install -y ./azure-cli-latest-azurelinux3.0.rpm \
    && rm azure-cli-latest-azurelinux3.0.rpm && \
    tdnf clean all && \
    rm -rf /var/cache/tdnf/*

# Install any Azure CLI extensions that should be included by default.
RUN az extension add --system --name ssh -y \
    && az extension add --system --name ml -y

# Install kubectl
RUN az aks install-cli \
    && chmod +x /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubelogin

# Install azure-functions-core-tools
RUN wget -nv -O Azure.Functions.Cli.zip `curl -fSsL https://api.github.com/repos/Azure/azure-functions-core-tools/releases/latest | grep "url.*linux-x64" | grep -v "sha2" | cut -d '"' -f4` \
    && unzip -d azure-functions-cli Azure.Functions.Cli.zip \
    && chmod +x azure-functions-cli/func \
    && chmod +x azure-functions-cli/gozip \
    && mv -v azure-functions-cli /opt \
    && ln -sf /opt/azure-functions-cli/func /usr/bin/func \
    && ln -sf /opt/azure-functions-cli/gozip /usr/bin/gozip \
    && rm -r Azure.Functions.Cli.zip

RUN mkdir -p /usr/cloudshell
WORKDIR /usr/cloudshell

# Powershell telemetry
ENV POWERSHELL_DISTRIBUTION_CHANNEL=CloudShell \
    # don't tell users to upgrade, they can't
    POWERSHELL_UPDATECHECK=Off

# Copy and run script to install Powershell modules and setup Powershell machine profile
COPY ./linux/powershell/ powershell
RUN cp ./powershell/libs/libmi.so /opt/microsoft/powershell/7/libmi.so && \
    /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Base && \
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
