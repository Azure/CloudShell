FROM sbidprod.azurecr.io/quinault
SHELL ["/bin/bash","-c"]
COPY linux/sidecarentrypoint.sh .
RUN chmod +x /sidecarentrypoint.sh
ENTRYPOINT [ "/sidecarentrypoint.sh" ]