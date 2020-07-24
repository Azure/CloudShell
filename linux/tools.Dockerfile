
# image location refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you 
# won't be able to reach this location, but don't worry.

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxlinux.azurecr.io/artifact/b787066e-c88f-4e20-ae65-e42a858c42ca/official/azure/cloudshell:1.0.20200708.1.base.master.f7c22730

# Copy from base build
FROM ${IMAGE_LOCATION}

# Install latest Azure CLI package. CLI team will always drop latest (pre-release) package here on Friday 11AM.
RUN wget -nv https://azurecliprod.blob.core.windows.net/cloudshell-release/azure-cli-latest.deb \
  && dpkg -i azure-cli-latest.deb \
  && rm -f azure-cli-latest.deb

# terraform key
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 51852D87348FFC4C 

# Download the latest terraform (AMD64), install to global environment.
RUN TF_VERSION=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r -M ".current_version") \
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
RUN chmod 755 /usr/local/bin/terraform*

# Copy and run script to Install AzureRM.NetCore and setup Powershell machine profile
COPY ./linux/powershell/PSCloudShellUtility/ /usr/local/share/powershell/Modules/PSCloudShellUtility/
COPY ./linux/powershell/ powershell
RUN /usr/bin/pwsh -File ./powershell/setupPowerShell.ps1 -image Top && rm -rf ./powershell

RUN mkdir -p /usr/cloudshell
WORKDIR /usr/cloudshell

RUN npm install -q 

# BEGIN: Install Office 365 CLI templates
RUN npm install -q -g @pnp/office365-cli
# END: Install Office 365 CLI templates

# Remove su so users don't have su access by default. 
RUN rm -f ./linux/Dockerfile && rm -f /bin/su

