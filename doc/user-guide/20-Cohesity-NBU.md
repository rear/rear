
# Documentation for the Cohesity NetBackup (NBU) Backup and Restore Method

## Summary

Cohesity NetBackup (formerly Symantec/Veritas NetBackup) is Cohesity's enterprise backup
product. Protection is policy-based and managed by three roles: a **primary server** that owns
the catalog, schedules jobs, and coordinates every backup and restore; one or more **media
servers** that move backup data to and from storage; and **clients**, the protected hosts,
each running the NetBackup client software. Every host in this topology authenticates to every
other host with an X.509 host ID-based certificate, issued by the primary acting as a
Certificate Authority and brokered by the `pbx`, `nbatd`, and `nbwmc` services. A client with no
valid certificate cannot exchange backup or restore traffic with its primary at all.

Backups are full or incremental, driven by policy, and tracked per client in the primary's
catalog. A policy can optionally enable **True Image Restore (TIR)**: when enabled, NetBackup
also records which files existed at the time of each backup, so a restore to a given point in
time can reproduce a directory exactly as it looked then, correctly leaving out anything deleted
or renamed since. Without TIR, a restore chain has no such record and simply reintroduces every
file that was ever backed up across the whole full-plus-incremental window, including files
deleted long before the chosen restore point.

**ReaR integration:**

The `BACKUP=NBU` method for ReaR supports bare metal recovery of Linux systems protected as
NetBackup clients. Unlike some other ReaR-integrated backup products, restore is not driven from
an external console: ReaR carries the client's own NetBackup software into the rescue image and
drives the standard NetBackup client commands (`bplist`, `bpclimagelist`, `bprestore`, `bpclntcmd`,
`nbcertcmd`) itself, so a full recovery runs end to end from the rescue shell. It has been
validated against a live NetBackup 11.2.0.1 primary across three client generations: a modern
systemd/PBX client, a legacy pre-PBX xinetd client, and a second OS family on the modern
systemd/PBX path, so both the certificate-based startup path and the older xinetd fallback are
exercised against real NetBackup.

Across the whole pipeline, `BACKUP=NBU`:

* Captures the client's entire NetBackup installation (`/usr/openv`, `/etc/vx`, `/opt/VRTSpbx`,
  `/var/VRTSpbx`) into the rescue image, excluding cloud/plugin libraries, installer packages,
  and NetBackup's own security-state directories (host certificate keystore, CA trust store,
  credential cache) — those are deliberately left out and recreated fresh at restore time
  instead of carried over stale.
* Detects and starts whichever client startup mechanism the source host actually uses: systemd
  (`vxpbx_exchanged.service` and `netbackup.service`), SysV `/etc/init.d`, or the legacy
  pre-PBX xinetd fallback (`vnetd`/`bpcd`/`vopied`), since which mechanism a given client ships
  depends on OS and NetBackup client version together.
* Enrolls a fresh host certificate for the rescue system via `nbcertcmd`, fetching the primary's
  CA certificate and prompting the operator for an authorization or reissue token, since the
  original client's certificate is never part of a NetBackup backup and can't simply be carried
  onto the rescue image.
* Detects if the rescue system's live hostname differs from the client name recorded in
  `bp.conf` and updates it automatically, while giving the operator a single pause, before any
  service starts or certificate gets enrolled, to also hand-edit `bp.conf` directly — for
  example to point `SERVER=` at a different primary or media server for an AIR/IRE-style
  disaster-recovery-site restore.
* Confirms the primary is reachable and genuinely a primary server before asking any restore
  questions, and reports both the primary's and the client's NetBackup version.
* Presents an interactive, catalog-driven Point-in-Time restore picker: it queries the client's
  actual backup catalog and lists it newest-first as a numbered menu, defaulting to the most
  recent backup on a plain ENTER, falling back to strict manual date/time entry only if the
  catalog can't be queried.
* Computes the correct restore chain itself: it walks the catalog backwards from the selected
  point in time to find the nearest preceding full backup, instead of restoring from the
  beginning of time.
* Supports restoring from a different client's backup than the one currently running (a cross
  restore), for example to restore client A's data onto client B's rescue session, provided the
  source client is authorized as an altname of the destination on the primary.
* Threads True Image Restore through the whole pipeline: it is verified at backup time, used to
  filter which backups the restore-time picker offers, and passed to the actual `bprestore`
  call, so a Point-in-Time restore is correct and not merely point-in-time-labeled.
* Restores the freshly enrolled certificate, CA trust store, and credential cache onto the
  recovered disk after the data restore completes, so the client can establish an outbound SSL
  connection to the primary again after reboot without a second manual enrollment. This step is
  skipped on a cross restore, since the enrolled certificate belongs to the rescue system's own
  hostname, not the client whose data was restored.
* Refuses, by default, to run against a host whose own `CLIENT_NAME` matches a `SERVER` or
  `MEDIA_SERVER` entry in its own `bp.conf` — that is, a NetBackup primary or media server
  itself — since NetBackup services must already be running for `bprestore` to work at all. This
  is checked both at backup time and restore time.
* Requires NetBackup client 8.1 or newer, the minimum version with host-certificate support that
  this backend depends on.

## Configuration

1. Edit `/etc/rear/local.conf` and set:

   ```
   BACKUP=NBU
   ```

2. Confirm the client is already installed and registered against a NetBackup primary, running
   NetBackup client 8.1 or newer, and has at least one backup in the catalog.
3. Optionally tune the following variables in `local.conf` or `site.conf`:

   | Variable | Default | Purpose |
   |---|---|---|
   | `NBU_TRUE_IMAGE_RESTORE` | `true` | Requires True Image Restore data on backups used for restore, and passes `-T` to `bplist`/`bpclimagelist`/`bprestore`. Set to `false` only if the backup policy does not collect TIR information — restores will then union every file backed up in the window instead of reproducing the exact point in time. |
   | `NBU_ALLOW_SERVER_AS_CLIENT` | `false` | Downgrades the primary/media-server safety check from a fatal error to a warning, allowing `rear mkbackup`/`recover` to proceed against a host that is itself a NetBackup server. |
   | `NBU_LD_LIBRARY_PATH` | `/usr/openv/lib:/usr/openv/netbackup/sec/at/lib:/usr/openv/lib/boost` | Library search path needed for NetBackup's own binaries to run during `mkbackup`/`mkrescue`. Only needs changing if the client installs NetBackup libraries somewhere nonstandard. |

   There is deliberately no `NBU_SERVER` setting in `default.conf`: the primary server is read
   from the client's own `bp.conf`, which is carried onto the rescue image as-is, so it is
   always current for that client rather than baked into a rear config value.
4. Test with `rear -v mkrescue` (or `mkbackup` to also run a NetBackup backup as part of the
   same invocation).
5. Keep the resulting rescue image available for recovery, e.g. by including its storage
   location in your own backup coverage, or by copying it off the host through your usual
   process.

## Recovery

1. Boot the recovery target from the ReaR rescue image and run `rear recover`.
2. ReaR compares the client name recorded in `bp.conf` against this system's live hostname:
   * If they match, ReaR proceeds with no change.
   * If they differ, ReaR updates `CLIENT_NAME` in `bp.conf` to the current hostname
     automatically.
   Either way, before anything else happens, ReaR pauses once and gives you the chance to
   hand-edit `bp.conf` directly — for example to point `SERVER=` at a different primary or media
   server if this is a disaster-recovery-site restore. Press ENTER to continue with the current
   `bp.conf`, or type `EXIT` to abort.
3. ReaR starts the NetBackup client services using whichever startup mechanism this client uses
   (systemd, SysV, or xinetd).
4. ReaR enrolls a new host certificate:
   * It fetches the primary's CA certificate via `nbcertcmd -getCAcertificate`, which will ask
     you to confirm the certificate's fingerprint.
   * It then prompts for an authorization or reissue token. Create an authorization token from
     the NetBackup web UI or with `nbcertcmd -createtoken` on the primary before starting the
     recovery, if you haven't already. There is no timeout on this prompt, since retrieving a
     token can take a while. If a certificate already exists for this client name, NetBackup
     will report that a reissue token is required instead — generate one the same way and enter
     it when re-prompted.
5. ReaR confirms the primary is reachable and is genuinely a primary server, and reports the
   primary's and the client's NetBackup version for reference.
6. ReaR asks which client's backups to restore from, defaulting to this client. Enter a
   different client name here only for a cross restore, and only once that client has been
   authorized as an altname of this one on the primary — otherwise the restore will fail.
7. ReaR queries the catalog and presents matching backups as a numbered list, newest first.
   Enter a number to select one, enter an exact date and time as `mm/dd/yyyy HH:MM:SS`, or press
   ENTER to restore the most recent backup. If the catalog can't be queried, ReaR falls back to
   asking for a date and time directly.
8. ReaR restores the data with `bprestore`, automatically restoring the full backup chain needed
   to reach the selected point in time. Any non-zero return code is reported as a failure, but
   recovery continues so you can inspect the system. Check the restore job's log on the
   NetBackup primary and verify the restored system carefully before rebooting.
9. ReaR restores the freshly enrolled certificate, CA trust store, and credential cache onto the
   recovered disk (skipped on a cross restore), copies the `bprestore` log into the recovered
   system for later reference, then finishes the usual bootloader installation and cleanup
   steps. Reboot once `rear recover` completes.

## Known Issues

* On a cross restore, the recovered client is left without its own valid certificate, since the
  certificate enrolled during recovery belongs to the rescue system's own hostname, not the
  source client's. Re-enroll a certificate for the recovered client manually after reboot.
* True Image Restore only works for backups taken under a policy with "Collect true image
  restore information" enabled. If that wasn't enabled, either set `NBU_TRUE_IMAGE_RESTORE=false`
  before restoring, or expect the restore to bring back files that were already deleted before
  the selected restore point.
* A NetBackup primary or media server cannot be recovered through this backend under default
  settings, since its own NetBackup services would need to already be running to perform the
  restore. Restore from an AIR/IRE-replicated copy on another primary instead, or set
  `NBU_ALLOW_SERVER_AS_CLIENT=true` deliberately if you understand the implications.
* If the rescue system's hostname was renamed during recovery, the certificate gets enrolled
  under that temporary hostname. There is currently no automatic check tying the enrolled
  certificate to whatever hostname the system ends up with after the final reboot — verify
  certificate validity again post-reboot if a rename occurred.

## Troubleshooting

* Verify that ReaR can rebuild the disk layout and boot without NetBackup involved first. Most
  recovery issues are due to ReaR's own disk/bootloader configuration, not the NetBackup
  integration.
* Certificate enrollment failing: confirm the primary is reachable and that you're using the
  right kind of token — an authorization token for a first enrollment, a reissue token if a
  certificate already exists for this client name.
* `bpclntcmd -is_master_server` failing: `bp.conf`'s `SERVER=` entry is unreachable or is not
  actually a primary server. Check connectivity and `bp.conf` contents (edit them during the
  recovery pause if needed).
* Point-in-time picker shows no backups, or falls back to manual entry: check that
  `bpclimagelist` can reach the primary, and that `NBU_TRUE_IMAGE_RESTORE` isn't filtering out
  every available backup because none of them collected TIR information.
* `bprestore` reporting a non-zero return code: ReaR treats every non-zero code as a failure.
  Check the restore job's log on the NetBackup primary for details. The copied per-file log
  (`bplog.restore*` in the recovered system's home directory) only lists individual restore
  steps, not the overall job status.
* Cross restore failing with NetBackup exit status 135: the source client hasn't been authorized
  as an altname of the destination client on the primary.
