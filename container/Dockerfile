FROM pandare/panda@sha256:e4bb0346e9f9cd9f0b4a2f75b353cbf041005687b4af47d5705cfee054aec71b

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        novnc \
        ovmf \
        qemu-utils \
        websockify \
    && rm -rf /var/lib/apt/lists/*

COPY common.sh run-live.sh run-replay.sh /opt/panda-tools/
RUN chmod 0755 /opt/panda-tools/*.sh

LABEL org.opencontainers.image.title="Experimental PANDA Windows 11 lab"
LABEL org.opencontainers.image.source="https://github.com/panda-re/panda"

CMD ["/opt/panda-tools/run-live.sh"]
