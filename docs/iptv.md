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
1. [Creating VLAN and obtaining IP address](#creating-vlan-and-obtaining-ip-address)
1. [Configuring igmpproxy](#configuring-igmpproxy)
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
   in order to support IPTV. Be aware that the stock UDM/P kernel **does not**
   support multicast routing.
   See [udm-kernel](https://github.com/fabianishere/udm-kernel)
   for a kernel that supports multicast routing.
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

## Route IPTV traffic onto LAN

Next, we use the `udm-iptv` container to route the IPTV traffic between WAN and
LAN. SSH into your machine and run the following command. Make sure you have the
[on-boot-script](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script)
installed.

```bash
tee  /mnt/data/on_boot.d/15-iptv.sh <<EOF >/dev/null
if podman container exists iptv; then
  podman rm -f iptv
fi
podman run --network=host --privileged \
    --name iptv --rm -i -d \
    -v /run:/var/run/ -v /run:/run \
    -e IPTV_WAN_INTERFACE="eth8" \
    -e IPTV_WAN_RANGES="213.75.0.0/16 217.166.0.0/16" \
    -e IPTV_LAN_INTERFACES="br0" \
    fabianishere/udm-iptv:1.0
    
# NAT the IP-ranges to IPTV network
iptables -t nat -A POSTROUTING -d 213.75.112.0/21 -j MASQUERADE -o iptv
iptables -t nat -A POSTROUTING -d 217.166.0.0/16 -j MASQUERADE -o iptv
EOF
chmod +x /mnt/data/on_boot.d/15-iptv.sh
```

This script will run after every boot of your UniFi Dream Machine and set up the
applications necessary to route the IPTV traffic.

**Note:** This configuration contains IP ranges and interfaces specific to my
KPN setup. Please modify to your specific setup.