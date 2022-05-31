FROM sbidprod.azurecr.io/quinault
SHELL ["/bin/bash","-c"]
COPY linux/sidecarentrypoint.sh .
COPY linux/installeverything_base.sh .
RUN chmod +x /sidecarentrypoint.sh
RUN chmod +x /installeverything_base.sh
ENTRYPOINT [ "/sidecarentrypoint.sh" ]