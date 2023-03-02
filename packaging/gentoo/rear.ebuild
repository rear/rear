# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4

DESCRIPTION="Fully automated disaster recovery supporting a broad variety of backup strategies and scenarios"
HOMEPAGE="http://relax-and-recover.org/"
SRC_URI="https://github.com/rear/rear/archive/${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="udev"

RDEPEND="net-fs/nfs-utils
	sys-apps/iproute2
	sys-apps/lsb-release
	sys-apps/util-linux
	sys-apps/gawk
	sys-block/parted
	sys-boot/syslinux
	virtual/cdrtools
	udev? ( sys-fs/udev )
	dev-libs/openssl
"

src_compile () {
	true
}

src_install () {
	# deploy udev USB rule and udev will autostart ReaR workflows in case a USB
	# drive with the label 'REAR_000' is connected, which in turn is the
	# default label when running the `rear format` command.
	if use udev; then
		insinto /lib/udev/rules.d
		doins etc/udev/rules.d/62-${PN}-usb.rules
	fi

	# copy configurations files
	insinto /etc
	doins -r etc/${PN}/

	# copy main script-file and docs
	dosbin usr/sbin/${PN}
	doman doc/${PN}.8
	dodoc README.adoc

	insinto /usr/share/
	doins -r usr/share/${PN}/
}

