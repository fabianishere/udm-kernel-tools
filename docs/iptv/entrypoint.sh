#!/bin/bash

IPTV_WAN_INTERFACE="${IPTV_WAN_INTERFACE:-eth8}"
IPTV_WAN_RANGES="${IPTV_WAN_RANGES:-"213.75.0.0/16 217.166.0.0/16"}"
IPTV_WAN_VLAN="${IPTV_WAN_VLAN:-4}"
IPTV_LAN_INTERFACES="${IPTV_LAN_INTERFACES:-br0}"

# Allow autologin from root into the container
configure_getty() {
    mkdir -p /etc/systemd/system/console-getty.service.d
    tee /etc/systemd/system/console-getty.service.d/override.conf <<'EOF' >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear --autologin root --keep-baud console 115200,38400,9600 $TERM
EOF
}

# Configure IGMP Proxy to bridge multicast traffic
configure_igmpproxy() {
    # Construct the IGMP Proxy altnets for the WAN interface
    IGMPPROXY_ALTNETS=$'\t'"altnet 192.168.0.0/16"$'\n'
    for range in $IPTV_WAN_RANGES; do
        IGMPPROXY_ALTNETS+=$'\t'"altnet $range"$'\n'
    done

    # Configure the igmpproxy interfaces
    IGMPPROXY_DISABLED_IFS=""
    IGMPPROXY_ENABLED_IFS=""
    for interface in $(basename -a /sys/class/net/*); do
        if echo "$IPTV_LAN_INTERFACES" | grep -w -q "$interface"; then
            IGMPPROXY_ENABLED_IFS+="phyint $interface downstream  ratelimit 0  threshold 1"$'\n'
        elif [ "$interface" != "lo" ] && [ "$interface" != "iptv" ]; then
            IGMPPROXY_DISABLED_IFS+="phyint $interface disabled"$'\n'
        fi
    done

    tee /etc/igmpproxy.conf <<EOF >/dev/null
quickleave

phyint iptv upstream  ratelimit 0  threshold 1
$IGMPPROXY_ALTNETS

$IGMPPROXY_ENABLED_IFS
$IGMPPROXY_DISABLED_IFS
EOF

    mkdir /etc/systemd/system/igmpproxy.service.d
    tee /etc/systemd/system/igmpproxy.service.d/override.conf <<EOF >/dev/null
[Unit]
After=network.target network-online.target
Requires=network-online.target

[Service]
Restart=always
EOF
}

# Setup systemd-networkd configuration
configure_networkd() {
    tee /etc/systemd/network/wan.network <<EOF >/dev/null
[Match]
Name=$IPTV_WAN_INTERFACE

[VLAN]
VLAN=iptv
EOF
    tee /etc/systemd/network/iptv.netdev <<EOF >/dev/null
[NetDev]
Name=iptv
Kind=vlan

[VLAN]
Id=$IPTV_WAN_VLAN
EOF
    tee /etc/systemd/network/iptv.network <<EOF >/dev/null
[Match]
Name=iptv

[Network]
DHCP=ipv4
LinkLocalAddressing=no
IPv6AcceptRA=false
LLMNR=false

[DHCPv4]
UseRoutes=yes
VendorClassIdentifier=IPTV_RG
EOF
}

configure_getty
configure_igmpproxy
configure_networkd

exec /bin/systemd
