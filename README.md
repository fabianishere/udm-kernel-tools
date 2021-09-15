# udm-kernel-tools [![Release](https://github.com/fabianishere/udm-kernel-tools/actions/workflows/release.yml/badge.svg)](https://github.com/fabianishere/udm-kernel-tools/actions/workflows/release.yml)
Tools for bootstrapping custom Linux kernels on the Ubiquiti UniFi Dream
Machine (Pro).

## Introduction
The Ubiquiti [UniFi Dream Machine](https://unifi-network.ui.com/dreammachine)
(UDM) and UDM Pro are a class of all-in-one network appliances built by Ubiquiti.
These devices are powered by UbiOS, which uses Linux kernel under the hood.

However, the stock kernel on these devices lacks some important functionality
needed for common use-cases (such as WireGuard as VPN or multicast routing support for IPTV).
In many cases, this functionality can be enabled with a custom Linux kernel.

This repository provides tools to bootstrap a custom Linux kernel on the UDM/P.
To prevent bricking your device, this tool does not overwrite the firmware of
the device.
Instead, it boots directly into the custom kernel from the stock kernel
using [kexec](https://en.wikipedia.org/wiki/Kexec) (see [How it works](#how-it-works)).

## Use-cases
There are currently several use-cases for using a custom kernel on the
UniFi Dream Machine (Pro). These use-cases include:

1. **In-kernel [WireGuard](https://wireguard.com) support**  
   Although you can already run a WireGuard server on your UDM/P using `wireguard-go` (see 
   [udm-utilities](https://github.com/boostchicken/udm-utilities)), its performance
   will be reduced due to it running in user-space. A custom kernel enables your 
   WireGuard VPN server to utilize the kernel implementation and run at full speed.
2. [**Multicast routing support**](docs/iptv.md)  
   The stock kernel of the UDM/P does not support multicast routing which is
   needed for running `igmpproxy`. In turn, `igmpproxy` is needed to bridge
   multicast traffic between WAN and LAN, which is needed for IPTV.
   See the [following guide](docs/iptv.md) for more information.
3. [**Early boot modifications**](#overriding-files-on-root-pre-boot)  
   Since changes to root filesystem on the UDM/P are non-persistent. It is not
   possible with the stock kernel to perform modification to the early boot
   process (since the [on-boot-script](https://github.com/boostchicken/udm-utilities/blob/master/on-boot-script/README.md) only runs after UniFi OS is started).
   This project enables you to modify the root filesystem before UbiOS is started.
   See [Overriding files on root pre-boot](#overriding-files-on-root-pre-boot) for more information. 

## Getting Started
### Disclaimer 
Although these tools do not modify any firmware on your device, using them might
lead to **system instability** or **data loss**.
Make sure you know what you are doing and ensure you have a **backup**! 
I take no responsibility for any damage that might occur as result of using this
project.

### Entering UniFi OS
To start, SSH into your UniFi Dream Machine (Pro) and enter the UniFi OS shell
as follows:
```bash
unifi-os shell
```

### Installing udm-kernel-tools
Select from the [Releases](https://github.com/fabianishere/udm-kernel-tools/releases) page
the package version you want to install and download the selected Debian package,
for instance:

```bash
wget https://github.com/fabianishere/udm-kernel-tools/releases/download/v1.1.0/udm-kernel-tools_1.1.0_arm64.deb
apt install ./udm-kernel-tools_1.1.0_arm64.deb
```

### Installing a custom kernel
To obtain and install a custom Linux kernel for the UniFi Dream Machine (Pro),
visit the [udm-kernel](https://github.com/fabianishere/udm-kernel) repository.
This repository contains instructions for installing the pre-built kernels as
well as instructions for building custom kernels yourself.

### Booting into a custom kernel 
First, list the kernels you have installed on your system as follows:
```bash
udm-bootctl list
```

Booting into a custom kernel is then done as follows:
```bash
udm-bootctl boot KERNEL_VERSION
```
Alternatively, you may specify the path to the kernel image.
**Note** that after executing this command, the SSH connection might become 
unresponsive or might even be killed with an error message. This is expected
behavior and after a minute, you should be able to log back into your device
via SSH.

Once the system is back online, verify that you are running the correct kernel:
```bash
uname -a
```

### Auto-booting into the custom kernel
Since the custom kernel does not persist across reboots due to the use of _kexec_,
you need to perform the boot procedure after every reboot. 
We provide a `udm-autoboot.service` to automate this process.

First, select the default kernel you want to boot into:
```bash
udm-bootctl set-default KERNEL_VERSION
```
Then, enable the `udm-autoboot.service` to run during system startup:
```bash
systemctl enable udm-autoboot.service
```

**Disabling auto-boot**  
To disable this functionality again, run the following command:
```bash
systemctl disable udm-autoboot.service
```

### Overriding files on root pre-boot
Some users may wish to modify files on the root filesystem before UniFi OS boots
(e.g., to hook into the early boot process).
In order to facilitate this, `udm-kernel-tools` allows users to override files
from the root filesystem using an overlay located  at `/mnt/data/udm-kernel-tools/root`,

The overlay filesystem will be mounted *only* after running 
`mkdir -p /overlay/root_ro/mnt/data/udm-kernel-tools/root` from within the *UniFi OS* shell
or when running `mkdir -p /data/udm-kernel-tools/root` from outside UniFi OS. 

Note that changes to this directory only appear on the root filesystem after
reboot.

### Restoring the stock kernel
If you are running a custom kernel and wish to return the stock kernel, simply
reboot the device (from UbiOS):
```bash
reboot
```

### Removing udm-kernel-tools
To remove `udm-kernel-tools` and the custom kernels you have installed, run
the following command in UniFi OS:

```bash
apt remove udm-kernel*
```

This will remove the artifacts on your device related to this project.

## Compatibility
Since the project requires firmware-specific binaries (e.g., kernel modules), you
possibly need to upgrade the tools after you have upgraded to a new firmware version.
Currently, the releases of this project support the following firmware versions:

- 1.8.6
- 1.9.3
- 1.10.0

To build the project for custom firmware versions, please refer to the [Maintenance Guide](MAINTENANCE.md).

## Troubleshooting
Below is a non-exhaustive list of issues that might occur while using these
tools. Please check these instructions before reporting an issue on issue tracker.

**Device reboots into stock kernel**  
When your device still reports after the boot procedure that it is running the
stock kernel, check the logs for errors:
```bash
# Check ramoops
cat /sys/fs/pstore/*
# Check kernel log
dmesg
```

**Device appears to be stuck**  
When you cannot connect to your device a few minutes after performing the boot
procedure, the device might be stuck. Power cycle the device to restore
the stock kernel.

**SSH session exits with error after boot command**  
After executing the `boot` command, your SSH connection might become unresponsive
or even exit with an error message. This is expected behavior, and you should
be able to log back in to your device after a minute.

## Contributing
Questions, suggestions and contributions are welcome and appreciated!
You can contribute in various meaningful ways:

* Report a bug through [Github issues](https://github.com/fabianishere/udm-kernel-tools/issues).
* Propose and document use-cases for using this project.
* Contribute improvements to the documentation.  
* Provide feedback about how we can improve the project.
* Help answer questions on our [Discussions](https://github.com/fabianishere/udm-kernel-tools/discussions) page.

Advanced users may also be interested in the [Maintenance Guide](MAINTENANCE.md).

## How it works
Bootstrapping a custom Linux kernel on the UDM/P is not trivial. By default,
UniFi OS restricts user capabilities on Linux significantly, to such an extent
that even changes to the root filesystem are not persistent without [a workaround](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script).

Although [udm-unlock](https://github.com/fabianishere/udm-unlock) can be used
to overwrite the kernel boot image or root filesystem, such an approach is fragile
and might lead to a bricked device.  

To prevent touching the UDM/P firmware for booting a custom Linu kernel, we can
employ Linux' [kexec](https://en.wikipedia.org/wiki/Kexec) functionality, which
enables Linux to act as a second stage bootloader for a custom kernel. 

Since _kexec_ is not supported natively by the stock kernel running on the
UDM/P, I have backported this functionality as a 
[loadable kernel module](https://github.com/fabianishere/kexec-mod).
These tools use the _kexec_ backport to load a custom kernel into memory and boot
directly into the custom kernel. With this, we do not need to modify the device
firmware and in case of issues, we can simply power-cycle the device.

While we can now boot into a custom Linux kernel, we will find that UbiOS requires
several proprietary kernel modules to properly function. To address this issue,
during the [initramfs phase](https://en.wikipedia.org/wiki/Initial_ramdisk), we
prepare a workaround that force-inserts the proprietary modules into the kernel,
even when the versions do not match (see [here](https://github.com/fabianishere/udm-kernel-tools/blob/32f0816089c5187f4ff13e3c68f9ea2f6325c591/udm-init#L45) for the implementation).

## License
The code is released under the GPLv2 license. See [COPYING.txt](/COPYING.txt).
