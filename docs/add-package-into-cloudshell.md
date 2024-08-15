# Add a package into Cloud Shell

One of the main features of Cloud Shell is that it serves many different packages to its users. Users don't have to go through the hassle of installing packages themselves when using Cloud Shell.

## An installation work around

For all packages that do not require root permissions, you are free to install it yourself. This includes, but not limited to, Python, Powershell, Nodejs packages.

Here's an example as to how you can install a package like ORAS yourself:

```
cd ~
VERSION="1.2.0"
curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
mkdir -p ~/oras-install/
mkdir -p ~/.local/bin/
tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
mv ~/oras-install/oras ~/.local/bin/oras
rm -rf oras_${VERSION}_*.tar.gz oras-install/
```
Reference: https://oras.land/docs/installation#linux

For persistence of your packages across multiple Cloud Shell sessions, it is recommended you enable the persistent storage with the "storage account" feature of Cloud Shell. In addition, install these packages in any directory in `$HOME`, since the `$HOME` directory is stored in the storage account.

In our above example you can see that the package is installed in the `~/.local/bin` directory. Since it is within a directory within `$HOME`, the ORAS package will persistent across Cloud Shell sessions (assuming you are using a storage mount).

## Requesting the package

As per security & compliance requirements, we are striving to have all our packages installed from Azure Linux (a.k.a Mariner). Azure Linux is a compliant Microsoft Linux Operating System. If you want your package to be available in Cloud Shell, we expect to have it downloadable from Azure Linux OS. 

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


