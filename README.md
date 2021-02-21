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
UDM/UDM-Pro, we must backport this it using a [loadable kernel module](https://github.com/fabianishere/kexec-mod-arm64).

## License
The code is released under the GPLv2 license. See [COPYING.txt](/COPYING.txt).
