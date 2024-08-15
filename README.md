
# Microsoft Azure Cloud Shell Image

Azure Cloud Shell is an interactive, authenticated, browser-accessible shell for managing Azure
resources. As a web-based environment, Cloud Shell provides immediate management access to any
device with a network connection. Azure Cloud Shell provides a
[host of tools](https://docs.microsoft.com/azure/cloud-shell/features), including Azure CLI, Azure
PowerShell, Ansible, Terraform, Puppet Bolt, kubectl, and many more.

For more details, check out
[Overview of Azure Cloud Shell](https://docs.microsoft.com/azure/cloud-shell/overview).

## Roadmap of planned development

Azure Cloud Shell is continually working with customers to improve Azure resource management by
focusing on the experience and tools most needed by our customers. We invite everyone to view and
provide feedback to our [roadmap](./roadmap/cs-roadmap-2023.md) and future investigations. The Azure
Cloud Shell team respects and enjoys engaging with our customers, please share our
[roadmap](./roadmap/cs-roadmap-2023.md) and provide feedback here in
[Discussions](https://github.com/Azure/CloudShell/discussions) or
[Issues](https://github.com/Azure/CloudShell/issues).

## About this repository

When you connect to Azure Cloud Shell, we start a container hosting a wide variety of tools, and

connect your browser to a shell process running inside that container. This repository contains the
Docker files used to build that container image. It does _not_ contain the code used for the rest of

the Azure Cloud Shell service. The code in this repository may not match exactly to what is running
in the Cloud Shell service at any given time. The service is updated periodically and changes are
gradually rolled out to different regions over time.
There may be a lag of up to 3-4 weeks
for changes made here to be reflected in all Cloud Shell regions.

This repository has several uses:

1. **Running the Cloud Shell image locally**. If you want a curated set of up-to-date command-line
   tools suitable for managing an Azure environment, but you want to run the tools locally on your
   own computer instead of in Cloud Shell, you can build the image and run it yourself.

1. **Contributing to Cloud Shell.** If you would like to propose a new tool for inclusion in Cloud
   Shell, you can create an issue or submit a Pull Request to request the tool be added. Please
   ensure that the PR actually builds within GitHub Actions.

The repository does _not_ provide an out-of-the-box replacement for the Azure Cloud Shell service.
Azure Cloud Shell provide a user interface integrated into the Azure portal, a web service that
manages the infrastructure on which the containers run, and some additional code used inside the
container to connect the shell process to the user interface via a websocket.

## Running the Cloud Shell image locally

### Differences between running locally and in Cloud Shell

1. **No identity endpoint**. In Cloud Shell, we provide a way to automatically obtain tokens for the
   user connected to the shell. We can't provide this when you run locally, so you have to
   authenticate explicitly before you can access Azure resources. When using AZ CLI, run `az login`;
   for PowerShell, run `Connect-AzAccount`.

1. **No cloud drive**. We don't mount the Cloud Drive from your Azure Cloud Shell, so you won't have
   access to files stored there.

1. **Root instead of cloud shell user**. In Azure Cloud Shell you always run as a regular user. When
   running the image locally, you run as root.

### Understanding the base.Dockerfile and tools.Dockerfile

The repository contains two Docker configuration files: `base` and `tools`. Normally you just have
one Dockerfile and rely on the container registry to cache the layers that haven't changed.
However, we need to cache the base image explicitly to ensure a fast startup time. Tools is built
on top of the base file and starts from an internal repository where the base image is cached, so
that we know when we need to update the base.

When building or using the image locally, you don't need to worry about that. Just build using the
instructions below, and be aware that changes to the base layer will take longer to release than
changes to the tools.

| Layer        | Job           |
| ---|---|
| Base      | Contains large, infrequently changing packages. Changes every 3-4 months. |
| Tools      | Contains frequently changing packages. Changes every 2-3 weeks |

## Building and Testing the image

### Building the images

> [!NOTE]
> Cloud Shell publishes an image on each update to the master branch. If you would like to use the pre-built image, then
> you can skip this step by downloading the latest [base image layer here](ghcr.io/azure/cloudshell/base:latest)
> and the latest [tools image layer here](ghcr.io/azure/cloudshell/tools:latest). You can find all previously built image layers [here](https://github.com/orgs/Azure/packages?repo_name=CloudShell).

Required software:

- Docker
- Bash terminal / Powershell

Building base.Dockerfile image from the root repository

```bash
docker build -t base_cloudshell -f linux/base.Dockerfile .
```

Building tools.Dockerfile image

```bash
docker build -t tools_cloudshell --build-arg IMAGE_LOCATION=base_cloudshell -f linux/tools.Dockerfile .
```

### Testing the images

Running `bash` in the `tools.Dockerfile` based image:

```bash
docker run -it tools_cloudshell /bin/bash
```

Running `pwsh` in the `tools.Dockerfile` based image:

```bash
docker run -it tools_cloudshell /usr/bin/pwsh
```

Testing the Cloud Shell image:

```bash
docker run --volume /path/to/CloudShell/folder/tests:/tests -it tools_cloudshell /tests/test.sh
```

For more information about bind mounts, please see the
[Docker documentation](https://docs.docker.com/storage/bind-mounts/). We do expect all test cases
to pass if you want your changes to be merged.

## Contribution Guidelines

### Types of issues

| Issue Type        | Action           |
| ---|---|
| Package is out of date      | Create a Pull Request or Issue |
| New desired package     | Create a Pull Request or Issue |
| New desired Cloud Shell feature | Create an [Discussion](https://github.com/Azure/CloudShell/discussions) |
| Issue with one of the packages*     | Talk to package owner & create a PR on their repo.  |
| Issue with how package interacts with Cloud Shell     | Create a Pull Request OR GitHub Issue |
| Security bug | See <https://www.microsoft.com/en-us/msrc/faqs-report-an-issue> |
| Issue with Cloud Shell in Azure Portal (can't log in, for example) | Open a [support ticket](https://learn.microsoft.com/azure/active-directory/fundamentals/how-to-get-support) |

<sup>*</sup> For example, if you have an issue within Azure CLI, don't open up an issue in the Cloud Shell
repo, open an issue within the Azure CLI repo.

- [Azure PowerShell issues](https://github.com/Azure/azure-powershell/issues)
- [Azure CLI issues](https://github.com/Azure/azure-cli/issues)

### Types of tools

Cloud Shell aims to provide a core set of tools for Azure and Microsoft 365 devops scenarios, but we
can't include everything. If you just want to use a tool yourself, you can install most utilities
into your own home directory inside Cloud Shell. You only need to update the image if you want
_every_ Cloud Shell admin to have the tool available.

For a tool to be included in Cloud Shell, it has to be:

- widely useful to Azure administrators
- well-maintained and supported,
- released under a license which permits us to include it
- lightweight in terms of CPU requirements, size on disk, and memory

Please:

- support fetching tokens from Managed Identity if a tool authenticates to Azure services
- add basic tests to the test suite run by GitHub Actions
- consume the tools from the [Mariner package repo](https://packages.microsoft.com/cbl-mariner/2.0/)

In general we avoid:

- alpha, beta, preview or unstable versions of software.
- tools primarily useful for extensive software development, as opposed to DevOps. Consider
  [Visual Studio Codespaces](https://visualstudio.microsoft.com/services/visual-studio-codespaces/)
  for that.

## Cloud Shell Documentation

The Cloud Shell documentation can be found at
[https://learn.microsoft.com/azure/cloud-shell/overview](https://learn.microsoft.com/azure/cloud-shell/overview).
If you wish to contribute to The Cloud Shell documentation, see the Microsoft Learn
[Contributors Guide](https://learn.microsoft.com/contribute/).

## Legal

This project welcomes contributions and suggestions. Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, see
[https://cla.microsoft.com](https://cla.microsoft.com).

When you submit a pull request, a CLA-bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., label, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the
[Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more
information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or
comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of
Microsoft trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion
or imply Microsoft sponsorship. Any use of third-party trademarks or logos are subject to those
third-party's policies.
