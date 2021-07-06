# IPTV on the UDM/P
This document describes how to use IPTV with the UDM/P. These instructions
have been tested with the IPTV network from KPN (ISP in the Netherlands).
However, they should be applicable for other ISPs as well.

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
1. The kernel on your UniFi Dream Machine (Pro) must support multicast routing in
   order to support IPTV. Be aware that the stock UDM/P kernel **does not** support
   multicast routing. See [udm-kernel](https://github.com/fabianishere/udm-kernel)
   for a kernel that supports multicast routing.
2. You must have [on-boot-script](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script)
   installed on your UDM/P.
3. The switches in-between the IPTV decoder and the UDM/P must have IGMP snooping
   enabled.
4. Connect a WAN port (eth8 on UDMP) to the FTTP NTU of your ISP (e.g., KPN).

## Setting up Internet Connection
The first step is to setup your internet connection to your ISP with the UDM/P
acting as modem, instead of some intermediate device.
These steps might differ per ISP, so please check the requirements for your ISP.

1. In your UniFi Dashboard, go to **Settings > Internet**.
2. Select the WAN port that is connected to the FTTP NTU.
3. Enable **VLAN ID** and set it to the Internet VLAN of your ISP (VLAN6 for KPN).
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
   To get this address, you can obtain it by setting all bits outside the
   subnet mask of your IP range, for instance:
   ```
   192.168.X.1/24 => 192.168.X.255
   192.168.0.1/16 => 192.168.255.255
   ```
   See [here](https://en.wikipedia.org/wiki/Broadcast_address) for more information.

## Creating VLAN and obtaining IP address
The next challenge we face is that the UniFi interface currently does not support
having multiple VLAN interfaces on the same WAN port. Fortunately, since the
UDM/P runs Linux under the hood, we can configure our own VLAN interface.

To perform the configuration and obtain the IP address on IPTV network automatically,
I have created the following scripts. These have been tested for the UDM Pro.

**If you have the UDM base model**, please update the WAN port from `eth8` to `eth4`.

1. Create `/mnt/data/on_boot.d/10-iptv.sh`:
   ```bash
   #!/bin/sh
   WAN_PORT=eth8
   
   # Add IPTV VLAN (4) interface on WAN port
   ip link add link "$WAN_PORT" name iptv type vlan id 4
   # Start DHCP client on IPTV VLAN
   udhcpc -p /run/udhcpc-vlan.pid -d /bin/true -s /mnt/persistent/udhcpc-hook.sh -i iptv \
        -O 121 -x 60:'"IPTV_RG"' # DHCP options necessary for IPTV
   # NAT the IP-ranges to IPTV network
   iptables -t nat -A POSTROUTING -d 213.75.112.0/21 -j MASQUERADE -o iptv
   iptables -t nat -A POSTROUTING -d 217.166.0.0/16 -j MASQUERADE -o iptv
   ```
   **Note** that this script contains configuration specifically for KPN. You need
   to change this configuration (e.g., IP ranges, VLAN ID and DHCP options) depending on
   your ISP.
2. Create `/mnt/persistent/udhcpc-hook.sh`:
   ```bash
   #!/bin/sh
   # busybox udhcp setup script
   # shellcheck shell=sh disable=SC1008

   PATH=/bin:/usr/bin:/sbin:/usr/sbin

   peer_var()
   {
       [ -n "$1" ] && [ "$1" != "yes" ]
   }

   update_interface()
   {
       [ -n "${broadcast}" ] && broadcast="broadcast ${broadcast}"
       [ -n "${subnet}" ] && netmask="netmask ${subnet}"
       [ -n "${mtu}" ] && mtu="mtu ${mtu}"
       ifconfig "${interface}" ${ip} ${broadcast} ${netmask} ${mtu}
   }

   update_classless_routes()
   {
       if [ -n "${staticroutes}" ] ; then
           max_routes=128
           metric=
           [ -n "${IF_METRIC}" ] && metric="metric ${IF_METRIC}"
           while [ -n "$1" ] && [ -n "$2" ] && [ $max_routes -gt 0 ]; do
               gw_arg=
               if [ "$2" != '0.0.0.0' ]; then
                   gw_arg="gw $2"
               fi

               [ ${1##*/} -eq 32 ] && type=host || type=net
               route add -$type "$1" ${gw_arg} ${metric} dev "${interface}"
               max=$((max-1))
               shift 2
           done
       fi
   }
   update_routes()
   {
       peer_var "${PEER_ROUTERS}" && return

       # RFC 3442
       [ -n "${staticroutes}" ] && update_classless_routes $staticroutes

       # If the DHCP server returns both a Classless Static Routes option and
       # a Router option, the DHCP client MUST ignore the Router option.
       if [ -n "${router}" ] && [ -z "${staticroutes}" ] ; then
           metric=
           [ -n "${IF_METRIC}" ] && metric="metric ${IF_METRIC}"
           for i in ${router} ; do
               route add default gw "${i}" ${metric} dev "${interface}"
           done
       fi
   }

   deconfig()
   {
       ifconfig "${interface}" 0.0.0.0

       if ! peer_var "${PEER_ROUTERS}" ; then
           while route del default dev "${interface}" >/dev/null 2>&1; do
               :
           done
       fi
   }

   case "$1" in
       bound|renew)
           update_interface
           update_routes
           ;;
       deconfig|leasefail)
           deconfig
           ;;
       nak)
           echo "nak: ${message}"
           ;;
       *)
           echo "unknown option $1" >&2
           echo "Usage: $0 {bound|deconfig|leasefail|nak|renew}" >&2
           exit 1
           ;;
   esac

   exit 0
   ```
3. Make the scripts executable and run the configuration:
   ```bash
   chmod +x /mnt/data/on_boot.d/10-iptv.sh /mnt/persistent/udhcpc-hook.sh
   /mnt/data/on_boot.d/10-iptv.sh
   ```
4. Verify that the VLAN interface has obtained an IP address:
   ```bash
   $ ip -4 addr show dev iptv
   43: iptv@eth8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
      inet XX.XX.XX.XX/22 brd XX.XX.XX.XX scope global iptv
        valid_lft forever preferred_lft forever
   ```
5. Verify that you have obtained the routes from the DHCP server:
   ```bash
   $ ip route list
   ...
   XX.XX.XX.X/21 via XX.XX.XX.X dev iptv
   ```

## Configuring igmpproxy
The final step is to configure `igmpproxy`. This is necessary to bridge the 
multicast needed for IPTV between WAN and LAN.

1. Enter UniFi OS:
   ```bash
   unifi-os shell
   ```
2. Install `igmpproxy`:
   ```bash
   apt install igmpproxy 
   ```
3. Create `/etc/igmpproxy.conf`:
   ```bash
   quickleave

   phyint iptv upstream  ratelimit 0  threshold 1
       altnet 192.168.0.0/16 # LAN
       altnet 213.75.0.0/16 # Multicast addresses used by KPN
       altnet 217.166.0.0/16
   
   ## Update to br0 to bridge interface of target LAN!
   phyint br0 downstream  ratelimit 0  threshold 1 
   ```
   **Note:** This configuration contains IP ranges and interfaces specific
   to my KPN setup. Please modify to your specific setup.

   **Note:** If you have set up **IPSec VPN** networks on your UDM/P, make sure you
   disable the corresponding interfaces.
   See [IGMP Proxy terminates with unknown reason](#igmp-proxy-terminates-with-unknown-reason).
4. Add a dependency on the `unifi.service`. Run `systemctl edit igmpproxy` and
   enter:
   ```
   [Unit]
   PartOf=unifi.service
   After=unifi.service
   ```
5. Enable and start `igmpproxy`:
   ```bash
   systemctl enable --now igmpproxy
   ```

## Troubleshooting and Known Issues
Below is a non-exhaustive list of issues that might occur while getting IPTV to
run on the UDM/P. Please check these instructions before reporting an issue on issue tracker.

### IPTV stops working after changes to the UDM/P configuration
If you re-provision your UDM/P, IPTV might stop working. 
To workaround this issue, re-run the script:
```bash
# Re-create the VLAN and obtain IP
/mnt/data/on_boot.d/10-iptv.sh
# Restart IGMP Proxy
podman exec -it unifi-os systemctl restart igmpproxy
```

### IGMP Proxy terminates with unknown reason
If you are running any IPSec VPN on your UDM/P, make sure you disable the IPSec
interfaces in the IGMP Proxy configuration (in `/etc/igmpproxy.conf`) as follows:
```
...
# Repeat for each IPSec interface
phyint l2tp disabled
```
