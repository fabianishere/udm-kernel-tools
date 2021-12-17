# Maintenance Guide
This document contains instructions for developers and advanced users on how to
maintain `udm-kernel-tools`.

## Contents
 - [Building the source code](#building-the-source-code)
 - [Adding firmware support](#adding-firmware-support)
 - [Publishing a release](#publishing-a-release)
 - [Continuous Integration](#continuous-integration)

## Building the source code
#### Prerequisites
To start, make sure you have installed at least the following packages:

```bash
apt install devscripts debhelper wget git gcc-aarch64-linux-gnu bison flex libssl-dev
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

## Adding firmware support
For every new firmware release for the UDM/P, the tools need to be updated to
support the new release. This is necessary, since the kernel modules used by
this project need to be compiled for every firmware release in order to work.

Usually, this process is straightforward:
1. Create a directory for the new firmware version:
   ```bash
   mkdir debian/config/vX.X.X
   ```
   You can check the firmware version on your device as follows:
   ```bash
   cat /etc/os-release
   ```
2. Obtain the kernel configuration of the kernel of the new firmware release. If
   you have installed the new firmware release already, you can obtain the config
   as follows:
   ```bash
   scp root@IP-ADDRESS-UDM:/proc/config.gz debian/config/vX.X.X/config.udm.gz
   gunzip debian/config/vX.X.X/config.udm.gz 
   ```
3. Create a configuration file for this firmware release at `debian/config/vX.X.X/config.mk`:
   ```makefile
   UDM_VERSION = X.X.X
   # Commit on https://github.com/fabianishere/udm-kernel to build the kernel
   # modules against. Usually, taking the commit of the previous firmware version works. 
   UDM_COMMIT = cbc07337f9f10c2330e7e1e1c5a4c7019967286f
   ```
4. Add support for the new firmware version when building the package in `debian/rules`:
   ```makefile
   UDM_VERSIONS ?= 1.8.6 1.9.0 1.9.1 1.9.2 1.9.3 X.X.X
   ```

**What issues can occur?**  
In some cases, a new firmware version ships kernel changes that are needed
by the UniFi controller. In that case, using older kernels without these changes
are unable to function correctly. Make sure the custom kernels still work on
the new firmware version before publishing.

## Publishing a release
To publish a release, tag the commit associated with the release:
```bash
git tag -a -s v1.X.X
```
Afterwards, you can push the tag and build pipeline workflow will perform the
actual release procedure:
```bash
git push origin --tags
```

## Continuous Integration
To test changes to the project, open a pull request against this repository.
This will automatically build the changes and create an artifact with the
generated Debian files which you can test on your device.
