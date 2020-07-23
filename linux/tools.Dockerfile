
# image location refers to a Microsoft-internal container registry which stores a cached version
# of the image built from base.Dockerfile. If you are building this file outside Microsoft, you 
# won't be able to reach this location, but don't worry.

# To build yourself locally, override this location with a local image tag. See README.md for more detail

ARG IMAGE_LOCATION=cdpxlinux.azurecr.io/artifact/b787066e-c88f-4e20-ae65-e42a858c42ca/official/azure/cloudshell:1.0.20200708.1.base.master.f7c22730

# Copy from base build
FROM ${IMAGE_LOCATION}

RUN apt update && ACCEPT_EULA=Y apt-get install -y \
  wget
