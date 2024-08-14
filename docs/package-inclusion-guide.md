# Azure Cloud Shell Package Inclusion Guide

## Background

There are millions (or potentially billions) of Linux packages. This guide goes through the principles of what the Azure Cloud Shell team uses to consider what gets included in the service.  

## General Principles

1. Useful for Azure users and administrators 
2. Available on Azure Linux Operating System 
3. Vulnerability free 
    - No unfixed CVEs for the package on Azure Linux past 30 days 
4. Appropriate Licensing 
    - Azure Cloud Shell should be allowed to both consume and distribute the package 
5. Well-maintained and supported 

6. Package should NOT be deprecated or archived 
    - Package repo should have a Git commit within the last 90 days 
    - The package should be of a stable version. The package should not be in alpha or beta version. 
    - Reasonable package size 

After satisfying these principles, the Azure Cloud Shell team maintains the right to ship packages based on the team's own discretion.  

## Discussion of Principles

1. Useful for Azure users and administrators 

All packages shipped by Azure Cloud Shell should be useful to Azure users. This principle is fundamental to the core of what we ship. If the package is not believed to be used widely, it will not be shipped in Cloud Shell. 

2. Available on Azure Linux OS 

Due to secure supply chain compliance that Cloud Shell abides to, we are required to consume packages from secure sources. The guidance from the supply chain team is to ONLY consume from Azure Linux OS. When it’s available on Azure Linux, we have the confidence that the binary has been built by a trusted Microsoft source. To find if the package is available in Azure Linux OS, please follow the documentation provided here: Add a package into Cloud Shell | CloudConsoles Wiki (eng.ms) 

3. Vulnerability free 

Due to new Microsoft security initiatives, we are striving to ship Cloud Shell with no vulnerabilities in all packages. The compliance rule that has been set on Cloud Shell is to not ship packages with unfixed vulnerabilities of over 30 days. Via the Trivy software for example, if a CVE has been detected on Jan 1st, we expect the package to be fixed and available in Azure Linux before Jan 31. 

4. Appropriate licensing 

Microsoft corporation should have the rights to both consume and ship the package. Failure to comply with this policy can lead to potential lawsuits and other legal issues. 

5. Well-maintained and supported 

Packages that Cloud Shell ships must be well-maintained. It is the responsibility of the package maintainer to provide evidence that the package is regularly being updated. The latest change to the package should be within 90 days. With that reasoning, no package that is deprecated or archived belongs in Cloud Shell. In addition, the package should be of a stable version for us to consume. No Alpha or Beta versions of the software will be used. 

6. Reasonable package size 

It’s imperative that the package we install shouldn’t overwhelm the Cloud Shell image size. Cloud Shell is already roughly an 8GB image and efforts are being made to reduce the size. The larger the size of the image, the longer it will take for things to effectively load. Unless the package plays a critical role for Cloud Shell users (such as Az-CLI), we believe that most packages should be less than 25MBs in size. 