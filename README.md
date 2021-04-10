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
Alternatively, you may specify the path to the kernel image. After executing the
command, the SSH connection will become unresponsive and eventually terminate 
when the device reboots.

Once the system is back online, verify that you are running the correct kernel:
```bash
uname -a
```

### Auto-booting into the custom kernel
Since the custom kernel does not persist across reboots due to the use of kexec,
you need to perform the boot procedure after every reboot. We provide a `udm-autoboot.service`
to automate this process.

First, select the default kernel you want to boot into:
```bash
udm-bootctl set-default KERNEL_VERSION
```
Then, enable the `udm-autoboot.service` to run during system startup:
```bash
systemctl enable udm-autoboot.service
```

### Overriding files on root pre-boot
Some users wish to modify files on the root filesystem before UniFi OS boots (e.g.,
to hook into the early boot process). In order to facilitate this, `udm-kernel-tools`
allows users to override files from the root filesystem using an overlay located
at `/mnt/data/udm-kernel-tools/root`. 

Note that changes to this directory only appear on the root filesystem after
reboot.

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
