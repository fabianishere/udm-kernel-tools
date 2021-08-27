#!/bin/sh
# Script for installing the IPTV container
#
# Copyright (C) 2021 Fabian Mastenbroek.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

if ! command -v unifi-os > /dev/null 2>&1
then
    echo "Make sure you run this command from UbiOS (and not UniFi OS)"
    exit 1
fi

# Determine the default WAN port (eth8 on UDM Pro, eth4 on UDM Base)
DEFAULT_WAN_PORT=$(grep -q "UDMPRO" /etc/board.info && echo "eth8" || echo "eth4")

tee  /mnt/data/on_boot.d/15-iptv.sh <<EOF >/dev/null
IPTV_WAN_INTERFACE="$DEFAULT_WAN_PORT"
IPTV_WAN_RANGES="213.75.112.0/21 217.166.0.0/16"
IPTV_WAN_VLAN="4"
IPTV_WAN_DHCP_OPTIONS="-O staticroutes -V IPTV_RG"
IPTV_LAN_INTERFACES="br0"

if podman container exists iptv; then
  podman rm -f iptv
fi
podman run --network=host --privileged \\
    --name iptv -i -d --restart always \\
    -e IPTV_WAN_INTERFACE="\$IPTV_WAN_INTERFACE" \\
    -e IPTV_WAN_RANGES="\$IPTV_WAN_RANGES" \\
    -e IPTV_WAN_VLAN="\$IPTV_WAN_VLAN" \\
    -e IPTV_WAN_DHCP_OPTIONS="\$IPTV_WAN_DHCP_OPTIONS" \\
    -e IPTV_LAN_INTERFACES="\$IPTV_LAN_INTERFACES" \\
    -e IPTV_LAN_RANGES="" \\
    fabianishere/udm-iptv
EOF
chmod +x /mnt/data/on_boot.d/15-iptv.sh

echo "IPTV container boot script successfully installed at /mnt/data/on_boot.d/15-iptv.sh"
echo "Make sure you configure the options in this script to your specific setup before running the script."