# The relationship between Azure Cloud Shell and Azure CLI

People are sometimes confused about the relationship between Azure Cloud Shell and Azure CLI. 
These are two different projects that are often used together, and it can be confusing who is doing what. 
This leads to bugs in one project being reported against the other. This doc explains the difference.

[**Azure CLI**](https://github.com/Azure/azure-cli) is a command line tool which can be used to configure Azure. 
You can download and install it yourself, or it is also provided pre-installed in Azure Cloud Shell.

[**Azure Cloud Shell**](https://github.com/Azure/cloudshell/) is an online service which provides a whole set of
tools for configuring Azure, including Azure CLI, Azure PowerShell, Terraform, kubectl, and many more. It is 
usually accessed via the Azure Portal (https://portal.azure.com/#cloudshell) but can also be used from Windows Terminal, 
Windows Admin Center, or other places. 

## I've found a bug, where should I file it?

Sorry about that! Unsurprisingly, if the bug is in the Azure CLI tool, please file it under https://github.com/Azure/azure-cli/issues . 
If the bug is in Cloud Shell, file it under https://github.com/Azure/cloudshell/issues . 

But how do you tell which is which?

- If your scenario doesn't involve running `az something`, it's not AZ CLI. 
- See if it is possible to run the scenario inside *and* outside of Cloud Shell. 
For example, you can [install AZ CLI locally](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli). 
If it works on your own computer and fails in Cloud Shell, it is likely a Cloud Shell issue. 
If it fails locally, it is **not** a Cloud Shell issue, because you are not using Cloud Shell at that time.
