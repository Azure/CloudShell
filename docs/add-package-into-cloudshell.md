# Requesting the Addition of a Package to the Cloud Shell image

A key advantage of Azure Cloud Shell is its extensive selection of pre-installed packages, streamlining your workflow by removing the need for manual installations. However, if you find that certain packages you need are not included, there are options available to add them.

## Adding a package for yourself

You are free to install packages that do not require root permissions, such as Python and PowerShell packages, on your own. However, please note that the `tdnf` package manager cannot be used since you do not have access to root.

Here's an example of how to install a package like ORAS:

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

## Adding a package for everyone using Cloud Shell

If you need a package in the base Cloud Shell image, we encourage you to make a request. We cannot include everything, but where there is sufficient demand we will seek to satisfy that need. The sections below describe how to request the addition of a package to Cloud Shell.

The package should meet Cloud Shell's [package inclusion principles](./package-inclusion-guide.md).

To meet security and compliance requirements, all packages must be installed from the Azure Linux package repository. The Azure Linux package repository is hosted on [packages.microsoft.com](https://packages.microsoft.com).

### Check if package is available in Azure Linux

> [!NOTE]
> The instructions assume Azure Linux 3.0 because Cloud Shell is currently based on Azure Linux 3.0.

Please check if the package is available here:
https://packages.microsoft.com/azurelinux/3.0/prod/base/x86_64/Packages/

Alternatively, you can use `docker` to check if a package exists in Azure Linux. Run the following command in a terminal:

```
docker run mcr.microsoft.com/cbl-mariner/base/core:2.0 bash -c "tdnf list | grep <package name>"
 ```

### Requesting Azure Linux package repository for the package

If the previous step confirmed that the package is already present in the Azure Linux repository, you can skip to the next step. Otherwise, you will need to request its addition by following these steps.

To start the process of adding your package to Azure Linux repository, please open an issue via [Azure Linux GitHub](https://github.com/microsoft/azurelinux/issues).

### Create a pull request on Azure Cloud Shell GitHub

To track this request in Cloud Shell, we will need an issue on GitHub. If the package is already in the Azure Linux repository, please open a pull request to include it, as described below. If the package is not yet available in the Azure Linux repo please open an issue making the request for the addition and link to the issue you raised in the Azure Linux GitHub repo in the previous step. Of course,before taking either of these steps, check if someone else has already made the request. If they have, please add your thumbs up so we know you need it too.

Please create a PR for adding the package in [base.Dockerfile](https://github.com/Azure/CloudShell/blob/master/linux/base.Dockerfile)'s package list as shown below: 


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


