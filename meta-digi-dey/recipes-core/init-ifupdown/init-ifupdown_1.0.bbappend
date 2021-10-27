# Copyright (C) 2013-2021 Digi International Inc.

FILESEXTRAPATHS_prepend := "${THISDIR}/${BP}:"

INITSCRIPT_NAME = "networking"
INITSCRIPT_PARAMS = "start 03 2 3 4 5 . stop 80 0 6 1 ."

inherit systemd

WIFI_VIRTWLANS_FILES = " \
    file://interfaces.wlan1.static \
    file://interfaces.wlan1.dhcp \
    file://virtwlans \
"

SRC_URI_append = " \
    file://ifupdown.service \
    file://interfaces.br0.example \
    file://interfaces.p2p \
    file://p2plink \
    file://resolv \
    ${@oe.utils.conditional('HAS_WIFI_VIRTWLANS', 'true', '${WIFI_VIRTWLANS_FILES}', '', d)} \
"

SRC_URI_append_ccimx6sbc = " file://interfaces.br0.atheros.example"

SYSTEMD_SERVICE_${PN} = "ifupdown.service"

WPA_DRIVER ?= "nl80211"

IS_CCIMX6 ?= "0"
IS_CCIMX6_ccimx6sbc = "1"

do_install_append() {
	# Install 'ifupdown' scripts
	install -m 0755 ${WORKDIR}/p2plink ${D}${sysconfdir}/network/if-up.d/
	install -m 0755 ${WORKDIR}/resolv ${D}${sysconfdir}/network/if-up.d/

	# Install systemd service
	install -d ${D}${systemd_unitdir}/system/
	install -m 0644 ${WORKDIR}/ifupdown.service ${D}${systemd_unitdir}/system/
	sed -i -e 's,@SBINDIR@,${base_sbindir},g' ${D}${systemd_unitdir}/system/ifupdown.service

	if [ -n "${HAVE_WIFI}" ]; then
		if [ -n "${WLAN_P2P_INTERFACE}" ]; then
			cat ${WORKDIR}/interfaces.p2p >> ${D}${sysconfdir}/network/interfaces
			[ -n "${WLAN_P2P_AUTO}" ] && sed -i -e 's/^#auto ##WLAN_P2P_INTERFACE##/auto ##WLAN_P2P_INTERFACE##/g' ${D}${sysconfdir}/network/interfaces
			sed -i -e 's,##WLAN_P2P_INTERFACE##,${WLAN_P2P_INTERFACE},g' ${D}${sysconfdir}/network/interfaces
		fi
	fi

	# Remove config entries if corresponding variable is not defined
	[ -z "${P2P0_STATIC_DNS}" ] && sed -i -e "/##P2P0_STATIC_DNS##/d" ${D}${sysconfdir}/network/interfaces
	[ -z "${P2P0_STATIC_GATEWAY}" ] && sed -i -e "/##P2P0_STATIC_GATEWAY##/d" ${D}${sysconfdir}/network/interfaces
	[ -z "${P2P0_STATIC_IP}" ] && sed -i -e "/##P2P0_STATIC_IP##/d" ${D}${sysconfdir}/network/interfaces
	[ -z "${P2P0_STATIC_NETMASK}" ] && sed -i -e "/##P2P0_STATIC_NETMASK##/d" ${D}${sysconfdir}/network/interfaces

	# Replace interface parameters
	sed -i -e "s,##P2P0_STATIC_IP##,${P2P0_STATIC_IP},g" ${D}${sysconfdir}/network/interfaces
	sed -i -e "s,##P2P0_STATIC_NETMASK##,${P2P0_STATIC_NETMASK},g" ${D}${sysconfdir}/network/interfaces
	sed -i -e "s,##P2P0_STATIC_GATEWAY##,${P2P0_STATIC_GATEWAY},g" ${D}${sysconfdir}/network/interfaces
	sed -i -e "s,##P2P0_STATIC_DNS##,${P2P0_STATIC_DNS},g" ${D}${sysconfdir}/network/interfaces
	sed -i -e "s,##WPA_DRIVER##,${WPA_DRIVER},g" ${D}${sysconfdir}/network/interfaces

	# Install virtual wlans files
	if ${HAS_WIFI_VIRTWLANS}; then
		install_virtwlans
		install_wlan1
	fi

	# On ccimx6, install the two possible br0 fragments in the filesystem
	# so we can decide which one to use during runtime depending on the
	# wireless MAC used on the SOM.
	if [ "${IS_CCIMX6}" = "1" ]; then
		install -m 0644 ${WORKDIR}/interfaces.br0.example ${D}${sysconfdir}
		install -m 0644 ${WORKDIR}/interfaces.br0.atheros.example ${D}${sysconfdir}
	else
		cat ${WORKDIR}/interfaces.br0.example >> ${D}${sysconfdir}/network/interfaces
	fi
}

install_virtwlans() {
	install -d ${D}${sysconfdir}/network/if-pre-up.d
	install -m 0755 ${WORKDIR}/virtwlans ${D}${sysconfdir}/network/if-pre-up.d/
	ln -s ../if-pre-up.d/virtwlans ${D}${sysconfdir}/network/if-post-down.d/virtwlans
}

WLAN1_POST_UP_ACTION = "${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'systemctl start hostapd@wlan1.service', '/etc/init.d/hostapd start', d)}"
WLAN1_PRE_DOWN_ACTION = "${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'systemctl stop hostapd@wlan1.service', '/etc/init.d/hostapd stop', d)}"

install_wlan1() {
	TARGET_WLAN1_FILE="${D}${sysconfdir}/network/interfaces"

	if [ -n "${HAVE_WIFI}" ]; then
		# On the ccimx6, install the wlan1 fragment in the filesystem
		# so we can decide if we want to incorporate it or not
		# depending on the wireless MAC used on the SOM.
		if [ "${IS_CCIMX6}" = "1" ]; then
			TARGET_WLAN1_FILE="${D}${sysconfdir}/interfaces.wlan1.example"
			install -m 0644 ${WORKDIR}/interfaces.wlan1.${WLAN1_MODE} ${TARGET_WLAN1_FILE}
		else
			cat ${WORKDIR}/interfaces.wlan1.${WLAN1_MODE} >> ${TARGET_WLAN1_FILE}
		fi
		[ -n "${WLAN1_AUTO}" ] && sed -i -e 's/^#auto wlan1/auto wlan1/g' ${TARGET_WLAN1_FILE}
	fi

	# Remove config entries if corresponding variable is not defined
	[ -z "${WLAN1_STATIC_DNS}" ] && sed -i -e "/##WLAN1_STATIC_DNS##/d" ${TARGET_WLAN1_FILE}
	[ -z "${WLAN1_STATIC_GATEWAY}" ] && sed -i -e "/##WLAN1_STATIC_GATEWAY##/d" ${TARGET_WLAN1_FILE}
	[ -z "${WLAN1_STATIC_IP}" ] && sed -i -e "/##WLAN1_STATIC_IP##/d" ${TARGET_WLAN1_FILE}
	[ -z "${WLAN1_STATIC_NETMASK}" ] && sed -i -e "/##WLAN1_STATIC_NETMASK##/d" ${TARGET_WLAN1_FILE}

	# Replace interface parameters
	sed -i -e "s,##WLAN1_STATIC_IP##,${WLAN1_STATIC_IP},g" ${TARGET_WLAN1_FILE}
	sed -i -e "s,##WLAN1_STATIC_NETMASK##,${WLAN1_STATIC_NETMASK},g" ${TARGET_WLAN1_FILE}
	sed -i -e "s,##WLAN1_STATIC_GATEWAY##,${WLAN1_STATIC_GATEWAY},g" ${TARGET_WLAN1_FILE}
	sed -i -e "s,##WLAN1_STATIC_DNS##,${WLAN1_STATIC_DNS},g" ${TARGET_WLAN1_FILE}
	sed -i -e "s,##WLAN1_POST_UP_ACTION##,${WLAN1_POST_UP_ACTION},g" ${TARGET_WLAN1_FILE}
	sed -i -e "s,##WLAN1_PRE_DOWN_ACTION##,${WLAN1_PRE_DOWN_ACTION},g" ${TARGET_WLAN1_FILE}
}

# Disable wireless interfaces on first boot for non-wireless variants
pkg_postinst_ontarget_${PN}() {
	if [ ! -d "/proc/device-tree/wireless" ]; then
		sed -i -e '/^auto wlan/{s,^,#,g};/^auto p2p/{s,^,#,g}' /etc/network/interfaces
	fi

	# Create the symlinks in the different runlevels
	if type update-rc.d >/dev/null 2>/dev/null; then
		update-rc.d ${INITSCRIPT_NAME} ${INITSCRIPT_PARAMS}
	fi

	COMPAT="/proc/device-tree/compatible"
	WIFI_MAC="/proc/device-tree/wireless/mac-address"

	# Only execute the script on wireless ccimx6 platforms
	if [ -e ${WIFI_MAC} -a $(grep fsl,imx6dl ${COMPAT} || grep fsl,imx6q ${COMPAT} | grep -v fsl,imx6qp) ]; then
		for id in $(find /sys/devices -name modalias -print0 | xargs -0 sort -u -z | grep sdio); do
			if [[ "$id" == "sdio:c00v0271d0301" ]] ; then
				cat /etc/interfaces.br0.atheros.example >> /etc/network/interfaces
				rm /etc/network/if-pre-up.d/virtwlans /etc/network/if-post-down.d/virtwlans
				break
			elif [[ "$id" == "sdio:c00v0271d050A" ]] ; then
				cat /etc/interfaces.wlan1.example >> /etc/network/interfaces
				cat /etc/interfaces.br0.example >> /etc/network/interfaces
				break
			fi
		done
		rm /etc/interfaces.*.example
	fi

	exit 0
}

inherit ${@bb.utils.contains("IMAGE_FEATURES", "read-only-rootfs", "remove-pkg-postinst-ontarget", "", d)}
