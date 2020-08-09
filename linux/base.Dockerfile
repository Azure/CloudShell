# base.Dockerfile contains components which are large and change less frequently. 
# tools.Dockerfile contains the smaller, more frequently-updated components. 

# Within Azure, the image layers
# built from this file are cached in a number of locations to speed up container startup time. A manual
# step needs to be performed to refresh these locations when the image changes. For this reason, we explicitly
# split the base and the tools docker files into separate files and base the tools file from a version
# of the base docker file stored in a container registry. This avoids accidentally introducing a change in
# the base image

FROM ubuntu:16.04 as azconsole-agentbase


