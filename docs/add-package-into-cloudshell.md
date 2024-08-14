# Add a package into Cloud Shell

One of the main features of Cloud Shell is that it serves many different packages to its users. Users don't have to go through the hassle of installing packages themselves when using Cloud Shell.

## An installation work around

For all packages that does not require root permissions, you are free to install it yourself. This includes python, powershell, nodejs packages. Here's an example as to how you can install a package like ORAS yourself.

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

If you mount a storage account and have the package stored within your HOME directory (or any subfolders from HOME), you can store it for future use. In the example above, since the package is stored within `~/.local/bin`, it will be available for you on the next time you use Cloud Shell.  

## Requesting the package

As per security & compliance requirements, we are striving to have all our packages installed from Azure Linux (a.k.a Mariner). Azure Linux is a compliant Microsoft Linux Operating System. If you want your package to be available in Cloud Shell, we expect to have it downloadable from Azure Linux OS. 

### Check if package is available in Azure Linux

The below instructions is assuming Azure Linux 2.0. Please note that Azure linux 3.0 is coming out soon.

Please check if the package is available on here - 
https://packages.microsoft.com/cbl-mariner/2.0/prod/base/x86_64/Packages/

You can also check via entering the below command.

```
docker run mcr.microsoft.com/cbl-mariner/base/core:2.0 bash -c "tdnf list | grep <package name>"
 ```

### Requesting Azure Linux for the package

You can skip this if the package is already available in Azure Linux

To start the process of adding your package to Azure Linux, please open an issue via [Azure Linux GitHub](https://github.com/microsoft/azurelinux/issues).
### Create a pull request on Azure Cloud Shell GitHub

Create a pull request on [Cloud Shell GitHub](https://github.com/Azure/CloudShell) for adding the package in. Please add the package within [base.Dockerfile](https://github.com/Azure/CloudShell/blob/master/linux/base.Dockerfile). 

Please add the package at the end of the long tdnf update + installation.

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


