#!/bin/sh
# Script for installing the IPTV container
#
# Copyright (C) 2021 Fabian Mastenbroek.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

if ! command -v unifi-os > /dev/null 2>&1; then
    echo "Make sure you run this command from UbiOS (and not UniFi OS)"
    exit 1
elif [ ! -d /mnt/data/on_boot.d/ ]; then
    echo "Make sure you have installed the on-boot-script on your device"
    echo "See https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script"
    exit
fi

UDM_TYPE=$(grep -q "UDMPRO" /etc/board.info && echo "UDMP" || echo "UDMB")

# Extract the IPv4 address of the specified interface
_if_inet_addr() {
    ip addr show dev "$1" | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }'
}

# Extract the VLAN id of an interface
_if_vlan_id() {
     awk -F ' *\\| *' "\$1 == \"$1\" { print \$2 }" /proc/net/vlan/config
}

# Print the specified list of interfaces
_if_print_all() {
   n=1
   for interface in "$@"; do
       vlan_id=$(_if_vlan_id "$interface")
       inet_addr=$(_if_inet_addr "$interface")

       vlan_fmt=${vlan_id:+"(VLAN $vlan_id)"}
       printf "%d: %-8s %-12s [IPv4 Address: %s]\n" "$n" "$interface" "$vlan_fmt" "${inet_addr:-None}"
       n=$(( n + 1 ))
   done
}

# Prompt the user for the WAN interface to use
_prompt_wan() {
    WAN_PATTERN=$(test "$UDM_TYPE" = "UDMP" && echo "eth[8-9]*" || echo "eth4*")
    WAN_INTERFACES=$(find /sys/class/net -name "$WAN_PATTERN" -exec basename {} \; | sort)
    PPP_INTERFACES=$(find /sys/class/net -name 'ppp?' -exec basename {} \;)

    n=1
    echo "Select the WAN interface over which the IPTV traffic enters your router:"
    _if_print_all $WAN_INTERFACES $PPP_INTERFACES

    while true; do
        # shellcheck disable=SC2039
        read -r -p "Enter WAN interface [default: $WAN_INTERFACE]: "
        if [ -z "$REPLY" ]; then
            break
        elif [ -d "/sys/class/net/$REPLY" ]; then
            WAN_INTERFACE="$REPLY"
            break
        else
            echo "Invalid WAN interface $REPLY"
        fi
    done
}

# Prompt the user for the WAN VLAN for the IPTV network
_prompt_wan_vlan() {
    # Verify whether the chosen WAN interface is already a VLAN interface.
    # This means we don't have to ask for a separate VLAN
    vlan=$(_if_vlan_id "$WAN_INTERFACE")
    if [ -n "$vlan" ]; then
        return
    fi

    prompt_msg="Is IPTV traffic carried over a separate VLAN?"
    while true; do
        # shellcheck disable=SC2039
        read -r -p "$prompt_msg ([Y]es or [N]o): "
        case $(echo "$REPLY" | tr '[:upper:]' '[:lower:]') in
            y|yes) break ;;
            n|no) return ;;
        esac
    done

    WAN_VLAN="4"

    while true; do
        # shellcheck disable=SC2039
        read -r -p "Enter VLAN ID [default: $WAN_VLAN]: "
        if [ -z "$REPLY" ]; then
            break
        elif [ "$REPLY" -eq "$REPLY" ] 2>/dev/null; then
            WAN_VLAN="$REPLY"
            break
        else
            echo "Invalid VLAN ID $REPLY"
        fi
    done
}

# Prompt the user for the WAN ranges
_prompt_wan_ranges() {
    echo "Select the addresses from where the IPTV traffic originates"

    # shellcheck disable=SC2039
    read -r -p "Enter WAN ranges [default: $WAN_RANGES]: "
    if [ -n "$REPLY" ]; then
        WAN_RANGES="$REPLY"
    fi
}

# Prompt the user for the LAN configuration
_prompt_lan() {
    ALL_LAN_INTERFACES=$(find /sys/class/net -name "br*" -exec basename {} \; | sort)

    n=1
    echo "Select the LAN interfaces on which you want to allow IPTV traffic:"
    _if_print_all $ALL_LAN_INTERFACES

    while true; do
        # shellcheck disable=SC2039
        read -r -p "Enter LAN interfaces separated by spaces [default: $LAN_INTERFACES]: "
        if [ -z "$REPLY" ]; then
            break
        fi

        error=""
        for interface in $REPLY; do
            if [ ! -d "/sys/class/net/$interface" ]; then
                echo "Invalid LAN interface $interface"
                error="yes"
                break
            fi
        done

        if [ -z "$error" ]; then
            LAN_INTERFACES="$REPLY"
            break
        fi
    done
}

# Prompt the user for the LAN configuration
_show_config() {
    echo "Generated the following configuration:"
    printf "  WAN Interface:      %s\n" "$WAN_INTERFACE"
    printf "  IPTV VLAN (WAN):    %s\n" "$WAN_VLAN"
    printf "  IPTV Ranges (WAN):  %s\n" "$WAN_RANGES"
    printf "  LAN Interfaces:     %s\n" "$LAN_INTERFACES"
}

# Create the boot script at the specified location
_create_config() {
    tee  "$1" <<EOF >/dev/null
IPTV_WAN_INTERFACE="$WAN_INTERFACE"
IPTV_WAN_RANGES="$WAN_RANGES"
IPTV_WAN_VLAN="$WAN_VLAN"
IPTV_WAN_DHCP_OPTIONS="-O staticroutes -V IPTV_RG"
IPTV_LAN_INTERFACES="$LAN_INTERFACES"

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
}

# Default values
WAN_INTERFACE=$(test "$UDM_TYPE" = "UDMP" && echo "eth8" || echo "eth4")
WAN_VLAN="0"
WAN_RANGES="213.75.0.0/16 217.166.0.0/16"
LAN_INTERFACES="br0"

if [ "$INTERACTIVE" != "no" ]; then
    _prompt_wan
    _prompt_wan_vlan
    _prompt_wan_ranges
    _prompt_lan
fi

_show_config
target=/mnt/data/on_boot.d/15-iptv.sh
_create_config "$target"
echo "IPTV boot script successfully installed at $target"