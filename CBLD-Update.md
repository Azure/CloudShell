# Cloud Shell update November 2020

Cloud Shell provides a large set of useful cloud management tools packaged inside a container. 
Until now, the base image for the container and the corresponding repository for packages has been Ubuntu 16.04. 
That has served us well but as you can tell by the version, this is now approaching end of life, and many of the
tools included in Cloud Shell which are pulled from the Ubuntu 16.04 package repository are older than we would like.

We are currently updating Cloud Shell to a newer base image and repository called “Common Base Linux – Delridge” (aka CBL-D).
That may sound unfamiliar – this is not a standalone distribution, but a Microsoft project which tracks Debian very closely. 
The primary difference between Debian and CBL-D is that Microsoft compiles all the packages included in the CBL-D repository 
internally. This helps guard against supply chain attacks. 

We are also updating many additional packages which are not included in the base respository but needed a refresh anyway.

What this means for Cloud Shell users is that **almost every single tool included in the Cloud Shell image has a newer version**, 
including many of the most-commonly-used ones. Some lesser-used tools have also been removed and some others added. 
In almost all cases, this should be an improvement. However if your scenario has been affected by any of these changes 
please contact Azure support, or create an issue in https://github.com/Azure/CloudShell/issues 

Some of the highlights:
- PowerShell 7.1.0
- Python 3.7 
- dotnet runtime 3.1
- dotnet sdk 3.1
- GCC/G++ 8.3
- Ansible 2.10.2
- AZ CLI 2.15.0
- AZCopy 10.6.1
- Azure PowerShell 5.1.0
- Batch Shipyard 3.9.1
- Blobxfer 1.9.4
- Chef Workstation 20.9.158
- Cloud Foundary CLI 6.53.0+8e2b70a4a.2020-10-01
- DC/OS CLI 1.2.0
- Docker-machine 0.16.2
- Draft 0.16.0+g5433afe
- Go 1.13.7
- Helm 3.4.0+g7090a89
- Istio 1.7.4
- Jenkins X 1.3.107
- Linkerd stable-2.8.1
- Packer 1.6.5
- Ripgrep 12.1.1

For a full list of the package versions installed via APT, you can run `apt list --installed`.
