# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you 
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxb787066ec88f4e20ae65e42a858c42ca00.azurecr.io/official/azure/cloudshell:1.0.20220906.1.base.master.12f76cc7

# Copy from base build
FROM ${IMAGE_LOCATION}

# Install latest Azure CLI package. CLI team drops latest (pre-release) package here prior to public release
# We don't support using this location elsewhere - it may be removed or updated without notice
RUN wget https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-mariner2.0.rpm \
    && tdnf install -y ./azure-cli-latest-mariner2.0.rpm \
    && rm azure-cli-latest-mariner2.0.rpm

# Install any Azure CLI extensions that should be included by default.
RUN az extension add --system --name ai-examples -y
RUN az extension add --system --name ssh -y

# EY: get an error when we try to install this.
RUN az extension add --system --name ml -y

# Install postgresql-devel for azure-cli extension rdbms-connect
RUN bash ./tdnfinstall.sh postgresql-devel

# Install kubectl
RUN az aks install-cli \
    && chmod +x /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubelogin

# Install terraform
RUN bash ./tdnfinstall.sh terraform

# github CLI
RUN bash ./tdnfinstall.sh gh

RUN mkdir -p /usr/cloudshell
WORKDIR /usr/cloudshell

# Copy and run script to Install powershell modules and setup Powershell machine profile
COPY ./linux/powershell/PSCloudShellUtility/ /usr/local/share/powershell/Modules/PSCloudShellUtility/
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Top && rm -rf ./powershell

# install powershell warmup script
COPY ./linux/powershell/Invoke-PreparePowerShell.ps1 linux/powershell/Invoke-PreparePowerShell.ps1

# Install Office 365 CLI templates
RUN npm install -q -g @pnp/cli-microsoft365

# Install Bicep CLI
RUN curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64 \
  && chmod +x ./bicep \
  && mv ./bicep /usr/local/bin/bicep \
  && bicep --help

# Remove su so users don't have su access by default. 
RUN rm -f ./linux/Dockerfile && rm -f /bin/su

# Temp: fix ansible modules. Proper fix is to update base layer to use regular python for Ansible.
RUN wget -nv -q https://raw.githubusercontent.com/ansible-collections/azure/dev/requirements-azure.txt \
    && /opt/ansible/bin/python -m pip install -r /usr/share/ansible/collections/ansible_collections/azure/azcollection/requirements-azure.txt 

#Add soft links
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -s /usr/bin/node /usr/bin/nodejs

# Add user's home directories to PATH at the front so they can install tools which
# override defaults
# Add dotnet tools to PATH so users can install a tool using dotnet tools and can execute that command from any directory
ENV PATH ~/.local/bin:~/bin:~/.dotnet/tools:$PATH

# Set AZUREPS_HOST_ENVIRONMENT 
ENV AZUREPS_HOST_ENVIRONMENT cloud-shell/1.0