# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=mcr.microsoft.com/azure-cloudshell:base.master.f6ead934.20260629.1

# Copy from base build
FROM ${IMAGE_LOCATION}

LABEL org.opencontainers.image.source="https://github.com/Azure/CloudShell"

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
    && az extension add --system --name ml -y \
    # Configure Bicep settings
    && az config set bicep.check_version=False \
    && az config set bicep.use_binary_from_path=True

# Install kubectl
RUN az aks install-cli \
    && chmod +x /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubelogin

# Install azure-functions-core-tools
RUN wget -nv -O Azure.Functions.Cli.zip `curl -fSsL https://api.github.com/repos/Azure/azure-functions-core-tools/releases/latest | grep "url.*linux-x64" | grep -v "sha2" | cut -d '"' -f4` \
    && unzip -d azure-functions-cli Azure.Functions.Cli.zip \
    && chmod +x azure-functions-cli/func \
    && mv -v azure-functions-cli /opt \
    && ln -sf /opt/azure-functions-cli/func /usr/bin/func \
    && rm -r Azure.Functions.Cli.zip

# Conditionally update tools that were pre-installed in the base image.
# Each check only installs when a newer version is available, keeping the
# tools image layer as small as possible.
RUN set -e \
    # --- Terraform ---
    && TF_LATEST=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M ".current_version") \
    && TF_LATEST="${TF_LATEST#v}" \
    && TF_CURRENT=$(/usr/local/bin/terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "0") \
    && TF_CURRENT="${TF_CURRENT#v}" \
    && if [ "$TF_LATEST" != "$TF_CURRENT" ]; then \
         rm -f /usr/local/bin/terraform \
         && TF_INSTALL_DIR=$(mktemp -d) \
         && pushd $TF_INSTALL_DIR \
         && wget -nv -O terraform.zip "https://releases.hashicorp.com/terraform/${TF_LATEST}/terraform_${TF_LATEST}_linux_amd64.zip" \
         && wget -nv -O terraform.sha256 "https://releases.hashicorp.com/terraform/${TF_LATEST}/terraform_${TF_LATEST}_SHA256SUMS" \
         && echo "$(grep "${TF_LATEST}_linux_amd64.zip" terraform.sha256 | awk '{print $1}')  terraform.zip" | sha256sum -c \
         && unzip terraform.zip \
         && mv terraform /usr/local/bin/terraform \
         && echo "Updated Terraform $TF_CURRENT -> $TF_LATEST" \
         && popd \
         && rm -rf $TF_INSTALL_DIR ; \
       else \
         echo "Terraform already up to date: $TF_LATEST" ; \
       fi \
    && unset TF_LATEST TF_CURRENT TF_INSTALL_DIR \
    # --- azd ---
    && azd update --no-prompt \
    # --- Ruby gems ---
    && OUTDATED=$(gem outdated 2>/dev/null | awk '{print $1}') \
    && for gem_name in bundler rake colorize rspec; do \
         if echo "$OUTDATED" | grep -qx "$gem_name"; then \
           echo "Updating gem: $gem_name" ; \
           gem update "$gem_name" --no-document --force ; \
         else \
           echo "Gem already up to date: $gem_name" ; \
         fi ; \
       done \
    && rm -rf $(gem env gemdir)/cache/*.gem \
    && unset OUTDATED \
    # --- @pnp/cli-microsoft365 ---
    && PKG=@pnp/cli-microsoft365 \
    && CURRENT=$(npm list -g --depth=0 --json 2>/dev/null | jq -r --arg p "$PKG" '.dependencies[$p].version // "0"') \
    && LATEST=$(npm view "$PKG" version 2>/dev/null) \
    && if [ -n "$LATEST" ] && [ "$CURRENT" != "$LATEST" ]; then \
         echo "Updating $PKG: $CURRENT -> $LATEST" ; \
         npm install -q -g "$PKG@$LATEST" ; \
         npm cache clean --force ; \
       else \
         echo "$PKG already up to date: $CURRENT" ; \
       fi \
    && unset PKG CURRENT LATEST

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
