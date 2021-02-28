#!/bin/sh
# SysV init script to reboot into a new kernel using kexec.
#
# Copyright (C) 2021 Fabian Mastenbroek.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

do_stop() {
    export LD_PRELOAD=/usr/lib/udm-kernel-tools/redir.so

    test "x`cat /sys/kernel/kexec_loaded`y" = "x1y" || exit 0
    test -x /sbin/kexec || exit 0

    printf "Rebooting machine using kexec..."
    # Clear the screen if possible
    printf "\033[;H\033[2J"
    /sbin/kexec -e
    printf "error: kexec failed"
}

case "$1" in
  start)
    # No-op
    ;;
  restart|reload)
    echo "Error: argument '$1' not supported"
    exit 3
    ;;
  stop)
    do_stop
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 3
    ;;
esac

exit $?
