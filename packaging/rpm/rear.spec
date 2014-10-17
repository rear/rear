%define rpmrelease %{nil}

### Work-around the fact that OpenSUSE/SLES _always_ defined both :-/
%if 0%{?sles_version} == 0
%undefine sles_version
%endif

Summary: Relax-and-Recover is a Linux disaster recovery and system migration tool
Name: rear
Version: 1.16.1
Release: 1%{?rpmrelease}%{?dist}
License: GPLv3
Group: Applications/File
URL: http://relax-and-recover.org/

# as GitHub stopped with download section we need to go back to Sourceforge for downloads
Source: https://sourceforge.net/projects/rear/files/rear/%{version}/rear-%{version}.tar.gz

BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildArch: noarch

### Dependencies on all distributions
Requires: binutils
Requires: ethtool
Requires: gzip
Requires: iputils
Requires: parted
Requires: tar
Requires: openssl
Requires: gawk
Requires: attr

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
#%if %{!?sles_version:1}0
#Requires: lsb
#%endif
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

# mingetty is not available anymore with RHEL 7 (use agetty instead via systemd)
# Note that CentOS also has %rhel defined so there is no need to use %centos
%if 0%{?rhel} && 0%{?rhel} > 6
Requires: util-linux
%else
Requires: mingetty
Requires: util-linux
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
(incl.  IBM TSM, HP DataProtector, Symantec NetBackup, EMC NetWorker,
Bacula, Bareos, rsync).

Relax-and-Recover was designed to be easy to set up, requires no maintenance
and is there to assist when disaster strikes. Its setup-and-forget nature
removes any excuse for not having a disaster recovery solution implemented.

Professional services and support are available.

%pre
if [ $1 -gt 1 ] ; then
# during upgrade remove obsolete directories
%{__rm} -rf %{_datadir}/rear/output/NETFS
fi

%prep
%setup -q 

echo "30 1 * * * root /usr/sbin/rear checklayout || /usr/sbin/rear mkrescue" >rear.cron

### Add a specific os.conf so we do not depend on LSB dependencies
%{?fedora:echo -e "OS_VENDOR=Fedora\nOS_VERSION=%{?fedora}" >etc/rear/os.conf}
%{?mdkversion:echo -e "OS_VENDOR=Mandriva\nOS_VERSION=%{distro_rel}" >etc/rear/os.conf}
%{?rhel:echo -e "OS_VENDOR=RedHatEnterpriseServer\nOS_VERSION=%{?rhel}" >etc/rear/os.conf}
#%{?sles_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=%{?sles_version}" >etc/rear/os.conf}
#%{?suse_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=%{?suse_version}" >etc/rear/os.conf}
%if 0%{?suse_version} == 1110
# SLE 11
OS_VERSION="11"
%endif
%if 0%{?suse_version} == 1130
# openSUSE 11.3
OS_VERSION="11.3"
%endif
%if 0%{?suse_version} == 1140
# openSUSE 11.4
OS_VERSION="11.4"
%endif
%if 0%{?suse_version} == 1210
# openSUSE 12.1
OS_VERSION="12.1"
%endif
%if 0%{?suse_version} == 1220
# openSUSE 12.2
OS_VERSION="12.2"
%endif
%if 0%{?suse_version} == 1230
# openSUSE 12.3
OS_VERSION="12.3"
%endif
%if 0%{?suse_version} == 1310
# openSUSE 13.1
OS_VERSION="13.1"
%endif
%if 0%{?suse_version} == 1315
# SLE 12
OS_VERSION="12"
%endif
%if 0%{?suse_version} == 1320
# openSUSE 13.2
OS_VERSION="13.2"
%endif
%{?suse_version:echo -e "OS_VENDOR=SUSE_LINUX\nOS_VERSION=$OS_VERSION" >etc/rear/os.conf}

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
* Fri Oct 17 2014 Gratien D'haese <gratien.dhaese@gmail.com>
- added the suse_version lines to identify the corresponding OS_VERSION

* Fri Jun 20 2014 Gratien D'haese <gratien.dhaese@gmail.com>
- add %%pre section

* Thu Apr 11 2013 Gratien D'haese <gratien.dhaese@gmail.com>
- changes Source

* Thu Jun 03 2010 Dag Wieers <dag@wieers.com>
- Initial package. (using DAR)
