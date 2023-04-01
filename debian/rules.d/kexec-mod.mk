# -*- makefile -*-

# Copyright (C) 2021 Fabian Mastenbroek.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.


BUILD_DIR ?= build

# The location from which the kernel sources are downloaded
UDM_COMMIT = 261fc64a700803935326bad8301bdde3f62e4f05
UDM_KERNEL_URL ?= https://github.com/fabianishere/udm-kernel/archive/${UDM_COMMIT}.tar.gz
UDM_KERNEL_TARBALL := ${BUILD_DIR}/$(shell basename ${UDM_KERNEL_URL})
UDM_KERNEL_SRC ?= ${BUILD_DIR}/kernel
UDM_MODULE_DIR ?= ${BUILD_DIR}/modules

KEXEC_MOD_SRC ?= kexec-mod

# Cross compilation settings
export ARCH=${DEB_TARGET_ARCH}
export CROSS_COMPILE=${DEB_TARGET_MULTIARCH}-

.PHONY: all
all: ${UDM_MODULE_DIR}/kexec_mod.ko ${UDM_MODULE_DIR}/kexec_mod_arm64.ko

${UDM_KERNEL_TARBALL}:
	mkdir -p $(dir ${UDM_KERNEL_TARBALL})/
	wget -P $(dir ${UDM_KERNEL_TARBALL})/ -N $(if ${GITHUB_TOKEN},--header="Authorization: token ${GITHUB_TOKEN}") ${UDM_KERNEL_URL}

${UDM_KERNEL_SRC}: ${UDM_KERNEL_TARBALL}
	mkdir -p $@
	tar -C $@ --strip-components=1 -xf ${UDM_KERNEL_TARBALL}

${UDM_KERNEL_SRC}/.config: debian/udm.config | ${UDM_KERNEL_SRC}
	ln -s $(realpath $<) $@
	$(MAKE) -C ${UDM_KERNEL_SRC} olddefconfig LOCALVERSION=
	$(MAKE) -C ${UDM_KERNEL_SRC} modules_prepare LOCALVERSION=

${UDM_MODULE_DIR}/kexec_mod.ko ${UDM_MODULE_DIR}/kexec_mod_${ARCH}.ko: ${UDM_KERNEL_SRC}/.config
	mkdir -p ${UDM_MODULE_DIR}
	dh_auto_build --sourcedirectory=${KEXEC_MOD_SRC}/kernel -- KDIR=$(realpath ${UDM_KERNEL_SRC}) LDFLAGS=
	cp ${KEXEC_MOD_SRC}/kernel/kexec_mod.ko ${UDM_MODULE_DIR}/kexec_mod.ko
	cp ${KEXEC_MOD_SRC}/kernel/arch/${ARCH}/kexec_mod_${ARCH}.ko ${UDM_MODULE_DIR}/kexec_mod_${ARCH}.ko

.PHONY: clean
clean:
ifneq ($(realpath ${UDM_KERNEL_SRC}),)
	dh_auto_clean --sourcedirectory=${KEXEC_MOD_SRC}/kernel -- KDIR=$(realpath ${UDM_KERNEL_SRC})
endif
	rm -rf ${BUILD_DIR}
