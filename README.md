
# Microsoft Azure Cloud Shell Image

Azure Cloud Shell is a browser-based shell environment which enables Azure customers to manage and configure their Azure services. It provides a [host of tools](https://docs.microsoft.com/azure/cloud-shell/features), including Azure CLI, Azure PowerShell, Ansible, Terraform, Chef, Puppet Bolt, kubectl, and many more.

For more details, check out [Overview of Azure Cloud Shell](https://docs.microsoft.com/azure/cloud-shell/overview#:~:text=Features%201%20Browser-based%20shell%20experience.%20...%202%20Choice,7%20Connect%20your%20Microsoft%20Azure%20Files%20storage.%20).

Try out Cloud Shell by clicking the button below.

[![](https://shell.azure.com/images/launchcloudshell.png "Launch Azure Cloud Shell")](https://shell.azure.com)


# About this repository

When you connect to Azure Cloud Shell, we start a container containing a wide variety of tools, and connect your
browser to a shell process running inside that container. This repository contains the Docker files used to build that image. 
It does _not_ contain all of the code used for the rest of the Azure Cloud Shell service. The code in this repository may not 
match exactly to what is running in the Cloud Shell service at any given time. The service is updated periodically and changes 
are gradually rolled out to different regions over time, so there may be a lag of up to 3-4 weeks between a change being made 
here and being reflected in all Cloud Shell regions.

This repository has several uses:

1. **Running the Cloud Shell image locally**. If you want a curated set of up-to-date command-line tools suitable for managing an Azure environment, but you want to run the tools locally on your own computer instead of in Cloud Shell, you can build the image and run it yourself.

1. **Contributing to Cloud Shell.** If you would like to propose a new tool for inclusion in Cloud Shell, you can create an issue or submit a Pull Request to request the tool be added. Please ensure that the PR actually builds within GitHub Actions.

The repository does *not* provide an out-of-the-box replacement for the Cloud Shell service. In addition to the container image here, Azure Cloud Shell consists of a user interface integrated into the portal, a web service which manages the infrastructure on which the containers run, and some additional code used inside the container to connect the shell process to the user interface via websocket.

## Running the Cloud Shell image locally

```bash
docker pull mcr.microsoft.com/azure-cloudshell:latest

# for bash
docker run -it mcr.microsoft.com/azure-cloudshell /bin/bash

# for powershell
docker run -it mcr.microsoft.com/azure-cloudshell /usr/bin/pwsh
```

### Differences between running locally and in Cloud Shell

1. **No identity endpoint**. In Cloud Shell, we provide a way to automatically obtain tokens for the user connected to the shell. 
We can't provide this when you run locally, so you have to authenticate explicitly before you can access Azure resources. 
When using AZ CLI, run `az login`; for PowerShell, run `Connect-AzAccount`.

2. **No cloud drive**. We don't mount the Cloud Drive from your Azure Cloud Shell, so you won't have access to files stored there.

3. **Root instead of cloud shell user**. In Azure Cloud Shell you always run as a regular user. When running the image locally, you run as root.

# Contributing to Cloud Shell


## Understanding the base.Dockerfile and tools.Dockerfile

The repository contains two Dockerfile, 'base' and 'tools'. Tools is built on top of the base file, so normally you would
just have one Dockerfile and rely on the container registry to cache all the layers that haven't changed. However we need 
to cache the base image explicitly to ensure fast startup time. So the image is split into these two files, and the tools
layer starts FROM an internal repository where the base image is cached, so that we know when we need to update the base.

When building or using the image locally, you don't need to worry about that. Just build using the instructions below, and be
aware that changes the the base layer will take longer to release than changes to the tools.

| Layer        | Job           |
| ---|---|
| Base      | Contains large, infrequently changing packages. Changes every 3-4 months. |
| Tools      | Contains frequently changing packages. Changes every 2-3 weeks |

## Building and Testing the image

### Required software

* Docker
* Bash terminal / Powershell

## Building base.Dockerfile image 
From the root repository
```bash
docker build -t base_cloudshell -f linux/base.Dockerfile .
```
## Building tools.Dockerfile image 
```bash
docker build -t tools_cloudshell --build-arg IMAGE_LOCATION=base_cloudshell -f linux/tools.Dockerfile . 
```

## Running bash in the tools.Dockerfile image 
```bash
docker run -it tools_cloudshell /bin/bash
```

## Running pwsh in the tools.Dockerfile image
```bash
docker run -it tools_cloudshell /usr/bin/pwsh
```

## Testing the Cloud Shell image
```
docker run --volume /path/to/CloudShell/folder/tests:/tests -it tools_cloudshell /tests/test.sh
```

For more information about bind mounts, please go onto the [Docker documentation](https://docs.docker.com/storage/bind-mounts/). We do expect all the test cases to pass if you would like your changes to be merged. 

# Contribution Guidelines 

## Types of issues 

| Issue Type        | Action           |
| ---|---|
| Package is out of date      | Create a Pull Request or Issue |
| New desired package     | Create a Pull Request or Issue |
| New desired Cloud Shell feature | Create an Issue |
| Issue with one of the packages*     | Talk to package owner & create a PR on their repo.  |
| Issue with how package interacts with Cloud Shell     | Create a Pull Request OR GitHub Issue |
| Security bug | See https://www.microsoft.com/en-us/msrc/faqs-report-an-issue |
| Issue with Cloud Shell in Azure Portal (can't log in, for example) | Open a [support ticket](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-troubleshooting-support-howto#:~:text=How%20to%20open%20a%20support%20ticket%20for%20Azure,Troubleshooting%20%2B%20Support%20and%20select%20New%20support%20request.) |

\* For example, if you have an issue within Azure CLI, don't open up an issue with the Cloud Shell repo, open an issue within the Azure CLI repo. 
Azure PowerShell is [here](https://github.com/Azure/azure-powershell/issues) and Azure CLI is [here](https://github.com/Azure/azure-cli/issues) 

## Types of tools 

Cloud Shell aims to provide a core set of tools for Azure and Microsoft 365 devops scenarios, but we can't include everything. 
If you just want to use a tool yourself, you can install most utilities into your own home directory inside Cloud Shell. 
You only need to update the image if you want _every_ Cloud Shell admin to have the tool available.

For a tool to be included in Cloud Shell, it has to be:

- widely useful to Azure administrators
- well-maintained and supported,  
- released under a license which permits us to include it
- lightweight in terms of CPU requirements, size on disk, and memory

Please:
- support fetching tokens from Managed Identity if a tool authenticates to Azure services
- add basic tests to the test suite run by GitHub Actions

In general we avoid:
- alpha, beta, preview or unstable versions of software. 
- tools primarily useful for extensive software development, as opposed to DevOps. Consider [Visual Studio Codespaces](https://visualstudio.microsoft.com/services/visual-studio-codespaces/) for that.

## Cloud Shell Documentation

Please see the [Microsoft Azure Documentation](https://github.com/MicrosoftDocs/azure-docs) for a guide to add to the Azure docs repo.
The Cloud Shell documentation can be found [here](https://github.com/MicrosoftDocs/azure-docs/tree/master/articles/cloud-shell).

# Legal

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.microsoft.com.

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

# Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
