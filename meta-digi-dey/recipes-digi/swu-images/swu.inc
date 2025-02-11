# Copyright (C) 2016-2021 Digi International Inc.
SUMMARY = "Generate update package for SWUpdate"
SECTION = "base"
LICENSE = "GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

SRC_URI = "file://sw-description"

inherit swupdate

IMAGE_DEPENDS = "${@get_baseimg_pn(d)}"

IMG_NAME = "${IMAGE_DEPENDS}"

SWUPDATE_IMAGES = "${IMG_NAME}"

SOFTWARE_VERSION ?= "0.0.1"
DESCRIPTION = "${@oe.utils.ifelse(d.getVar('TRUSTFENCE_ENCRYPT_ROOTFS', True) == '1', 'Encrypted rootfs ${IMG_NAME} update', '${IMG_NAME} update')}"

BOOTFS_EXT ?= ".boot.vfat"
BOOTFS_EXT_ccimx6ul ?= ".boot.ubifs"
ROOTFS_EXT ?= ".ext4.gz"
ROOTFS_EXT_ccimx6ul ?= '${@bb.utils.contains("IMAGE_FEATURES", "read-only-rootfs", ".squashfs", ".ubifs", d)}'

BOOT_DEV_NAME ?= "/dev/mmcblk0p1"
BOOT_DEV_NAME_ccimx6ul ?= "linux"
ROOTFS_DEV_NAME ?= "/dev/mmcblk0p3"
ROOTFS_DEV_NAME_ccimx6ul ?= "rootfs"
ROOTFS_ENC_DEV = "/dev/mapper/cryptrootfs"
ROOTFS_ENC_DEV_ccimx6ul = "${ROOTFS_DEV_NAME}"
ROOTFS_DEV_NAME_FINAL = "${@oe.utils.ifelse(d.getVar('TRUSTFENCE_ENCRYPT_ROOTFS', True) == '1', '${ROOTFS_ENC_DEV}', '${ROOTFS_DEV_NAME}')}"

python () {
    img_fstypes = d.getVar('BOOTFS_EXT', True) + " " + d.getVar('ROOTFS_EXT', True)
    d.setVarFlag("SWUPDATE_IMAGES_FSTYPES", d.getVar('IMG_NAME', True), img_fstypes)
}

python do_swuimage_prepend() {
    import glob

    if (d.getVar('TRUSTFENCE_SIGN', True) == "1"):
        d.setVar('SWUPDATE_PRIVATE_KEY', glob.glob(d.getVar('SWUPDATE_PRIVATE_KEY_TEMPLATE', True))[0])
}

def get_baseimg_pn(d):
    file_name = d.getVar('PN', True)
    return file_name[:file_name.find("-swu")]

do_unpack[postfuncs] += "fill_description"

fill_description() {
	sed -i -e "s,##BOOTIMG_NAME##,${IMG_NAME}-${MACHINE}${BOOTFS_EXT},g" "${WORKDIR}/sw-description"
	sed -i -e "s,##BOOT_DEV##,${BOOT_DEV_NAME},g" "${WORKDIR}/sw-description"
	sed -i -e "s,##ROOTIMG_NAME##,${IMG_NAME}-${MACHINE}${ROOTFS_EXT},g" "${WORKDIR}/sw-description"
	sed -i -e "s,##ROOTFS_DEV##,${ROOTFS_DEV_NAME_FINAL},g" "${WORKDIR}/sw-description"
	sed -i -e "s,##SW_VERSION##,${SOFTWARE_VERSION},g" "${WORKDIR}/sw-description"
	sed -i -e "s,##DESCRIPTION##,${DESCRIPTION},g" "${WORKDIR}/sw-description"
}
