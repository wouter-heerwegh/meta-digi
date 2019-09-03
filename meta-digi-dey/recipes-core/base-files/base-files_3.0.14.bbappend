# Copyright (C) 2013-2019 Digi International.

FILESEXTRAPATHS_prepend := "${THISDIR}/${BPN}:"

SRC_URI += " \
    file://sysctl.conf \
"

do_install_append() {
	install -m 0644 ${WORKDIR}/sysctl.conf ${D}${sysconfdir}/
}

pkg_postinst_ontarget_${PN}() {
	get_emmc_block_device() {
		emmc_number="$(sed -ne 's,.*mmcblk\(.\)boot0.*,\1,g;T;p' /proc/partitions)"
		if [ -b "/dev/mmcblk${emmc_number}" ] &&
		[ -b "/dev/mmcblk${emmc_number}boot0" ] &&
		[ -b "/dev/mmcblk${emmc_number}boot1" ] &&
		[ -b "/dev/mmcblk${emmc_number}rpmb" ]; then
			echo "/dev/mmcblk${emmc_number}"
		fi
	}

	RESIZE2FS="$(which resize2fs)"
	DM_BLOCK_DEVICE="/dev/dm-"
	EMMC_BLOCK_DEVICE="$(get_emmc_block_device)"
	if [ -x "${RESIZE2FS}" -a -n "${EMMC_BLOCK_DEVICE}" ]; then
		PARTITIONS="$(blkid ${EMMC_BLOCK_DEVICE}p* | sed -ne "{s,\(^${EMMC_BLOCK_DEVICE}[^:]\+\):.*TYPE=\"ext4\".*,\1,g;T;p}" | sort -u)"
		# Add possible device mapper devices
		PARTITIONS="${PARTITIONS} $(blkid ${DM_BLOCK_DEVICE}* | sed -ne "{s,\(^${DM_BLOCK_DEVICE}[^:]\+\):.*TYPE=\"ext4\".*,\1,g;T;p}" | sort -u)"
		for i in ${PARTITIONS}; do
			if ! ${RESIZE2FS} ${i} 2>/dev/null; then
				echo "ERROR: resize2fs ${i}"
			fi
		done
	fi

	# Disable file system check when rootfs is encrypted
	if [ -n "${TRUSTFENCE_INITRAMFS_IMAGE}" ]; then
		for arg in $(cat /proc/cmdline); do
			case "${arg}" in
				root=*) eval ${arg};;
			esac
		done
		# Are we running from NAND
		if echo "${root}" | grep -qs ubi; then
			root="/dev/${root}"
		else
			root="$(findfs ${root})"
		fi
		echo "${root}       /                    auto       defaults              0  0" >> /etc/fstab
	fi
}

CONFFILES_${PN} += "${sysconfdir}/sysctl.conf"
