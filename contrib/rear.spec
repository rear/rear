Summary: Relax and Recover (Rear) is a Linux Disaster Recovery framework
Name: rear
Version: 1.13.0
Release: 1%{?dist}
License: GPLv3
Group: Applications/File
URL: http://rear.github.com/

Source: rear-%{version}.tar.bz2
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildArch: noarch

### Dependencies on all distributions
Requires: binutils
Requires: ethtool
##Requires: genisoimage
Requires: gzip
Requires: iproute
Requires: iputils
Requires: mingetty
Requires: mkisofs
Requires: parted
Requires: portmap
##Requires: rpcbind
Requires: tar
Requires: util-linux

### We drop LSB requirements because it pulls in too many dependencies
### We hardcode the OS in /etc/rear/os.conf instead
##Requires: redhat-lsb

### Required for Bacula/MySQL support
#Requires: bacula-mysql

### Required for OBDR
#Requires: lsscsi
#Requires: sg3_utils

### Optional requirement
#Requires: cfg2html

%ifarch %ix86 x86_64
Requires: syslinux
%endif
%ifarch ppc ppc64
Requires: yaboot
%endif

%description
Relax and Recover (abbreviated Rear) is a highly modular disaster recovery
framework for GNU/Linux based systems, but can be easily extended to other
UNIX alike systems. The disaster recovery information (and maybe the backups)
can be stored via the network, local on hard disks or USB devices, DVD/CD-R,
tape, etc. The result is also a bootable image that is capable of booting via
PXE, DVD/CD and USB media.

Relax and Recover integrates with other backup software and provides integrated
bare metal disaster recovery abilities to the compatible backup software.

%prep
%setup

echo "30 1 * * * root /usr/sbin/rear checklayout || /usr/sbin/rear mkrescue" >rear.cron

### Add a specific os.conf so we do not depend on LSB dependencies
%{?rhel:echo -e "OS_VENDOR=RedHatEnterpriseServer\nOS_VERSION=%{?rhel}" >etc/rear/os.conf}
%{?fedora:echo -e "OS_VENDOR=Fedora\nOS_VERSION=%{?fedora}" >etc/rear/os.conf}
%{?suse_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=%{?suse_version}" >etc/rear/os.conf}
%{?sles_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=%{?sles_version}" >etc/rear/os.conf}
%{?mdkversion:echo -e "OS_VENDOR=Mandriva\nOS_VERSION=%{distro_rel}" >etc/rear/os.conf}

%build

%install
%{__rm} -rf %{buildroot}
%{__make} install DESTDIR="%{buildroot}"
%{__install} -Dp -m0644 rear.cron %{buildroot}%{_sysconfdir}/cron.d/rear
%{__install} -Dp -m0644 etc/udev/rules.d/62-rear-usb.rules %{buildroot}%{_sysconfdir}/udev/rules.d/62-rear-usb.rules

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, root, root, 0755)
%doc AUTHORS COPYING README doc/*.html doc/*.txt
%doc %{_mandir}/man8/rear.8*
%config(noreplace) %{_sysconfdir}/cron.d/rear/
%config(noreplace) %{_sysconfdir}/rear/
%config(noreplace) %{_sysconfdir}/udev/rules.d/62-rear-usb.rules
%{_datadir}/rear/
%{_localstatedir}/lib/rear/
%{_sbindir}/rear

%changelog
* Thu Jun 03 2010 Dag Wieers <dag@wieers.com>
- Initial package. (using DAR)
