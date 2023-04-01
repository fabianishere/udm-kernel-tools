# udm-kernel-tools [![Release](https://github.com/fabianishere/udm-kernel-tools/actions/workflows/release.yml/badge.svg)](https://github.com/fabianishere/udm-kernel-tools/actions/workflows/release.yml)
Tools for bootstrapping custom Linux kernels on the Ubiquiti UniFi Dream
Machine (Pro).

## Introduction
The Ubiquiti [UniFi Dream Machine](https://unifi-network.ui.com/dreammachine)
(UDM) and UDM Pro are a class of all-in-one network appliances built by Ubiquiti, 
which use the Linux kernel under the hood.

The stock kernel on these devices lacks some important functionality needed for
common use-cases (multipath routing, eBPF, containers). In many cases, this
functionality can be enabled with a custom Linux kernel.

This repository provides tools to bootstrap a custom Linux kernel on the UDM/P.
To prevent bricking your device, this tool does not overwrite the firmware of
the device. Instead, it boots directly into the custom kernel from the stock 
kernel using [kexec](https://en.wikipedia.org/wiki/Kexec) (see [How it works](#how-it-works)).


## Getting Started
### Disclaimer 
Although these tools do not modify any firmware on your device, using them might
lead to **system instability** or **data loss**.
Make sure you know what you are doing and ensure you have a **backup**! 
I take no responsibility for any damage that might occur as result of using this
project.

### Installing udm-kernel-tools
Select from the [Releases](https://github.com/fabianishere/udm-kernel-tools/releases) page
the package version you want to install and download the selected Debian package,
for instance:

```bash
wget https://github.com/fabianishere/udm-kernel-tools/releases/download/v2.0.0/udm-kernel-tools_2.0.0_arm64.deb
apt install ./udm-kernel-tools_2.0.0_arm64.deb
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
apt remove 'udm-kernel*'
```

This will remove the artifacts on your device related to this project.

## Compatibility
From version 2 onwards, only UniFi Dream Machine (Pro) firmware versions 2 and
above are supported by this project. If you need support for older firmware,
please install any of the versions below 2.

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

* Report a bug through [GitHub issues](https://github.com/fabianishere/udm-kernel-tools/issues).
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

To prevent touching the UDM/P firmware for booting a custom Linux kernel, we can
employ Linux's [kexec](https://en.wikipedia.org/wiki/Kexec) functionality, which
enables Linux to act as a second stage bootloader for a custom kernel. 

Since _kexec_ is not supported natively by the stock kernel running on the
UDM/P, I have backported this functionality as a 
[loadable kernel module](https://github.com/fabianishere/kexec-mod).
These tools use the _kexec_ backport to load a custom kernel into memory and boot
directly into the custom kernel. With this, we do not need to modify the device
firmware and in case of issues, we can simply power-cycle the device.

## License
The code is released under the GPLv2 license. See [COPYING.txt](/COPYING.txt).
