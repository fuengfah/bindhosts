#!/bin/sh
PATH=$PATH:/data/adb/ap/bin:/data/adb/magisk:/data/adb/ksu/bin
MODDIR="/data/adb/modules/bindhosts"
. $MODDIR/utils.sh
SUSFS_BIN=/data/adb/ksu/bin/ksu_susfs

# always try to prepare hosts file
if [ ! -f $MODDIR/system/etc/hosts ]; then
	mkdir -p $MODDIR/system/etc
	cat /system/etc/hosts > $MODDIR/system/etc/hosts
	printf "127.0.0.1 localhost\n::1 localhost\n" >> $MODPATH/system/etc/hosts
fi
susfs_clone_perm "$MODDIR/system/etc/hosts" /system/etc/hosts

# detect operating operating_modes

# normal operating_mode
# all managers? (citation needed) can operate at this operating_mode
# this assures that we have atleast a base operating operating_mode
mode=0
skip_mount=0

# ksu+susfs operating_mode
# susfs exists so we can hide the bind mount if binary is available 
# and kmsg has 'susfs_init'. though this has an issue if KSU_SUSFS_ENABLE_LOG=n
# we just hope in here that they were built with =y
if [ ${KSU} = true ] && [ -f ${SUSFS_BIN} ] ; then
	dmesg | grep -q "susfs_init" && {
		mode=1
		skip_mount=1
		}
fi

# plain bindhosts operating mode, no hides at all
# we enable this on apatch if its NOT on magisk mount
# as this allows better compatibility
# on current apatch ci, magic mount is now opt-out
# if apatch and doesnt have override; then check for envvar
# if no envar or false, mode 2.
# this logic we catch old versions that doesnt have the envvar
# so every apatch on overlayfs will fall onto this.
if [ $APATCH = true ] && [ ! -f /data/adb/.bind_mount_enable ]; then 
	if [ -z $APATCH_BIND_MOUNT ] || [ $APATCH_BIND_MOUNT = false ]; then
		mode=2
		skip_mount=1
	fi
fi

# hosts_file_redirect operating_mode
# this method is APatch only
# no other heuristic other than dmesg
if [ $APATCH = true ]; then
	dmesg | grep -q "hosts_file_redirect" && {
	mode=3
	skip_mount=1
	}
fi

# ZN-hostsredirect operating_mode
# method works for all, requires zn-hostsredirect + zygisk-next
# while `znctl dump-zn` gives us an idea if znhr is running, 
# znhr starts at late service when we have to decide what to do NOW.
# we can only assume that it is on a working state
# here we unconditionally flag an operating_mode for it
if [ -d /data/adb/modules/hostsredirect ] && [ ! -f /data/adb/modules/hostsredirect/disable ] && 
	[ -d /data/adb/modules/zygisksu ] && [ ! -f /data/adb/modules/zygisksu/disable ]; then
	mode=4
	skip_mount=1
fi

# override operating mode here
[ -f /data/adb/bindhosts/mode_override.sh ] && {
	echo "bindhosts: post-fs-data.sh - mode_override found!" >> /dev/kmsg
	skip_mount=1 
	. /data/adb/bindhosts/mode_override.sh
	[ $mode = 0 ] && skip_mount=0
	}

# write operating mode to mode.sh 
# service.sh will read it
echo "operating_mode=$mode" > $MODDIR/mode.sh
# skip_mount or not
[ $skip_mount = 0 ] && ( [ -f $MODDIR/skip_mount ] && rm $MODDIR/skip_mount )
[ $skip_mount = 1 ] && ( [ ! -f $MODDIR/skip_mount ] && touch $MODDIR/skip_mount )

# debugging
echo "bindhosts: post-fs-data.sh - probing done" >> /dev/kmsg

#EOF
