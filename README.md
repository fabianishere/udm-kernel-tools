# udm-kernel-tools
Tools for bootstrapping custom Linux kernels on the Ubiquiti UniFi Dream
Machine (Pro).

## Introduction
The Ubiquiti [UniFi Dream Machine](https://unifi-network.ui.com/dreammachine)
(UDM) and UDM Pro are a class of all-in-one network appliances built by Ubiquiti.
These devices are powered by UniFi OS, which uses Linux kernel under the hood.

This repository contains a set of tools for bootstrapping custom Linux kernels on
UDM/UDM-Pro devices in order to enable use-cases not possible with the stock kernel, for instance:

- In-kernel Wireguard support
- Multicast routing

Running a custom Linux kernel on the UDM/UDM-Pro is not trivial. By default,
UniFi OS restricts user capabilities on Linux significantly, to such an extent
that even changes to the root filesystem are not persistent without [a workaround](https://github.com/boostchicken/udm-utilities/tree/master/on-boot-script)).
Although [udm-unlock](https://github.com/fabianishere/udm-unlock) could be used
to overwrite the kernel boot image, due to kernel image signature verification,
this will probably result in a bricked device.

We can work around this issue by employing Linux' [kexec](https://en.wikipedia.org/wiki/Kexec)
functionality, which enables Linux to act as a second stage bootloader for a
custom kernel. Since _kexec_ is not supported by the stock kernel running on the
UDM/UDM-Pro, we must backport this it using a [loadable kernel module](https://github.com/fabianishere/kexec-mod).

## Installation
SSH into your UniFi Dream Machine and enter the UniFi OS shell as follows:
```bash
unifi-os shell
```

Select from the [Releases](https://github.com/fabianishere/pve-edge-kernel/releases) page
the package version you want to install and download the selected Debian package,
for instance:

```bash
wget https://github.com/fabianishere/udm-kernel-tools/releases/download/v1.0.0/udm-kernel-tools_1.0.0_arm64.deb
apt install ./udm-kernel-tools_1.0.0_arm64.deb
```

## Usage
**Warning**  
Using these tools might lead to system instability or data loss.
Make sure you know what you are doing and ensure you have a backup!

Enter again the UniFi OS shell on your device:
```bash
unifi-os shell
```

Now boot into the custom kernel as follows:
```bash
udm-bootctl boot /path/to/kernel/image
```
The SSH connection will become unresponsive and eventually terminate when the device reboots. 

### Obtaining kernel images
To built a custom kernel image or download a custom pre-built kernel for your
UniFi Dream Machine, visit the [udm-kernel](https://github.com/fabianishere/udm-kernel) repository.

## Building manually
You may also choose to build the package yourself.

#### Prerequisites
To start, make sure you have installed at least the following packages:

```bash
apt install devscripts debhelper wget git gcc-aarch64-linux-gnu
```

#### Obtaining the source
```bash
git clone --recursive https://github.com/fabianishere/udm-kernel-tools
```

#### Building
Navigate now to the root directory of the repository and build the package
as follows:
```bash
debuild -uc -us -aarm64 --lintian-opts --profile debian
```
This will generate in the parent directory the Debian package which you can
install on your device.

## License
The code is released under the GPLv2 license. See [COPYING.txt](/COPYING.txt).
