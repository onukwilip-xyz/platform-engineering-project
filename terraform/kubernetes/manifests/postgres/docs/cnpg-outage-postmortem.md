# Incident Postmortem — CNPG PostgreSQL Cluster Outage
# Platform: onukwilip.xyz (GKE, us-central1)
# Duration: ~96 hours (June 10–14, 2026)
# Severity: Critical — database unavailable, all microservices down

---

## Summary

A `kubectl cnpg restart` command triggered a rolling restart of the 3-node PostgreSQL
cluster. The switchover from pg-1 to pg-2 deadlocked because the GCS WAL archive
contained stale WAL files from a previous cluster initialization with a different
PostgreSQL system identifier. pg-2 could not complete archive recovery, could not
promote, and the cluster remained without a healthy primary for ~96 hours.

Resolution: pg-3 was promoted to primary (timeline 2) after deleting the stale GCS WAL
segments that were causing the archive recovery loop, combined with reducing the
switchover delay and using `kubectl cnpg promote` in supervised mode.

---

## Timeline

| Time (UTC) | Event |
|---|---|
| Jun 10 06:54 | Cluster initialized, pg-1 as primary, system ID `7649656642244059156` |
| Jun 10 17:16 | Cluster condition transitions to "Not Ready" (first sign of archiving issue) |
| Jun 11 12:50 | Last valid checkpoint on pg-1 before the incident |
| Jun 11 19:54 | `kubectl cnpg restart postgres-cluster` executed — rolling restart initiated |
| Jun 11 19:54 | Operator sets `kubectl.kubernetes.io/restartedAt` annotation, begins switchover pg-1 → pg-2 |
| Jun 11 19:55 | pg-2 starts archive recovery to catch up on any WAL pg-1 wrote but didn't stream |
| Jun 11 ~20:00 | pg-2 reaches WAL segment 0x0C in GCS — finds WAL from OLD cluster (system ID `7648644339469807636`) |
| Jun 11 onwards | pg-2 stuck in archive recovery loop — wrong system ID WAL restores but doesn't advance LSN |
| Jun 11 onwards | pg-1 reports "Switchover in progress" — waiting for pg-2 to confirm promotion |
| Jun 12 onwards | All 3 instances crash-looping or stuck. No primary. Endpoint empty. |
| Jun 14 08:22 | Stale WAL segments 11 and 12 deleted from GCS — archive restore loop broken |
| Jun 14 15:07 | `kubectl cnpg promote postgres-cluster-3` succeeds — pg-3 becomes primary on timeline 2 |
| Jun 14 15:07 | `postgres-cluster-rw` endpoint populated: `10.20.2.250:5432` |
| Jun 14 ~15:40 | WAL archiving fixed via `cnpg.io/skipEmptyWalArchiveCheck` annotation |
| Jun 14 ~15:45 | pg-1 rebuilt as streaming replica via `pg_basebackup` from pg-3 |
| Jun 14 ~16:00 | All 3 instances healthy, cluster fully recovered |

---

## Root Causes

### Root cause 1 — Stale WAL archive in GCS (primary cause)

The GCS path `gs://pe-cnpg-postgres-backups/postgres-cluster/postgres-cluster/` was
reused across two different CNPG cluster initializations:

| Cluster lifecycle | System ID | WAL in GCS |
|---|---|---|
| Old cluster (previous PoC iteration) | `7648644339469807636` | Segments 0x01–0x25 |
| Current cluster | `7649656642244059156` | Segments 0x01–0x0F (overlapping) |

When the current cluster ran normally, pg-1 was primary and pg-2/pg-3 received WAL
via streaming replication — they NEVER needed the GCS archive. The stale WAL coexisted
silently. The rolling restart triggered a switchover, and for the first time pg-2 tried
to fetch WAL beyond what streaming had delivered. Segments 0x10 and above in GCS were
from the old cluster. PostgreSQL logged:

```
WAL file is from different database system:
  WAL file database system identifier is 7648644339469807636,
  pg_control database system identifier is 7649656642244059156
```

PostgreSQL accepted the WAL (this warning is non-fatal), but the WAL records made no
sense for the current cluster's data. Recovery stalled at LSN `0/11000040`. The
restore_command kept returning success (files existed in GCS), so PostgreSQL's startup
process never reached the "end of archive" pause point where it would honor the promote
signal. This is a documented PostgreSQL behavior:

> "pg_ctl promote is not preemptive in archive recovery — it will block until timeout
> and not promote until restore_command exits abnormally."
> — PostgreSQL mailing list BUG #17577

### Root cause 2 — Rolling upgrade triggered by PodSpec affinity diff (contributing cause)

Immediately after the manual resource limit changes on cluster workloads (to fix
node pressure), the CNPG operator detected a diff between the running pod specs and
the cluster CR's desired spec ("original and target PodSpec differ in affinity"). This
caused the operator to continuously trigger rolling upgrade switchovers, re-setting
`targetPrimary` on every reconciliation loop — overriding every manual `kubectl cnpg
promote` attempt.

### Root cause 3 — Aggressive `wal_receiver_timeout: 5s` (amplifying cause)

The cluster was configured with `wal_receiver_timeout: 5s`. This caused every streaming
replication attempt during archive recovery to time out almost immediately, creating an
extremely tight retry loop that made the startup process harder to interrupt with a
promote signal.

---

## What We Tried (Chronological)

### ❌ Failed: `kubectl cnpg promote postgres-cluster postgres-cluster-2`

**Why it failed:** The operator had set `kubectl.kubernetes.io/restartedAt` annotation
on the cluster to drive the rolling restart. On every reconciliation loop, the operator
saw this annotation and reset `targetPrimary=postgres-cluster-2` — overriding the
promote command immediately.

---

### ❌ Failed: Removing `cnpg.io/restartedAt` annotation

**Why it failed:** The actual restart annotation in CNPG 1.29.0 is
`kubectl.kubernetes.io/restartedAt`, not `cnpg.io/restartedAt`. The old annotation
name was used in CNPG versions prior to 1.24. Removing the wrong annotation had no
effect.

**Key learning:** Always check the actual annotation on the resource with
`kubectl get cluster ... -o json | jq .metadata.annotations` before removing
annotations by assumed names.

---

### ✓ Partially successful: Removing `kubectl.kubernetes.io/restartedAt`

Removing the correct restart annotation stopped the operator from fighting the promote
command on every reconcile loop. However, promotion still failed because:
- The rolling upgrade (PodSpec diff) kept triggering new switchovers
- The archive recovery loop (stale GCS WAL) prevented pg-3's startup process from
  honoring the promote signal

---

### ❌ Failed: Manual `touch /var/lib/postgresql/data/pgdata/promote`

**Why it failed:** The CNPG instance manager (PID 1) monitors and deletes any promote
file it didn't create itself. The file was removed within ~2 seconds — before the
PostgreSQL startup process's next pause point (~5 seconds) could detect it.

---

### ❌ Failed: `kill -SIGUSR1 <pid>` via shell

**Why it failed:** The CNPG container's shell (`sh`) doesn't support the `-S` flag for
named signals. `kill -SIGUSR1 23` was rejected with `Illegal option -S`. The correct
approach is either `pg_ctl promote` (which uses the C `kill()` syscall internally) or
`kill -10 <pid>` (using the numeric signal number for SIGUSR1).

---

### ❌ Failed: `pg_ctl promote` direct exec

**Why it failed:** Two separate failure modes at different stages:

1. First attempt returned "server is not in standby mode" — because `kill -TERM 23`
   had accidentally been sent previously (testing signal syntax), which terminated
   the PostgreSQL postmaster. The instance manager restarted PostgreSQL as a primary
   briefly, but the recovery.signal was then recreated.

2. Later attempts to `pg_ctl promote` while pg-3 was in the archive recovery loop
   timed out with `pg_ctl: server did not promote in time` — because the startup
   process was blocked waiting for the archive restore_command to fail, exactly as
   described in PostgreSQL BUG #17577.

---

### ❌ Failed: Fencing pg-1 and pg-2 without deleting stale GCS WAL

Fencing stopped pg-1 and pg-2 from interfering, but the underlying archive recovery
loop on pg-3 continued. Promotion still couldn't fire.

---

### ❌ Failed: Removing `spec.backup.barmanObjectStore` without restarting pg-3's pod

Patching the cluster CR to remove `barmanObjectStore` changes PostgreSQL's
`postgresql.conf` (clearing `restore_command`), but CNPG does this via a SIGHUP reload
rather than a pod restart. `restore_command` is NOT a reload-able parameter in
PostgreSQL — it only takes effect after a restart. The running pg-3 continued using the
old restore_command.

**Fix required:** After removing `barmanObjectStore`, the pod must be explicitly deleted
to force a restart with the new config.

---

### ✓ Successful: Full resolution sequence

The following steps, in this specific order, resolved the incident:

**Step 1 — Stop automatic rolling upgrades:**
```bash
kubectl patch cluster postgres-cluster -n postgres \
  --type=merge -p '{"spec":{"primaryUpdateStrategy":"supervised"}}'
```
Prevents the operator from triggering new switchovers autonomously.

**Step 2 — Remove the stuck restart annotation:**
```bash
kubectl annotate cluster postgres-cluster -n postgres \
  "kubectl.kubernetes.io/restartedAt-" --overwrite
```
Stops the operator from overriding every promote command.

**Step 3 — Reduce switchover delay:**
```bash
kubectl patch cluster postgres-cluster -n postgres \
  --type=merge -p '{"spec":{"switchoverDelay":30}}'
```
Prevents the 1-hour switchoverDelay from blocking promotion after pg-1 was deleted.

**Step 4 — Delete stale WAL segments from GCS (the core fix):**
```bash
BASE="gs://pe-cnpg-postgres-backups/postgres-cluster/postgres-cluster/wals/0000000100000000"
gcloud storage rm "${BASE}/000000010000000000000010.gz"
gcloud storage rm "${BASE}/000000010000000000000011.gz"
gcloud storage rm "${BASE}/000000010000000000000012.gz"
# Segments 13-25 were already absent
```
Once segment 11 (the blocker) was deleted, `restore_command` returned "not found"
(exit non-zero). PostgreSQL's startup process reached the end-of-archive pause point.

**Step 5 — Unfence all instances:**
```bash
kubectl annotate cluster postgres-cluster -n postgres \
  'cnpg.io/fencedInstances=[]' --overwrite
```

**Step 6 — Promote pg-3 (CNPG-controlled, not manual):**
```bash
kubectl cnpg promote postgres-cluster postgres-cluster-3 -n postgres
```
With the stale WAL gone, the archive restore_command failed cleanly for segment 11.
pg-3's startup process reached end-of-archive, the instance manager called
`pg_ctl promote -w -t 40000000`, and pg-3 became primary on timeline 2 within 6
seconds.

**Step 7 — Delete pg-1 pod to complete failover:**
```bash
kubectl delete pod postgres-cluster-1 -n postgres
```
pg-1's instance manager was still in "waiting for switchover to finish" mode. Deleting
the pod forced the operator to treat it as failed and allowed promotion to complete.

**Step 8 — Fix WAL archiving:**
```bash
kubectl annotate cluster postgres-cluster -n postgres \
  cnpg.io/skipEmptyWalArchiveCheck=enabled --overwrite
```
CNPG's `barman-cloud-check-wal-archive` refused to archive because the GCS path
was "not empty" (it contained timeline 1 WAL). The annotation bypasses this safety
check — safe here because the existing WAL belongs to the same system ID and timeline
2 WAL files have different names.

**Step 9 — Restore settings and rebuild replicas:**
```bash
kubectl patch cluster postgres-cluster -n postgres --type=merge -p '{
  "spec": {"switchoverDelay":3600,"minSyncReplicas":1,"primaryUpdateStrategy":"unsupervised"}
}'
kubectl cnpg destroy postgres-cluster 2 -n postgres
```
pg-1 was rebuilt automatically via pg_basebackup. pg-2 was destroyed and rebuilt
cleanly. All 3 instances reached healthy streaming replication status.

---

## Contributing Factors Discovered During Investigation

**CNPG instance manager version behavior change (CNPG 1.24+):**
In CNPG 1.24+, the restart annotation changed from `cnpg.io/restartedAt` to
`kubectl.kubernetes.io/restartedAt`. Documentation doesn't prominently highlight this.
Always verify annotation names against the running operator version, not assumed names.

**CNPG instance manager deletes external promote files:**
The instance manager owns the promotion lifecycle. Any promote file written externally
is treated as a race condition and deleted. Manual promotion must go through CNPG's
own `kubectl cnpg promote` command, not by writing files directly.

**`restore_command` is not SIGHUP-reloadable:**
Changing `barmanObjectStore` in the cluster CR causes a SIGHUP to PostgreSQL, but
`restore_command` is a startup-time parameter. The pod must be restarted for the
change to take effect.

**`barman-cloud-check-wal-archive` "Expected empty archive" blocks archiving:**
After a cluster promotion to a new timeline, if any WAL exists in the archive path,
CNPG's pre-archive safety check fails. This is correct behavior for fresh installs but
causes false positives when the archive contains WAL from the same cluster on a
previous timeline. The `cnpg.io/skipEmptyWalArchiveCheck=enabled` annotation bypasses
it safely in this scenario.

---

## Prevention Measures

### 1. Never reuse a GCS archive path across cluster reinitializations

When destroying and recreating a CNPG cluster at the same GCS destination path:

```bash
# Clear the WAL archive before recreating the cluster
gcloud storage rm -r gs://pe-cnpg-postgres-backups/postgres-cluster/postgres-cluster/wals/
gcloud storage rm -r gs://pe-cnpg-postgres-backups/postgres-cluster/postgres-cluster/basebackups/
```

Or use a versioned path in the cluster spec:
```yaml
destinationPath: gs://pe-cnpg-postgres-backups/postgres-cluster-v2
```

### 2. Set `primaryUpdateStrategy: supervised` in staging environments

```yaml
spec:
  primaryUpdateStrategy: supervised
```

With `supervised`, the operator never triggers automatic switchovers for rolling
upgrades. Upgrades require an explicit `kubectl cnpg promote` command. This prevents
the silent rolling upgrades that compounded this incident.

### 3. Fix PodSpec diffs in Terraform before ArgoCD auto-sync

After any manual resource changes (LimitRanges, affinity, tolerations), update the
Terraform/Helm values to match before re-enabling ArgoCD sync:

```hcl
# In your CNPG cluster Helm values / Terraform
affinity = {
  enablePodAntiAffinity = true
  podAntiAffinityType   = "required"   # explicit — prevent diff
  topologyKey           = "kubernetes.io/hostname"
}
```

The "original and target PodSpec differ in affinity" condition is what triggered the
rolling upgrade that compounded the outage.

### 4. Increase `wal_receiver_timeout`

The default value of 5 seconds is extremely aggressive. Increase to 30 seconds to give
streaming replication connections more time to establish before falling back to archive:

```yaml
spec:
  postgresql:
    parameters:
      wal_receiver_timeout: "30s"
      wal_sender_timeout: "30s"
```

### 5. Maintain a valid base backup at all times

The incident was complicated by the absence of a valid base backup (`First Point of
Recoverability: Not Available`). Schedule regular ScheduledBackups:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: postgres-cluster-daily
  namespace: postgres
spec:
  schedule: "0 2 * * *"    # 02:00 UTC daily
  backupOwnerReference: self
  cluster:
    name: postgres-cluster
  method: barmanObjectStore
```

With a valid base backup, a full cluster rebuild from GCS is always possible as a
last resort, without depending on potentially stale WAL files.

### 6. Add LimitRanges only to application namespaces

LimitRanges with aggressive defaults (`cpu: 120m, memory: 150Mi`) applied to
infrastructure namespaces (istio-system, monitoring, postgres, argocd) caused a
cascade of ztunnel OOMKills that triggered the node drain which triggered the resource
limit changes which triggered the PodSpec diff which triggered the rolling upgrade.

Safe namespaces for LimitRanges: `users`, `store-ui`, and other application namespaces.
Unsafe: `istio-system`, `kube-system`, `monitoring`, `postgres`, `argocd`.

### 7. Use `kubectl cnpg restart` only after confirming archive health

Before running `kubectl cnpg restart`, verify:
```bash
# 1. WAL archiving is working
kubectl cnpg status postgres-cluster -n postgres | grep "WAL archiving"
# Must show: Working WAL archiving: OK

# 2. A valid base backup exists
kubectl cnpg status postgres-cluster -n postgres | grep "First Point"
# Must show a date, not "Not Available"

# 3. Archive contains only WAL from THIS cluster
# Check system ID matches:
kubectl exec postgres-cluster-1 -n postgres -- \
  psql -U postgres -c "SELECT system_identifier FROM pg_control_system();"
# Compare with WAL in GCS — system IDs must match
```

---

## Key Commands Reference for Future Incidents

```bash
# Check cluster status comprehensively
kubectl cnpg status postgres-cluster -n postgres

# Check which annotation is driving a restart
kubectl get cluster postgres-cluster -n postgres \
  -o jsonpath='{.metadata.annotations}' | jq

# Remove the restart annotation (CNPG 1.24+)
kubectl annotate cluster postgres-cluster -n postgres \
  "kubectl.kubernetes.io/restartedAt-" --overwrite

# Stop automatic rolling upgrades immediately
kubectl patch cluster postgres-cluster -n postgres \
  --type=merge -p '{"spec":{"primaryUpdateStrategy":"supervised"}}'

# Promote a specific instance
kubectl cnpg promote postgres-cluster <instance-name> -n postgres

# Fence instances (stops PostgreSQL, keeps pods running)
kubectl annotate cluster postgres-cluster -n postgres \
  'cnpg.io/fencedInstances=["instance-1","instance-2"]' --overwrite

# Unfence
kubectl annotate cluster postgres-cluster -n postgres \
  'cnpg.io/fencedInstances=[]' --overwrite

# Destroy and rebuild a specific instance (preserves PVC by default)
kubectl cnpg destroy postgres-cluster <instance-number> -n postgres

# Skip WAL archive safety check after promotion
kubectl annotate cluster postgres-cluster -n postgres \
  cnpg.io/skipEmptyWalArchiveCheck=enabled --overwrite

# List WAL files in GCS archive
gcloud storage ls \
  "gs://pe-cnpg-postgres-backups/postgres-cluster/postgres-cluster/wals/0000000100000000/"

# Delete a specific WAL segment from GCS
gcloud storage rm \
  "gs://pe-cnpg-postgres-backups/postgres-cluster/postgres-cluster/wals/0000000100000000/000000010000000000000011.gz"
```

---

## References

- [CNPG Labels and Annotations — restartedAt (v1.24+)](https://cloudnative-pg.io/documentation/1.24/labels_annotations/)
- [CNPG Fencing documentation](https://cloudnative-pg.io/documentation/1.29/fencing/)
- [CNPG Recovery — skipEmptyWalArchiveCheck](https://cloudnative-pg.io/documentation/1.20/recovery/)
- [CNPG cnpg destroy command](https://cloudnative-pg.io/documentation/1.29/cnpg-plugin/#destroy)
- [PostgreSQL BUG #17577 — pg_ctl promote not preemptive in archive recovery](https://www.postgresql.org/message-id/CAKFQuwaK1urL_7QfVNwY%3DDEcUqHAx9_JdMeeR1%3DdGRy7KQBjtA%40mail.gmail.com)
- [CNPG issue #10419 — replica stuck in wal-restore loop after failover](https://github.com/cloudnative-pg/cloudnative-pg/issues/10419)
- [Barman Cloud WAL archive path format](https://docs.pgbarman.org/release/3.11.0/barman-cloud-wal-archive.1.html)
