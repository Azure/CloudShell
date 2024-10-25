# base.Dockerfile contains components which are large and change less frequently.
# tools.Dockerfile contains the smaller, more frequently-updated components.

# Within Azure, the image layers
# built from this file are cached in a number of locations to speed up container startup time. A manual
# step needs to be performed to refresh these locations when the image changes. For this reason, we explicitly
# split the base and the tools docker files into separate files and base the tools file from a version
# of the base docker file stored in a container registry. This avoids accidentally introducing a change in
# the base image

# CBL-Mariner is an internal Linux distribution for Microsoft’s cloud infrastructure and edge products and services.
# CBL-Mariner is designed to provide a consistent platform for these devices and services and will enhance Microsoft’s
# ability to stay current on Linux updates.
# https://github.com/microsoft/CBL-Mariner
FROM mcr.microsoft.com/cbl-mariner/base/core:2.0
LABEL org.opencontainers.image.source="https://github.com/Azure/CloudShell"

SHELL ["/bin/bash","-c"]
COPY linux/tdnfinstall.sh .

