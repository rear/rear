%define rpmrelease %{nil}

### Work-around the fact that OpenSUSE/SLES _always_ defined both :-/
%if 0%{?sles_version} == 0
%undefine sles_version
%endif

Summary: Relax-and-Recover is a Linux disaster recovery and system migration tool
Name: rear
Version: 1.14
Release: 1%{?rpmrelease}%{?dist}
License: GPLv3
Group: Applications/File
URL: http://relax-and-recover.org/

# as GitHub stopped with download section we need to go back to Sourceforge for downloads
#Source: https://github.com/downloads/rear/rear/rear-%{version}.tar.gz
Source: https://sourceforge.net/projects/rear/files/rear/%{version}/rear-%{version}.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildArch: noarch

### Dependencies on all distributions
Requires: binutils
Requires: ethtool
Requires: gzip
Requires: iputils
Requires: mingetty
Requires: parted
Requires: tar
Requires: util-linux
Requires: openssl

### If you require NFS, you may need the below packages
#Requires: nfsclient portmap rpcbind

### We drop LSB requirements because it pulls in too many dependencies
### The OS is hardcoded in /etc/rear/os.conf instead
#Requires: redhat-lsb

### Required for Bacula/MySQL support
#Requires: bacula-mysql

### Required for OBDR
#Requires: lsscsi sg3_utils

### Optional requirement
#Requires: cfg2html

%ifarch %ix86 x86_64
Requires: syslinux
%endif
%ifarch ppc ppc64
Requires: yaboot
%endif

%if %{?suse_version:1}0
Requires: iproute2
### recent SuSE versions have an extra nfs-client package
### and switched to genisoimage/wodim
%if 0%{?suse_version} >= 1020
Requires: genisoimage
%else
Requires: mkisofs
%endif
###
%if %{!?sles_version:1}0
Requires: lsb
%endif
%endif

%if %{?mandriva_version:1}0
Requires: iproute2
### Mandriva switched from 2008 away from mkisofs,
### and as a specialty call the package cdrkit-genisoimage!
%if 0%{?mandriva_version} >= 2008
Requires: cdrkit-genisoimage
%else
Requires: mkisofs
%endif
#Requires: lsb
%endif

### On RHEL/Fedora the genisoimage packages provides mkisofs
%if %{?centos_version:1}%{?fedora_version:1}%{?rhel_version:1}0
Requires: crontabs
Requires: iproute
Requires: mkisofs
#Requires: redhat-lsb
%endif

### The rear-snapshot package is no more
Obsoletes: rear-snapshot

%description
Relax-and-Recover is the leading Open Source disaster recovery and system
migration solution, and successor to mkcdrec. It comprises of a modular
framework and ready-to-go workflows for many common situations to produce
a bootable image and restore from backup using this image. As a benefit,
it allows to restore to different hardware and can therefore be used as
a migration tool as well.

Currently Relax-and-Recover supports various boot media (incl. ISO, PXE,
OBDR tape, USB or eSATA storage), a variety of network protocols (incl.
sftp, ftp, http, nfs, cifs) as well as a multitude of backup strategies
(incl.  IBM TSM, HP DataProtector, Symantec NetBackup, Bacula, rsync).

Relax-and-Recover was designed to be easy to set up, requires no maintenance
and is there to assist when disaster strikes. Its setup-and-forget nature
removes any excuse for not having a disaster recovery solution implemented.

Professional services and support are available.

%prep
%setup -q

echo "30 1 * * * root /usr/sbin/rear checklayout || /usr/sbin/rear mkrescue" >rear.cron

### Add a specific os.conf so we do not depend on LSB dependencies
%{?fedora:echo -e "OS_VENDOR=Fedora\nOS_VERSION=%{?fedora}" >etc/rear/os.conf}
%{?mdkversion:echo -e "OS_VENDOR=Mandriva\nOS_VERSION=%{distro_rel}" >etc/rear/os.conf}
%{?rhel:echo -e "OS_VENDOR=RedHatEnterpriseServer\nOS_VERSION=%{?rhel}" >etc/rear/os.conf}
%{?sles_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=%{?sles_version}" >etc/rear/os.conf}
### Doesn't work as, suse_version for OpenSUSE 11.3 is 1130
#%{?suse_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=%{?suse_version}" >etc/rear/os.conf}

%build

%install
%{__rm} -rf %{buildroot}
%{__make} install DESTDIR="%{buildroot}"
%{__install} -Dp -m0644 rear.cron %{buildroot}%{_sysconfdir}/cron.d/rear
#%{__install} -Dp -m0644 etc/udev/rules.d/62-rear-usb.rules %{buildroot}%{_sysconfdir}/udev/rules.d/62-rear-usb.rules

%clean
%{__rm} -rf %{buildroot}

%files
%defattr(-, root, root, 0755)
%doc AUTHORS COPYING README doc/*.txt
%doc %{_mandir}/man8/rear.8*
%config(noreplace) %{_sysconfdir}/cron.d/rear
%config(noreplace) %{_sysconfdir}/rear/
#%config(noreplace) %{_sysconfdir}/udev/rules.d/62-rear-usb.rules
%{_datadir}/rear/
%{_localstatedir}/lib/rear/
%{_sbindir}/rear

%changelog
* Thu Apr 11 2013 Gratien D'haese <gratien.dhaese@gmail.com>
- changes Source

* Thu Jun 03 2010 Dag Wieers <dag@wieers.com>
- Initial package. (using DAR)
