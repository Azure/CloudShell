# Requesting the Addition of a Package to the Cloud Shell image

One of the main features of Cloud Shell is that it serves many different packages to its users. Users don't have to go through the hassle of installing packages themselves when using Cloud Shell.

## Adding a package for yourself

You are free to install packages that do not require root permissions, such as Python and PowerShell packages, on your own. However, please note that the `tdnf` package manager cannot be used since you do not have access to root.

Here's an example as to how you can install a package like ORAS yourself:

```
VERSION="1.2.0"
curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
mkdir -p ~/.local/bin/
tar -zxf oras_${VERSION}_*.tar.gz -C ~/.local/bin/ oras
rm oras_${VERSION}_*.tar.gz
```
Reference: https://oras.land/docs/installation#linux
> [!NOTE]
> If you would like your package to persist across multiple Cloud Shell sessions, a storage account is required.

## Adding a package for everyone in using Cloud Shell

If you have a need for a package in the base Cloud Shell image we encourage you to make the request. We cannot include everything, but where there is sufficient demand we will seek to satisfy that need. The sections below describe how to request the addition of a package to Cloud Shell.

To meet security and compliance requirements, we aim to have all packages installed from Azure Linux (Mariner), a compliant Microsoft Linux OS. To include your package in Cloud Shell, ensure it's available for download from Azure Linux.

### Check if package is available in Azure Linux

> [!NOTE]
> The instructions assume Azure Linux 2.0 because CloudShell is currently based on Azure Linux 2.0

Please check if the package is available here - 
https://packages.microsoft.com/cbl-mariner/2.0/prod/base/x86_64/Packages/

Alternatively, you can use `docker` to check if a package exists in Azure Linux. Run the following command in your terminal:

```
docker run mcr.microsoft.com/cbl-mariner/base/core:2.0 bash -c "tdnf list | grep <package name>"
 ```

### Requesting Azure Linux for the package

You can skip this if the package is already available in Azure Linux.

To start the process of adding your package to Azure Linux, please open an issue via [Azure Linux GitHub](https://github.com/microsoft/azurelinux/issues).
### Create a pull request on Azure Cloud Shell GitHub

Finally create a pull request on [Cloud Shell repository](https://github.com/Azure/CloudShell) to add the package. Please add the package in [base.Dockerfile](https://github.com/Azure/CloudShell/blob/master/linux/base.Dockerfile)'s package list as shown below: 


```
RUN tdnf update -y --refresh && \
  bash ./tdnfinstall.sh \
  mariner-repos-extended && \
  tdnf repolist --refresh && \
  bash ./tdnfinstall.sh \
  nodejs18 \
  curl \
  ... \
  <package name>
```


