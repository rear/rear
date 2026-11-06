
# Documentation for the Cohesity DataProtect (COH) Backup and Restore Method

## Summary

Cohesity DataProtect provides policy-based backup and recovery for supported workloads. A
protection policy defines the source, schedule, retention, and storage target. Backup data is
transferred to a Cohesity cluster and stored as snapshots.

**Backup processing:**

* The client or workload is registered as a protection source.
* A protection job runs according to its assigned policy.
* Data is read directly from the workload or through a locally installed agent.
* The backup stream is sent to the DataProtect cluster.
* The cluster deduplicates and compresses the backup data.
* Encryption protects data in transit and at rest.
* Snapshots can be configured as immutable, preventing modification or deletion during the
  defined retention period and improving cyber resilience.
* Recovery operations read the required snapshot and restore the selected files, volumes, or
  workload data.

**ReaR integration:**

For the ReaR workflow, the lightweight Cohesity agent is installed locally on the Linux client
and performs either a file system based or block based backup. The agent can perform
source-side deduplication to reduce network transfer. Backup data is stored on the DataProtect
cluster in deduplicated, compressed, encrypted, on immutable snapshots.

The `BACKUP=COH` method for ReaR supports bare metal recovery of Linux systems that are
protected as physical servers by Cohesity DataProtect. It has been validated against a live
Cohesity cluster, recovering successfully both when the recovery host keeps the original
hostname and when it comes up with a different hostname.

The Cohesity agent that runs on a protected physical server has no local command to list or
restore backups: the agent only accepts connections from the Cohesity cluster, it does not pull
data on its own. Because of this, `BACKUP=COH` works as follows:

* `rear mkrescue` copies the installed Cohesity agent (binaries, configuration, and runtime
  state under `/opt/cohesity`, `/etc/cohesity-agent`, and `/var/cohesity`) into the ReaR rescue
  image, together with the `cohesity-agent` systemd service unit (if used) and the commands the
  agent's `command_path.sh` looks up at startup, so the agent can be started again during
  recovery.
* `rear recover` rebuilds the disk layout as usual, then checks whether this recovery host's
  hostname still matches what is recorded in the copied
  `/etc/cohesity-agent/agent.cfg`:
  * If they **differ** (e.g. a different host), the Cohesity
    agent identity is reset automatically: `agent.cfg`, `server_cert`, and the telemetry
    `hostuuid` are renamed with a `_rear` suffix (not deleted, so nothing is lost) so the agent
    starts up unregistered. This is mandatory and requires no confirmation - the stale identity
    cannot be reused for this session.
  * If they **match**, ReaR offers the same reset as an *optional* step, in case the original
    client-server registration on the Cohesity cluster side is lost or invalid.
  * Either way, the original server's own agent registration/identity is never destroyed by this
    step: the rescue image only holds a snapshot of it, and resetting that snapshot does not
    affect the real registration.
* `rear recover` then starts the Cohesity agent inside the rescue environment so the Cohesity
  cluster can reach it.
* The actual data restore is **initiated and monitored by the administrator from the Cohesity
  Data Cloud console and/or its REST API**, targeting the recovery host's mounted target
  filesystem. `rear recover` pauses and waits for the administrator to confirm the restore has
  completed before it continues with bootloader installation and final cleanup.

## Configuration

1. Edit `/etc/rear/local.conf` and set:

   ```
   BACKUP=COH
   ```

2. Install and register the Cohesity agent on the physical server as directed by Cohesity's
   documentation, and confirm the server is protected by a Cohesity Protection Group. Either
   File Level or Block Based Backup can be used to protect the server.
3. Optionally tune the following variables in `local.conf` or `site.conf`:

   | Variable | Default | Purpose |
   |---|---|---|
   | `COPY_AS_IS_COH` | `/etc/cohesity-agent /opt/cohesity /var/cohesity` | Agent installation, config and state copied into the rescue image. |
   | `COPY_AS_IS_EXCLUDE_COH` | `/opt/cohesity/agent/data/agent/tmp/* /opt/cohesity/agent/data/logs/*` | Agent temp files and logs left out of the rescue image. |
   | `REQUIRED_PROGS_COH` | `linux_agent_exec host kill losetup lsof nproc wget whereis whoami` | Programs the agent needs at runtime in the rescue system. |
   | `COH_LD_LIBRARY_PATH` | `/opt/cohesity/agent/software/crux/bin/dlls_for_linking` | Library search path for the agent's bundled libraries during `mkrescue`. Only needs changing if the agent is installed somewhere nonstandard. |
4. Test ReaR by running `rear -v mkrescue`.
5. Keep the resulting rescue image (ISO or other `OUTPUT_URL`) available for recovery, e.g. by
   also protecting the host filesystem containing `/var/lib/rear/output/` with Cohesity
   DataProtect, or by copying the rescue image off the host through your usual process.

## Recovery

1. Boot the recovery target from the ReaR rescue image.
2. Run `rear recover`.
3. ReaR compares the hostname recorded in `agent.cfg` against this host's current hostname and
   logs what it detected:
   * **Same hostname as the original system:** the existing agent identity is kept unless you
     confirm the optional prompt to reset it anyway.
   * **Different hostname:** the agent identity is reset automatically (no prompt) - `rear
     recover` logs that this is required and proceeds.
4. Once ReaR reports the Cohesity agent has started:
   * If the identity was **kept**, go to the Cohesity Data Cloud console (or use its REST API)
     and initiate a physical server recovery of this (still-registered) host, restoring into the
     path ReaR reports as `$TARGET_FS_ROOT`.
   * If the identity was **reset**, this rescue session comes up as a fresh, temporary Cohesity
     agent. Register it with the Cohesity cluster - if you are recovering from a replica, it must
     be registered against the replica's target cluster, not the original one - then run a
     **Physical Server File & Folder recovery** job to restore the data into `$TARGET_FS_ROOT`.
     No re-registration of the original server is needed - its own identity was never touched.
   * In the File & Folder recovery job, make sure to select **all** critical mount points, not
     just `/`. If any of the source filesystems were excluded from indexing, disable the
     **"Browse on Indexed Data"** option in the file/folder selection, otherwise those
     filesystems' contents won't be browsable/selectable for restore.
5. Monitor the restore to completion in the Cohesity Data Cloud console and/or via the REST API.
6. Back in the ReaR recovery shell, type `exit` to let `rear recover` continue.
7. If the identity was **reset** and the hostname in the restored `agent.cfg` matches the current
   hostname, ReaR copies the new agent identity (`agent.cfg`, `server_cert`, `hostuuid`) to the
   restored system, replacing the restored copies, so no further registration is needed after
   the first boot. If the hostnames differ, nothing is copied and the agent needs to be
   registered again after reboot.
8. Let `rear recover` finish (bootloader installation, cleanup), then reboot.

## Known Issues

* If a filesystem's contents are missing from the File & Folder recovery browser, check whether
  it was excluded from indexing and disable "Browse on Indexed Data" as described above.
* When recovering from a replica cluster, the temporary agent must be registered against the
  replica's target cluster. Especially when the replica cluster has not been registered with
  the agent prior to the backup.

## Troubleshooting

* Verify that ReaR can rebuild the disk layout and boot without Cohesity DataProtect involved
  first. Most recovery issues are due to ReaR's own disk/bootloader configuration, not the
  Cohesity integration.
* Check the Cohesity agent logs under `/var/log/cohesity/` inside the rescue environment if the
  agent fails to start or the cluster cannot reach it.
* If the agent identity was reset, the original files are still present as `agent.cfg_rear`,
  `server_cert_rear`, and `hostuuid_rear` under `/etc/cohesity-agent/` and
  `/var/cohesity/telemetry/` inside the rescue environment, in case you need to inspect what was
  originally recorded.
