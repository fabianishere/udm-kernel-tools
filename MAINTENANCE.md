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
