# Azure Cloud Shell Package Inclusion Guide

## Background

There are millions (or potentially billions) of Linux packages. This guide goes through the principles of what the Azure Cloud Shell team uses to consider what gets included in the service.

## General Principles

1. **Useful for Azure users and administrators**
2. **Is available on [Azure Linux package repository](https://github.com/microsoft/azurelinux)**
    - Find out which packages are available on Azure Linux repository by following [this guide](add-package-into-cloudshell.md/#Check-if-package-is-available-in-Azure-Linux).
3. **Is consistently vulnerability free**
    - Does not have unfixed [CVE](https://www.cve.org/) lingering around. 
4. **Has appropriate license**
    - Azure Cloud Shell (or Microsoft) should be allowed to both use and distribute the package freely.
5. **Is well-maintained and supported**
    - It should NOT be deprecated or archived.
    - The code repository should have a contribution / commit within the last 120 days.
    - It should be of a stable version, not an alpha or beta version. 

6. **Reasonable package size**

> [!NOTE]
> After these principles have been satisfied, the Azure Cloud Shell maintainers reserves the right to make final decisions on package inclusion at their discretion.

## Discussion of Principles

1. **Useful for Azure users and administrators** 

All packages shipped by Azure Cloud Shell should be useful to Azure users. This principle is fundamental to the core of what we ship. If the package is not believed to be used widely, it will not be shipped in Cloud Shell. 

2. **Available on [Azure Linux package repository](https://github.com/microsoft/azurelinux)**

Due to secure supply chain compliance that Cloud Shell abides to, we are required to consume packages from secure sources. The guidance from the supply chain team is to ONLY consume from Azure Linux repository. Azure Linux OS is a compliant Microsoft Linux operating system. When it’s available on Azure Linux repository, we have the confidence that the binary has been built by a trusted Microsoft source. To find if the package is available, please follow the documentation provided here: [Add a package into Cloud Shell](./add-package-into-cloudshell.md#requesting-the-package)

3. **Vulnerability free** 

Due to Microsoft security initiatives, we are striving to ship Cloud Shell with no vulnerabilities in all packages. The compliance rule for Cloud Shell is to avoid shipping packages with vulnerabilities that remain unfixed for more than 30 days. Via the [Trivy software](https://trivy.dev/) for example, if a [CVE](https://www.cve.org/) has been detected on Jan 1st, we expect the package to be fixed and available in Azure Linux repository before Jan 31. 

4. **Appropriate licensing** 

Azure Cloud Shell should have the rights to both use and ship the package. Failure to comply with this policy can lead to potential lawsuits and other legal issues. 

5. **Well-maintained and supported** 

Packages included with Cloud Shell must be actively maintained and regularly updated. Package maintainers are responsible for providing evidence that their packages are current, with the latest updates made within the last 120 days. For instance, if the package is hosted on GitHub, we expect to see a commit within that timeframe. Based on this requirement, deprecated or archived packages are not suitable for inclusion in Cloud Shell. Additionally, only stable versions of software will be considered; Alpha or Beta versions will not be used.

6. **Reasonable package size**

It is crucial to ensure that any installed package does not significantly increase the Cloud Shell image size. The current Cloud Shell image is approximately 8GB, and ongoing efforts aim to reduce this size. Larger image sizes can lead to longer load times, impacting the overall user experience. Therefore, unless a package is essential for Cloud Shell users—such as the Azure CLI—we recommend that most packages should not exceed 25MB in size.

## Exceptions

If a package does not meet all the principles outlined above but is still considered essential, please initiate a discussion within the relevant GitHub repository. Ensure that your proposal includes a thorough justification, detailing the critical need for the package and addressing any potential concerns related to the principles it does not satisfy.