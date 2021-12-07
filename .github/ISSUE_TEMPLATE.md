#### Relax-and-Recover (ReaR) Issue Template

Fill in the following items before submitting a new issue
(quick response is not guaranteed with free support):

* ReaR version ("/usr/sbin/rear -V"):

* OS version ("cat /etc/os-release" or "lsb_release -a" or "cat /etc/rear/os.conf"):

* ReaR configuration files ("cat /etc/rear/site.conf" and/or "cat /etc/rear/local.conf"):

* Hardware vendor/product (PC or PowerNV BareMetal or ARM) or VM (KVM guest or PowerVM LPAR):

* System architecture (x86 compatible or PPC64/PPC64LE or what exact ARM device):

* Firmware (BIOS or UEFI or Open Firmware) and bootloader (GRUB or ELILO or Petitboot):

* Storage (local disk or SSD) and/or SAN (FC or iSCSI or FCoE) and/or multipath (DM or NVMe):

* Storage layout ("lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,LABEL,SIZE,MOUNTPOINT"):

* Description of the issue (ideally so that others can reproduce it):

* Workaround, if any:

* Attachments, as applicable ("rear -D mkrescue/mkbackup/recover" debug log files):

To paste verbatim text like command output or file content,
include it between a leading and a closing line of three backticks like
````
```
verbatim content
```
````
