SUMMARY = "iCal and scheduling (RFC 2445, 2446, 2447) library"
HOMEPAGE = "https://github.com/libical/libical"
BUGTRACKER = "https://github.com/libical/libical/issues"
LICENSE = "LGPLv2.1 | MPL-2.0"
LIC_FILES_CHKSUM = "file://LICENSE;md5=1910a2a76ddf6a9ba369182494170d87 \
                    file://LICENSE.LGPL21.txt;md5=933adb561f159e7c3da079536f0ed871 \
                    file://LICENSE.MPL2.txt;md5=f75d2927d3c1ed2414ef72048f5ad640 \
                    "
SECTION = "libs"

FILESEXTRAPATHS_prepend := "${COREBASE}/meta/recipes-support/libical/libical:"

SRC_URI = " \
    https://github.com/${BPN}/${BPN}/releases/download/v${PV}/${BP}.tar.gz \
    file://0001-Use-our-hand-build-native-src-generator.patch \
"
SRC_URI[md5sum] = "41bd1f1fcdcb4779cea478bb55cf07bf"
SRC_URI[sha256sum] = "09fecacaf75ba5a242159e3a9758a5446b5ce4d0ab684f98a7040864e1d1286f"
UPSTREAM_CHECK_URI = "https://github.com/libical/libical/releases"

inherit cmake pkgconfig

PACKAGECONFIG ??= "icu glib"
PACKAGECONFIG[bdb] = ",-DCMAKE_DISABLE_FIND_PACKAGE_BDB=True,db"
PACKAGECONFIG[glib] = "-DICAL_GLIB=True,-DICAL_GLIB=False,glib-2.0-native libxml2-native glib-2.0 libxml2"
# ICU is used for RSCALE (RFC7529) support
PACKAGECONFIG[icu] = ",-DCMAKE_DISABLE_FIND_PACKAGE_ICU=True,icu"

# No need to use perl-native, the host perl is sufficient.
EXTRA_OECMAKE += "-DPERL_EXECUTABLE=${HOSTTOOLS_DIR}/perl"
# doc build fails with linker error (??) for libical-glib so disable it
EXTRA_OECMAKE += "-DICAL_BUILD_DOCS=false"

do_install_append () {
    # Remove build host references
    sed -i \
       -e 's,${STAGING_LIBDIR},${libdir},g' \
       -e 's,${STAGING_INCDIR},${includedir},g' \
       ${D}${libdir}/cmake/LibIcal/LibIcal*.cmake
}
