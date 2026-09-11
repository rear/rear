
# Documentation for the Cohesity DataProtect (COH) Backup and Restore Method

**Status: draft / not yet validated against a real recovery test.**

## Summary

The `BACKUP=COH` method for ReaR supports bare metal recovery of Linux systems that are
protected as physical servers by Cohesity DataProtect.

The Cohesity agent that runs on a protected physical server has no local command to list or
restore backups: the agent only accepts connections from the Cohesity cluster, it does not pull
data on its own. Because of this, `BACKUP=COH` works as follows:

* `rear mkrescue` copies the installed Cohesity agent (binaries, configuration, and runtime
  state) into the ReaR rescue image so that it can be started again during recovery.
* `rear recover` rebuilds the disk layout as usual, then starts the Cohesity agent inside the
  rescue environment so the Cohesity cluster can reach it again.
* The actual data restore is **initiated and monitored by the administrator from the Cohesity
  Data Cloud console and/or its REST API**, targeting the recovery host's mounted target
  filesystem. `rear recover` pauses and waits for the administrator to confirm the restore has
  completed before it continues with bootloader installation and final cleanup.

## Configuration

1. Install and register the Cohesity agent on the physical server as directed by Cohesity's
   documentation, and confirm the server is protected by a Cohesity Protection Group.
2. Edit `/etc/rear/local.conf` and set:

   ```
   BACKUP=COH
   ```

3. Test ReaR by running `rear -v mkrescue`.
4. Keep the resulting rescue image (ISO or other `OUTPUT_URL`) available for recovery, e.g. by
   also protecting the host filesystem containing `/var/lib/rear/output/` with Cohesity
   DataProtect, or by copying the rescue image off the host through your usual process.

## Recovery

1. Boot the recovery target from the ReaR rescue image.
2. Run `rear recover`.
3. Answer the inline questions, including whether the recovery host has the same IP address as
   the original system (needed because the Cohesity agent's configuration file records the
   original IP address, hostname, and registered cluster).
4. Once ReaR reports the Cohesity agent has started, go to the Cohesity Data Cloud console (or
   use its REST API) and initiate a physical server recovery of this host, restoring into the
   path ReaR reports as `$TARGET_FS_ROOT`.
5. Monitor the restore to completion in the Cohesity Data Cloud console and/or via the REST API.
6. Back in the ReaR recovery shell, type `exit` to let `rear recover` continue.
7. Let `rear recover` finish (bootloader installation, cleanup), then reboot.

## Known Issues

* If the recovery host's IP address differs from the original, the Cohesity agent will likely
  need to be re-registered with the Cohesity cluster before a restore can succeed. This is
  currently only surfaced as a warning by ReaR; re-registration itself is a manual step.
* This method has not yet been exercised end-to-end against a live Cohesity cluster; treat it as
  a starting point rather than a validated recovery procedure.

## Troubleshooting

* Verify that ReaR can rebuild the disk layout and boot without Cohesity DataProtect involved
  first. Most recovery issues are due to ReaR's own disk/bootloader configuration, not the
  Cohesity integration.
* Check the Cohesity agent logs under `/var/log/cohesity/` inside the rescue environment if the
  agent fails to start or the cluster cannot reach it.
