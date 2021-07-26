FROM arm64v8/ubuntu:focal

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends systemd igmpproxy \
	&& systemctl enable systemd-networkd igmpproxy \
	&& rm -rf /var/cache /var/lib/apt/lists

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
