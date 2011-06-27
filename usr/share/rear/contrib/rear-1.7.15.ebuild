# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $


inherit eutils depend.php

DESCRIPTION="Rear - Relax and Recover | Disaster Recovery for GNU/Linux"
HOMEPAGE="http://rear.sourceforge.net/"
SRC_URI="mirror://sourceforge/${PN}/${P}.tar.gz"
KEYWORDS="~amd64 x86"
LICENSE="GPL-2"
SLOT="1"

RDEPEND="sys-apps/util-linux
	net-dialup/mingetty
	sys-apps/lsb-release
	sys-apps/iproute2
	net-fs/nfs-utils
	sys-boot/syslinux
	app-cdr/cdrtools"

S=${WORKDIR}

src_unpack() {
        unpack ${A}
}

src_compile() {
        einfo "Nothing to compile."
}

src_install() {
	dodir /usr/share/rear /etc/rear
	cp -rPR ${S}/${P}/etc/rear/* "${D}etc/rear"
	cp -rPR ${S}/${P}/usr/share/rear/* "${D}usr/share/rear"
	dosbin ${S}/${P}/usr/sbin/rear
}

pkg_config() {
	einfo Rear - Relax and Recover was successfully installed
	einfo you can get information about configuration on
	einfo the website http://rear.sourceforge.net/documentation.php
}
