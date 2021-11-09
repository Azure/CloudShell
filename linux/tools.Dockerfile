
# IMAGE_LOCATION refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you 
# won't be able to reach this location, but don't worry!

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxlinux.azurecr.io/artifact/b787066e-c88f-4e20-ae65-e42a858c42ca/official/azure/cloudshell:1.0.20201030.1.base.master.0e24a3b1

# Copy from base build
FROM ${IMAGE_LOCATION}

# Install latest Azure CLI package. CLI team drops latest (pre-release) package here prior to public release
# We don't support using this location elsewhere - it may be removed or updated without notice
RUN wget -nv https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest-buster.deb \
    && dpkg -i azure-cli-latest-buster.deb \
    && rm -f azure-cli-latest-buster.deb

# Install latest SSHArc 0.2.0 from ClI package.
RUN az extension add --system --yes --source https://ssharc.blob.core.windows.net/ssharc/ssh-0.2.0-py3-none-any.whl

# Install any Azure CLI extensions that should be included by default.
RUN az extension add --system --name ai-examples -y

# EY: get an error when we try to install this.
# RUN az extension add --system --name azure-cli-ml -y

# Install kubectl
RUN az aks install-cli \
    && chmod +x /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubelogin

# Download the latest terraform (AMD64), install to global environment.
RUN gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B36CBA91A2C0730C435FC280B0B441097685B676 \
    && TF_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M ".current_version") \
    && wget -nv -O terraform.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip \
    && wget -nv -O terraform.sha256 https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS \
    && wget -nv -O terraform.sha256.sig https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_SHA256SUMS.sig \  
    && gpg --verify terraform.sha256.sig terraform.sha256 \
    && echo $(grep -Po "[[:xdigit:]]{64}(?=\s+terraform_${TF_VERSION}_linux_amd64.zip)" terraform.sha256) terraform.zip | sha256sum -c \
    && unzip terraform.zip \
    && mkdir /usr/local/terraform \
    && mv terraform /usr/local/terraform \
    && rm -f terraform terraform.zip terraform.sha256 terraform.sha256.sig \
    && unset TF_VERSION

COPY ./linux/terraform/terraform*  /usr/local/bin/
RUN chmod 755 /usr/local/bin/terraform* && dos2unix /usr/local/bin/terraform*

# github CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt update \
    && apt install gh

# Temporarily rerun PowerShell install during tools build to pick up latest version
RUN rm packages-microsoft-prod.deb \
    && wget -nv -q https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt update \
    && apt-get -y install powershell 

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

# Temp: fix linkerd symlink if it points nowhere. This can be removed after next base image update
RUN ltarget=$(readlink /usr/local/linkerd/bin/linkerd) && \
    if [ ! -f $ltarget ] ; then rm /usr/local/linkerd/bin/linkerd ; ln -s /usr/local/linkerd/bin/linkerd-stable* /usr/local/linkerd/bin/linkerd ; fi

# Temp: fix ansible modules. Proper fix is to update base layer to use regular python for Ansible.
RUN wget -nv -q https://raw.githubusercontent.com/ansible-collections/azure/dev/requirements-azure.txt \
    && /opt/ansible/bin/python -m pip install -r requirements-azure.txt \
    && rm requirements-azure.txt

# Add user's home directories to PATH at the front so they can install tools which
# override defaults
ENV PATH ~/.local/bin:~/bin:$PATH

# Set AZUREPS_HOST_ENVIRONMENT 
ENV AZUREPS_HOST_ENVIRONMENT cloud-shell/1.0
