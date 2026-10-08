
# Integrating external backup programs into ReaR

Relax-and-Recover can be used only to restore the disk layout of your system and boot loader. However, that means you are responsible for taking backups. And, more important, to restore these before you reboot recovered system.

However, we have successfully already integrated external backup programs within ReaR, such as Netbackup, EMC NetWorker, Tivoli Storage Manager, Data Protetctor to name a few commercial backup programs. Furthermore, open source external backup programs which are also working with ReaR are Bacula, Bareos, Duplicity and Borg to name the most known ones.

Ah, my backup program which is the best of course, is not yet integrated within ReaR. How shall we proceed to make your backup program working with ReaR? This is a step by step approach.

The work-flow `mkrescue` is the only needed as `mkbackup` will not create any backup as it is done outside ReaR anyhow. Very important to know.

## Think before coding

Well, what does this mean? Is my backup program capable of making full backups of my root disks, including ACLs? And, as usual, did we test a restore of a complete system already? Can we do a restore via the command line, or do we need a graphical user interface to make this happen?
If the CLI approach is working then this would be the preferred manor for ReaR. If on the other hand only GUI approach is possible, then can you initiate a push from the media server instead of the pull method (which we could program within ReaR)?

So, most imprtant things to remember here are:

 * CLI - preferred method (and far the easiest one to integrate within ReaR) - pull method
 * GUI - as ReaR has no X Windows available (only command line) we cannot use the GUI within ReaR, however, GUI is still possible from another system (media server or backup server) and push out the restore to the recovered system. This method is similar to the REQUESTRESTORE BACKUP method.

What does ReaR need to have on board before we can initiate a restore from your backup program?

 * the executables (and libraries) from your backup program (only client related)
 * configuration files required by above executables?
 * most likely you need the manuals a bit to gather some background information of your backup program around its minimum requirements

## Steal code from previous backup integrations

Do not make your life too difficult by re-invented the wheel. Have a look at existing integrations. How?

Start with the default configuration file of ReaR:

    $ cd /usr/share/rear/conf
    $ grep -r NBU *
    default.conf:# BACKUP=NBU (Cohesity NetBackup)
    default.conf:COPY_AS_IS_NBU=(
    default.conf:COPY_AS_IS_EXCLUDE_NBU=(
    default.conf:NBU_LD_LIBRARY_PATH="/usr/openv/lib:/usr/openv/netbackup/sec/at/lib:/usr/openv/lib/boost"
    default.conf:NBU_TRUE_IMAGE_RESTORE="true"
    default.conf:NBU_ALLOW_SERVER_AS_CLIENT="false"

`COPY_AS_IS_NBU` and `COPY_AS_IS_EXCLUDE_NBU` are each defined as a multi-line array in
`default.conf` (see that file directly for the full element lists), which is why `grep` only
shows their opening line here rather than every path inside them.

What does this learn you?

 * you need to define a backup method name, e.g. `BACKUP=NBU` (must be unique within ReaR!)
 * define some new variables to automatically copy executables into the ReaR rescue image, and one to exclude stuff which is not required by the recovery (this means you have to play with it and fine-tune it)
 * optionally, define your own `BACKUP=<NAME>`-specific variables for anything your integration needs to tune (NBU uses a few, like `NBU_TRUE_IMAGE_RESTORE` above, to toggle behavior without editing the scripts themselves).

Some other `BACKUP=` methods also define a `PROGS_<NAME>` placeholder array of required executables that ReaR checks for before running - NBU does not need one, since its whole NetBackup installation is captured wholesale via `COPY_AS_IS_NBU` rather than as a list of individual binaries.

Now, you have defined a new BACKUP scheme name, right? As an example take the name BURP (http://burp.grke.org/).

Define in /usr/share/rear/conf/default:

    # BACKUP=BURP section (Burp program stuff)
    COPY_AS_IS_BURP=( )
    COPY_AS_IS_EXCLUDE_BURP=( )
    PROGS_BURP=( )

Of course, the tricky part is what should above arrays contain? That you should already know as that was part of the first task (*Think before coding*).

This is only the start of learning what others have done before:

    $ cd /usr/share/rear
    $ find . -name NBU
    ./finalize/NBU
    ./prep/NBU
    ./rescue/NBU
    ./restore/NBU
    ./skel/NBU
    ./verify/NBU

What does this mean? Well, these are directories created for Netbackup and beneath these directories are scripts that will be included during the `mkrescue` and `recover` work-flows. See `20-Cohesity-NBU.md` for a full description of what this particular integration does, if you want a worked example of a complete, real backend rather than just its file layout.

Again, think burp, and you probably also need these directories to be created:

    $ mkdir --mode=755 /usr/share/rear/{finalize,prep,rescue,restore,verify}/BURP


Another approach is to look at the existing scripts of NBU (as a starter):

    $ sudo rear -s mkrescue | grep NBU
    Source prep/NBU/default/350_check_nbu_client_version.sh
    Source prep/NBU/default/400_prep_nbu.sh
    Source prep/NBU/default/450_check_nbu_client_configured.sh
    Source rescue/NBU/default/450_prepare_netbackup.sh

    $ sudo rear -s recover | grep NBU
    Source verify/NBU/default/250_check_nbu_client_name.sh
    Source verify/NBU/default/300_parse_bp_conf.sh
    Source verify/NBU/default/350_start_netbackup.sh
    Source verify/NBU/default/400_verify_nbu.sh
    Source verify/NBU/default/450_request_client_source.sh
    Source verify/NBU/default/500_request_pit_restore_parameters.sh
    Source restore/NBU/default/400_restore_with_nbu.sh
    Source finalize/NBU/default/900_restore_vxss_credentials.sh
    Source finalize/NBU/default/990_copy_bplogrestorelog.sh

