# IPTV on the UDM/P

This document describes how to use IPTV with the UDM/P. These instructions have
been tested with the IPTV network from KPN (ISP in the Netherlands). However,
they should be applicable for other ISPs as well.

For IPTV on the UniFi Security Gateway, please refer to the
[following guide](https://github.com/basmeerman/unifi-usg-kpn).

## Contents

1. [Global Design](#global-design)
1. [Prerequisites](#prerequisites)
1. [Setting up Internet Connection](#setting-up-internet-connection)
1. [Configuring Internal LAN](#configuring-internal-lan)
1. [Configuring udm-iptv](#configuring-udm-iptv)
1. [Troubleshooting and Known Issues](#troubleshooting-and-known-issues)

## Global Design

```
        Fiber
          |
    +----------+
    | FTTH NTU |
    +----------+
          |
      VLAN4 - IPTV
      VLAN6 - Internet
          |
      +-------+
      | UDM/P |   - Ubiquiti UniFi Dream Machine
      +-------+
          |
         LAN
          |
      +--------+
      | Switch |  - Ubiquiti UniFi Switch
      +--------+
       |  |  |
       |  |  +-----------------------------+
       |  |                                |
       |  +-----------------+              |
       |                    |              |
+--------------+       +---------+      +-----+
| IPTV Decoder |       | Wifi AP |      | ... |
+--------------+       +---------+      +-----+
  - KPN IPTV
  - Netflix
```

# Prerequisites

Make sure you check the following prerequisites before trying the other steps:

1. The kernel on your UniFi Dream Machine (Pro) must support multicast routing
   in order to support IPTV. The stock UDM/P kernel starting from
   [firmware version 1.11](https://community.ui.com/releases/UniFi-OS-Dream-Machines-1-11-0-14/71916646-d8f6-41c0-b145-2fbe2db7c278)
   now support multicast routing natively.
   If you cannot use the latest firmware version, see [udm-kernel](https://github.com/fabianishere/udm-kernel)
   for a kernel that supports multicast routing for older firmware versions of
   the UDM/P.
2. You must
   have [on-boot-script](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script)
   installed on your UDM/P.
3. The switches in-between the IPTV decoder and the UDM/P must have IGMP
   snooping enabled.
4. Connect a WAN port (eth8 on UDMP) to the FTTP NTU of your ISP (e.g., KPN).

## Setting up Internet Connection

The first step is to setup your internet connection to your ISP with the UDM/P
acting as modem, instead of some intermediate device. These steps might differ
per ISP, so please check the requirements for your ISP.

1. In your UniFi Dashboard, go to **Settings > Internet**.
2. Select the WAN port that is connected to the FTTP NTU.
3. Enable **VLAN ID** and set it to the Internet VLAN of your ISP (VLAN6 for
   KPN).
4. Set **IPv4 Connection** to _PPPoE_.
5. For KPN, **Username** should be set to `xx-xx-xx-xx-xx-xx@internet` where
   the `xx-xx-xx-xx-xx-xx` is replaced by the MAC address of your modem, with
   the semicolons (":") replaced with dashes ("-").
6. For KPN, **Password** should be set to `ppp`.

## Configuring Internal LAN

To operate correctly, the IPTV decoders on the internal LAN possibly require
additional DHCP options. You can add these DHCP options as follows:

1. In your UniFi Dashboard, go to **Settings > Networks**.
2. Select the LAN network on which IPTV will be used.
3. Go to **Advanced > DHCP Option** and add the following options:

   | Name      | Code | Type       | Value          |
   |-----------|:----:|------------|----------------|
   | IPTV      |  60  | Text       | IPTV_RG        |
   | Broadcast |  28  | IP Address | _BROADCAST_ADDRESS_ |

   Replace _BROADCAST_ADDRESS_ with the broadcast address of your LAN network.
   To get this address, you can obtain it by setting all bits outside the subnet
   mask of your IP range, for instance:
   ```
   192.168.X.1/24 => 192.168.X.255
   192.168.0.1/16 => 192.168.255.255
   ```
   See [here](https://en.wikipedia.org/wiki/Broadcast_address) for more
   information.

## Configuring udm-iptv

Next, we will use the [udm-iptv](https://hub.docker.com/r/fabianishere/udm-iptv)
container to get IPTV working on your LAN. This container uses
[igmpproxy](https://github.com/pali/igmpproxy) to route multicast IPTV traffic between WAN and LAN.

Before we set up the `udm-iptv` container, make sure you have the
[on-boot-script](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script)
installed.  SSH into your machine and execute the following commands:

```bash
tee  /mnt/data/on_boot.d/15-iptv.sh <<EOF >/dev/null
if podman container exists iptv; then
  podman rm -f iptv
fi
podman run --network=host --privileged \
    --name iptv -i -d --restart always \
    -e IPTV_WAN_INTERFACE="eth8" \
    -e IPTV_WAN_RANGES="213.75.112.0/21 217.166.0.0/16" \
    -e IPTV_LAN_INTERFACES="br0" \
    fabianishere/udm-iptv:1.1 -d -v
EOF
chmod +x /mnt/data/on_boot.d/15-iptv.sh
```

This script will run after every boot of your UniFi Dream Machine and set up the
applications necessary to route the IPTV traffic.

**Note:** This configuration contains IP ranges and interfaces specific to my
KPN setup. Please modify to your specific setup. See below for a list of options
to configure the container.

| Environmental Variable | Description | Default |
| ------------------------|----------- |---------|
| IPTV_WAN_INTERFACE      | Interface on which IPTV traffic enters the router | eth8 |
| IPTV_WAN_RANGES         | IP ranges from which the IPTV traffic originates (separated by spaces) | 213.75.0.0/16 217.166.0.0/16 |
| IPTV_WAN_VLAN           | ID of VLAN which carries IPTV traffic (use 0 if no VLAN is used) | 4 |
| IPTV_WAN_VLAN_INTERFACE | Name of the VLAN interface to be created | iptv |
| IPTV_WAN_DHCP_OPTIONS   | [DHCP options](https://busybox.net/downloads/BusyBox.html#udhcpc) to send when requesting an IP address | -O staticroutes -V IPTV_RG |
| IPTV_LAN_INTERFACES     | Interfaces on which IPTV should be made available | br0 |
| IPTV_LAN_RANGES         | IP ranges from which IPTV will be watched | 192.168.0.0/16 |

## Troubleshooting and Known Issues

Below is a non-exhaustive list of issues that might occur while getting IPTV to
run on the UDM/P, as well as troubleshooting steps. Please check these
instructions before reporting an issue on issue tracker.

### Debugging IGMP Proxy

Use the following steps to debug `igmpproxy` if it is behaving strangely:

1. **Enabling debug logs**  
   You can enable `igmpproxy` to report debug messages by adding the following
   flags to the script in `/mnt/data/on_boot.d/15-iptv.sh`:
   ```diff
      podman run --network=host --privileged \
        -e IPTV_WAN_INTERFACE="eth8" \
        -e IPTV_WAN_RANGES="213.75.112.0/21 217.166.0.0/16" \
        -e IPTV_LAN_INTERFACES="br0" \
   -    fabianishere/udm-iptv:1.1
   +    fabianishere/udm-iptv:1.1 -d -v
      ```
   Make sure you run the script afterwards to apply the changes.
2. **Viewing debug logs**  
   You may now view the debug logs of `igmpproxy` as follows:
   ```bash
   podman logs iptv
   ```