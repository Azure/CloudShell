FROM sbidprod.azurecr.io/quinault
SHELL ["/bin/bash","-c"]

COPY sidecar_poc/watchUpdate.sh .
COPY sidecar_poc/entrypoint.sh .
RUN apt-get update && apt-get install azure-cli=2.36.0-1~buster

# Start a inotify watcher
RUN mkdir -p /tmp/cloudshellpkgs && cd / && chmod +x watchUpdate.sh && chmod +x entrypoint.sh
#CMD ["cd / && bash -c watcher.sh /tmp/cloudshellpkgs && sleep 4"]
ENTRYPOINT [ "/entrypoint.sh" ]