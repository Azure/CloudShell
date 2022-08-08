# Cloud Shell update July 2022

Cloud Shell provides a large set of useful cloud management tools packaged inside a container. From
November 2020 to now, the base image for the container and the corresponding repository for packages
has been “Common Base Linux – Delridge” (aka CBL-D). Thanks to the support and feedback, Cloud
Shell is now moving to support additional Microsoft scenarios and requires a new base image.

We are currently updating Cloud Shell to a newer base image and repository called "Common Base Linux
– Mariner" (aka CBL-Mariner). That may sound unfamiliar – this is not a standalone distribution, but
a Microsoft project which tracks Red Hat very closely. The primary difference between Red Hat and
CBL-Mariner is that Microsoft compiles all the packages included in the CBL-Mariner repository
internally. This helps guard against supply chain attacks.

Tooling has been updated to reflect the new base image CBL-Mariner and should have little impact on
customers. If your scenario has been affected by these changes, please contact Azure support, or
create an issue in the [Cloud Shell repository](https://github.com/Azure/CloudShell/issues).

For a full list of the package versions installed, you can run `tdnf list installed`.
