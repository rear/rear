# Relax-and-Recover Linux Disaster Recovery &amp; Bare Metal Restore

Relax-and-Recover (abbreviated ReaR) is the de facto standard disaster recovery framework on Linux.

It is in particular used on enterprise Linux distributions like Red Hat Enterprise Linux (RHEL)
and SUSE Linux Enterprise Server (SLES).

ReaR is a system administrator tool and framework to create a bootable disaster recovery system image
for bare metal disaster recovery with data backup restore on physical or virtual replacement hardware.

For bare metal disaster recovery the ReaR recovery system is booted on pristine replacement hardware.
On replacement hardware first the storage setup/layout is recreated (disk partitioning, filesystems, mount points),
then a backup restore program is called to restore the data (system files) into the recreated storage,
and finally a boot loader is installed.

System administrators use the ReaR framework to set up a disaster recovery procedure
as part of their disaster recovery policy (which complements their existing backup policy).

ReaR complements backup and restore of data with bare metal disaster recovery. ReaR can also act as local backup software,
but ReaR is not a a backup management software. In many enterprise environmentments, data backup and restore happens via dedicated backup software which is integrated by ReaR and used to restore the data onto a replacement system as part of the automated disaster recovery procedure implemented by ReaR.

ReaR has support for built-in backup methods using 'tar' and 'rsync' that are used for backup and restore.

ReaR integrates supports the following 3rd party, also commercial, tools for restoring a backup.

The complete list of backup methods (`BACKUP=...`) is:

* `AVA` Dell EMC Avamar / EMC Avamar
* `BACULA` Bacula
* `BAREOS` [Bareos](https://docs.bareos.org/Appendix/DisasterRecoveryUsingBareos.html#linux)
* `BLOCKCLONE` block device cloning via `dd`
* `BORG` Borg Backup
* `CDM` Rubrik Cloud Data Management
* `DP` OpenText Data Protector
* `DUPLICITY` Duplicity / Duply
* `EXTERNAL` External custom restore method
* `FDRUPSTREAM` FDR/Upstream
* `GALAXY11` Commvault Galaxy 11 / Commvault Simpana
* `NBKDC` NovaStor DataCenter
* `NBU` Veritas NetBackup / Symantec NetBackup
* `NETFS` ReaR built-in backup and restore via `rsync` or `tar` to a network file system or to a locally attached backup disk (USB, eSATA, ...)
* `NFS4SERVER` NFS4 server to push data *to* the rescue system
* `NSR` Dell EMC NetWorker / EMC NetWorker / Legato NetWorker
* `OBDR` One Button Disaster Recovery via tape
* `PPDM` [Dell PowerProtect Data Manager](https://infohub.delltechnologies.com/en-us/t/simplifying-linux-bmr-for-powerprotect-data-manager-using-rear-relax-and-recover-disaster-recovery-solution/)
* `RBME` [Rsync Backup Made Easy](https://github.com/schlomo/rbme)
* `REQUESTRESTORE` Request restore from a human operator
* `RSYNC` ReaR built-in backup using `rsync` via `rsync` or `ssh` protocol
* `SESAM` [SEP Sesam](https://wiki.sep.de/wiki/index.php/Bare_Metal_Recovery_Linux)
* `TSM` IBM Storage Protect / Tivoli Storage Manager / IBM Spectrum Protect
* `VEEAM` Veeam Backup

ReaR integrates well with Disaster Recovery Linux Manager (DRLM) [drlm.org](https://drlm.org), which can act as a central management tool for ReaR deployments.

[Professional services and support are available.](https://relax-and-recover.org/support/)

## REQUIREMENTS

Relax-and-Recover is written entirely in Bash and does not require any
external programs. It utilizes the standard tools on your Linux system to
create the rescue system, and works out of the box on most systems.

ReaR supports many different use cases and includes support for many 3rd party backup tools. Therefore
our packages have only the dependencies for the ReaR core functionality, but not for all the tools
required for all the ReaR features. This is to keep your install size small when you don't need all the features. When using it, ReaR will let you know if your specific use case or workflow requires additional tools and ask you to install them.

## QUICK START GUIDE

**Note**: Instead of cloning the sources from GitHub you can also download and install a snapshot build from our [GitHub Releases](https://github.com/rear/rear/releases) page and continue from `rear format`.

This quick start guide shows how to run Relax-and-Recover from the git checkout
and create a bootable USB backup and rescue medium.

Start by cloning the Relax-and-Recover sources from GitHub:

```shell
git clone https://github.com/rear/rear.git
````

Move into the 'rear/' directory (it gets created by `git clone`):

```shell
cd rear/
````

Prepare your USB medium.

Change `/dev/sdX` to the correct device in your environment.
Relax-and-Recover will 'own' the whole device.

**This will destroy all data on that device.**

```shell
sudo usr/sbin/rear format /dev/sdX
```

Relax-and-Recover asks you to confirm that you want to format your USB device:

```shell
Yes
````

The device gets labeled `REAR-000` by the `rear format` workflow.

Now edit the `etc/rear/local.conf` configuration file:

```shell
### write the rescue initramfs to USB and update the USB bootloader
OUTPUT=USB

### create a backup using the internal NETFS method, using 'tar'
BACKUP=NETFS

### write both rescue image and backup to the device labeled REAR-000
BACKUP_URL=usb:///dev/disk/by-label/REAR-000
```

Ensure you have at least defined the *OUTPUT*, *BACKUP* and *BACKUP_URL* variables.

Now you are ready to create a ReaR rescue image on your USB device.
We want verbose output (-v option):

```shell
sudo usr/sbin/rear -v mkrescue
````

The output you get will look like this:
```
Relax-and-Recover <version>
Using log file: /var/log/rear/rear-<hostname>.log
Creating disk layout
Creating root filesystem layout
Copying files and directories
Copying binaries and libraries
Copying kernel modules
Creating initramfs
Writing MBR to /dev/sdX
Copying resulting files to usb location
```

You may check the log file for possible errors or see more details what Relax-and-Recover is doing.

Now reboot your system and verify that you can boot the ReaR rescue environment from your USB device as a test.
In the ReaR rescue environment log in as `root` (no password) and directly shut it down (it was only a test).

Again boot your normal system.

In your normal system (with your `REAR-000` labeled USB rescue device connected)
create a backup of your system (provided your USB device has enough space) by using:

```shell
sudo usr/sbin/rear -v mkbackup
```

The output you get will look like the above but now with a backup done at the end.

When all went well (also check the log file),
you have a bootable USB rescue medium with a backup of your system.

You are now better prepared for disaster recovery.

If your system got destroyed you can boot from your USB backup and rescue medium,
log in as `root` into the ReaR rescue environment and call `rear -v recover`.
This will completely re-create your system from scratch and restore your backup
which will destroy and overwrite all previously existing data on your system disk.
So to test if `rear recover` works, you need fully compatible replacement hardware
where you can verify that `rear recover` works (at least on your replacement hardware).

## INSTALLATION

We recommend installing a suitable `rear` package that we provide, see the [Relax-and-Recover Download page](https://relax-and-recover.org/download/). On RHEL, SUSE, Ubuntu, Debian, Arch Linux, and other distributions, you can install the package with the package manager of your distribution.

Alternatively as a software developer you may manually build it from the source tree with:

```shell
make package
```

This will create a package for your distribution in `dist`.

Alternatively as a software developer you may install manually via:

```shell
make install
```

Do not mix different installation methods.

You should remove a package before doing a manual installation.

## CONFIGURATION

**Note:** This is just a quick overview, please take a look at our full [Relax-and-Recover documentation](https://relax-and-recover.org/documentation/) for more details.

To configure Relax-and-Recover you have to edit the configuration files in

`/etc/rear/`. All `*.conf` files there are part of the configuration, but
only `site.conf` and `local.conf` are intended for the user configuration.
All other configuration files hold defaults for various distributions and
should not be changed.

In `/etc/rear/templates/` there are also some template files which are use by
Relax-and-Recover to create configuration files (mostly for the boot
environment). You can use these templates to prepend your own configurations
to the configuration files created by Relax-and-Recover, for example you can
edit `PXE_pxelinux.cfg` to add some general pxelinux configuration you use
(I put there stuff to install Linux over the network).

In almost all circumstances you have to configure two main settings and their
parameters: The *BACKUP* method and the *OUTPUT* method.

The backup method defines how your data is to be saved and whether Relax-and-Recover
should backup your data as part of the mkrescue process or whether you use an
external application, e.g. backup software to archive your data.

The output method defines how the rescue system is written to disk and how you
plan to boot the failed computer from the rescue system.

See `/usr/share/rear/conf/default.conf` for an overview of the possible methods
and their options. An example to use TSM for backup and PXE for output and
would be to add these lines to `/etc/rear/local.conf`:

```shell
BACKUP=TSM
OUTPUT=PXE
```

And since all your computers use NTP for time synchronisation, you should also add these lines to `/etc/rear/local.conf`:

```shell
TIMESYNC=NTP
```

Don’t forget to distribute the `local.conf` to all your systems.

The resulting PXE files (kernel, initrd and pxelinux configuration) will be
written to files in `/var/lib/rear/output/`. You can now modify the behaviour
by copying the appropriate configuration variables from `default.conf` to
`local.conf` and changing them to suit your environment.

In this example we used the `local.conf` file which is intended for local and *manual* configuration. To distribute the configuration to all your systems you should use the `site.conf` file which is intended for *automated* configuration. This file will never be part of the `rear` package to avoid conflicts between our packages and your configuration management. To this end our `local.conf` doesn't actually contain any settings by default.

## USAGE

To use Relax-and-Recover you always call the main script `/usr/sbin/rear`:

```
# rear help

Usage: rear [-h|--help] [-V|--version] [-dsSv] [-D|--debugscripts SET] [-c DIR] [-C CONFIG] [-r KERNEL] [-n|--non-interactive] [-e|--expose-secrets] [-p|--portable] [--] COMMAND [ARGS...]

Relax-and-Recover comes with ABSOLUTELY NO WARRANTY; for details see
the GNU General Public License at: http://www.gnu.org/licenses/gpl.html

Available options:
 -h --help              usage information (this text)
 -c DIR                 alternative config directory; instead of /src/rear/etc/rear
 -C CONFIG              additional config files; absolute path or relative to config directory
 -d                     debug mode; run many commands verbosely with debug messages in log file (also sets -v)
 -D                     debugscript mode; log executed commands via 'set -x' (also sets -v and -d)
 --debugscripts SET     same as -d -v -D but debugscript mode with 'set -SET'
 -r KERNEL              kernel version to use; currently '5.15.0-204.147.6.3.el9uek.x86_64'
 -s                     simulation mode; show what scripts are run (without executing them)
 -S                     step-by-step mode; acknowledge each script individually
 -v                     verbose mode; show messages what Relax-and-Recover is doing on the terminal or show verbose help
 -n --non-interactive   non-interactive mode; aborts when any user input is required (experimental)
 -e --expose-secrets    do not suppress output of confidential values (passwords, encryption keys) in particular in the log file
 -p --portable          allow running any ReaR workflow, especially recover, from a git checkout or rear source archive
 -V --version           version information


List of commands:
 checklayout     check if the disk layout has changed
 dump            dump configuration and system information
 format          Format and label medium for use with ReaR
 mkbackup        create rescue media and backup system
 mkbackuponly    backup system without creating rescue media
 mkopalpba       create a pre-boot authentication (PBA) image to boot from TCG Opal 2-compliant self-encrypting disks
 mkrescue        create rescue media only
 mountonly       use ReaR as live media to mount and repair the system
 opaladmin       administrate TCG Opal 2-compliant self-encrypting disks
 recover         recover the system
 restoreonly     only restore the backup
 validate        submit validation information
Use 'rear -v help' for more advanced commands.
```

To view/verify your configuration, run `rear dump`. It will print out the
current settings for *BACKUP* and *OUTPUT* methods and some system information.

To create a new rescue environment, simply call `rear mkrescue`. Do not forget
to copy the resulting rescue system away so that you can use it in the case of
a system failure. Use `rear mkbackup` instead if you are using the builtin
backup functions (like `BACKUP=NETFS`)

To recover your system, start the replacement computer from the rescue system and run
`rear recover`. Your system will be recovered and you can restart it and
continue to use it normally.

## AUTHORS AND MAINTAINERS

The ReaR project was initiated in 2006 by [Schlomo Schapiro](https://github.com/schlomo) and [Gratien D’haese](https://github.com/gdha) and has since then seen a lot of contributions by many authors. As ReaR deals with bare metal disaster recovery, there is a large amount of code that was contributed by owners and users of specialized hardware and software. Without their combined efforts and contributions ReaR would not be the universal Linux bare metal disaster recovery solution that it is today.

As time passed the project was lucky to get the support of additional developers to also help as maintainers: [Dag Wieers](https://github.com/dagwieers), [Jeroen Hoekx](https://github.com/jhoekx), [Johannes Meixner](https://github.com/jsmeix), [Vladimir Gozora](https://github.com/gozora), [Sébastien Chabrolles](https://github.com/schabrolles), [Renaud Métrich](https://github.com/rmetrich) and [Pavel Cahyna](https://github.com/pcahyna). We hope that ReaR continues to prove useful and to attract more developers who agree to be maintainers. Please refer to the [MAINTAINERS](MAINTAINERS) file for the list of active and past maintainers.

To see the full list of authors and their contributions please look at the [git history](https://github.com/rear/rear/graphs/contributors). We are very thankful to all authors and encourage anybody interested to take a look at our source code and to contribute what you find important.
