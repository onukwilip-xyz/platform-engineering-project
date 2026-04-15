# DEPLOYMENT GUIDES
- Don't use Istio sidecars - Envoy proxy
- Use Cert manager to Sign and Issue Certificates
- The Certificates should be short-lived and auto rotated
- Enable Zonal topology spread to deploy the replicas across VMs in various zones in the region
- Set up a 3 replica DB cluster with Vertical Autoscaling
- Configure daily (incremental) and weekly (full) backups to Cloud Storage

---
# POSTGRESQL ARCHITECTURE

## Stack
- **CloudNativePG (CNPG) Operator** — Postgres cluster lifecycle
- **PgBouncer** (via CNPG `Pooler` CRD, v1.21+) — connection pooling
- **VPA** (GKE-native) — vertical autoscaling for Cluster pods
- **HPA** — horizontal autoscaling for Pooler pods
- **Barman Cloud** (CNPG-integrated) — backups to GCS
- **GCS bucket** — backup target, Object Versioning enabled
- **Workload Identity Federation** — GCP auth for backups
- **pg_stat_statements** — query-level monitoring
- **Prometheus exporter** (CNPG built-in) — metrics

## Topology
- 1 CNPG Cluster, 3 instances, spread across 3 zones
- 1 primary + 2 synchronous standbys
- `minSyncReplicas: 1, maxSyncReplicas: 1`
- Separate PVCs for PGDATA and WAL
- No Istio sidecar injection on DB/Pooler namespaces

## Traffic paths
- **Transaction workloads** → CNPG Pooler (PgBouncer, transaction mode) → `<cluster>-rw` Service → Primary
- **Session workloads / batch jobs** → direct to `<cluster>-rw` Service (bypass pooler)

## Autoscaling
- **VPA** on Cluster pods (`Auto` mode), safe via CNPG-managed PDBs + rolling switchover
- **HPA** on Pooler pods (CPU-based, target 60%), min 3 / max 6, zone-spread

## Resilience controls
- CNPG-managed PDBs (primary + replicas)
- Pod anti-affinity (one instance per node)
- Topology spread constraints (one instance per zone)
- `primaryUpdateMethod: switchover` for graceful primary changes
- `switchoverDelay` tuned for in-flight query drain

## Multi-tenant isolation (per service) [Implement later]
- One logical database per microservice
- One Postgres role per service, scoped privileges
- Per-role `statement_timeout`, `idle_in_transaction_session_timeout`, `CONNECTION LIMIT`, `work_mem`
- Per-service connection pool

## Backups
- Continuous WAL archiving → GCS (PITR)
- Daily base backup → GCS
- Weekly full base backup → GCS
- 30-day minimum retention, GCS lifecycle policy for older

## Deployment
- GitOps via ArgoCD Applications + Terraform for installing the Helm charts
- Terraform for GCS bucket, IAM bindings, WIF
- Helm for CNPG operator install
- Kubernetes manifests for Cluster, Pooler, ScheduledBackup, VPA, HPA, PDB, Database/Role init

## TLS & mTLS Requirements

## Certificates to provision

All certs issued via cert-manager `Certificate` CRs pointing at your internal `ClusterIssuer` (org root CA).

### CNPG Cluster
- **Server cert + key** — Postgres identity to clients and replicas
  - DNS names: `<cluster>-rw`, `<cluster>-ro`, `<cluster>-r` services + namespace FQDNs
  - Consumed via `.spec.certificates.serverTLSSecret`
- **Server CA cert** — trust anchor for validating client certs (mTLS)
  - Consumed via `.spec.certificates.serverCASecret`
- **Client CA cert** — trust anchor for validating replication client cert
  - Consumed via `.spec.certificates.clientCASecret`
- **Replication client cert + key** — `streaming_replica` user identity for inter-node replication
  - CN: `streaming_replica`
  - Consumed via `.spec.certificates.replicationTLSSecret`

### PgBouncer (CNPG Pooler)
- **Server cert + key** — PgBouncer identity to application clients
  - DNS names: Pooler Service FQDNs
  - Inherits cluster CA automatically when referenced in Pooler spec
- **Client cert + key** — PgBouncer's identity when connecting to Postgres (only if mTLS is enforced Postgres-side; otherwise PgBouncer uses password auth)

### Application clients (FastAPI, future services)
- **Client cert + key per service** — service identity to PgBouncer
  - CN: matches Postgres role name (for cert-based `pg_hba.conf` mapping)
  - Signed by Client CA

## Certificate lifecycle

| Cert | Duration | renewBefore | rotationPolicy |
|---|---|---|---|
| Server certs (CNPG, PgBouncer) | 90d | 10d | Always |
| Replication cert | 90d | 10d | Always |
| Client certs (apps) | 7d | 2d | Always |

Root CA stays long-lived (managed at ClusterIssuer level).

## Rotation behavior

- **CNPG server/replication certs**: CNPG 1.21+ detects Secret changes and performs rolling restart (standbys first, primary last via graceful switchover). No manual action.
- **PgBouncer server cert**: CNPG Pooler rolling restart on Secret change, absorbed by multi-instance topology + PDB.
- **Application client certs**: Reloader watches client cert Secrets, triggers app Deployment rolling restart on change.

## Trust distribution to clients

Apps mount `ca.crt` from their own client cert Secret (cert-manager populates all three keys). Pass `sslrootcert=/certs/ca.crt` in connection URI.

## PgBouncer TLS configuration

- `server_tls_sslmode = verify-full` (validates Postgres server cert)
- `server_tls_ca_file` points to CA cert
- `client_tls_sslmode = require` (or `verify-full` for mTLS from apps)
- `client_tls_ca_file` points to CA cert (if validating app client certs)

## Application connection string

```
postgresql://<user>@<pooler-service>:5432/<db>?
  sslmode=verify-full&
  sslcert=/certs/tls.crt&
  sslkey=/certs/tls.key&
  sslrootcert=/certs/ca.crt
```

## Operational tooling

- **cert-manager**: issues and rotates all certs
- **Reloader**: restarts app Deployments on client cert Secret changes
- **Prometheus alert**: `certmanager_certificate_expiration_timestamp_seconds` < 14 days, as automation-failure backstop [Implement later]

Here're some docs to help

Its architecture and usage
https://cloudnative-pg.io/blog/developing-webapps-with-cloudnative-pg/
https://cloudnative-pg.io/docs/1.29/architecture

Its installation
https://github.com/cloudnative-pg/charts/blob/main/README.md
https://github.com/cloudnative-pg/charts/blob/main/charts/cluster/README.md

---
# MONGODB ARCHITECTURE

## Stack
- **Percona Operator for MongoDB (PSMDB Operator)** — replica set lifecycle
- **Percona Server for MongoDB (PSMDB)** — wire-compatible MongoDB drop-in
- **Percona Backup for MongoDB (PBM)** — operator-integrated backups to GCS
- **VPA** (GKE-native) — vertical autoscaling for replica set pods
- **GCS bucket** — backup target, Object Versioning enabled
- **Workload Identity Federation** — GCP auth for backups
- **Prometheus** via PSMDB exporter (bundled with operator)
- No connection pooler — Node.js driver handles client-side pooling

## Topology
- 1 PerconaServerMongoDB cluster, 3-member replica set, zone-spread
- 1 primary + 2 secondaries (auto-elected via replica set protocol)
- Separate PVCs per member
- No Istio sidecar injection on DB namespace
- Optional: mongos/config server for future sharded workloads (not needed initially)

## Traffic path
- Node.js Product Catalog service → MongoDB Service (all 3 members in connection string) → replica set
- Client-side driver handles connection pooling, primary discovery, and read preference routing
- Writes → primary; reads → per `readPreference` setting (default `primary`)

## Autoscaling
- **VPA** on replica set pods (`Auto` mode)
- Operator-managed PDB ensures eviction ordering (secondaries first, then primary via stepdown)
- No HPA — MongoDB replica sets are fixed-size; horizontal scaling = adding shards

## Resilience controls
- Operator-managed PDB (`maxUnavailable: 1`)
- Pod anti-affinity (one member per node)
- Topology spread constraints (one member per zone)
- Write concern `majority` for durability guarantees
- `readConcern: majority` for consistency across failovers
- Primary stepdown during rolling updates (graceful, ~3–12s failover window)

## Multi-tenant isolation (per service)
- One logical database per microservice (`catalogdb`, etc.)
- One MongoDB user per service, `readWrite` role scoped to own database only
- Role-based access via operator's `users` CRD field
- Per-service connection limits (driver-side `maxPoolSize`)

## Backups
- Continuous oplog archiving → GCS (PITR)
- Daily base backup → GCS
- Weekly full base backup → GCS
- 30-day minimum retention, GCS lifecycle policy for older
- Declarative via PBM `backup.tasks` in the PSMDB CR
- Authentication via Workload Identity Federation → GCP SA with `roles/storage.objectAdmin`

## Deployment
- GitOps via ArgoCD
- Terraform for GCS bucket, IAM bindings, WIF
- Helm for Percona Operator install
- Kubernetes manifests for PerconaServerMongoDB CR (includes backup config, users, topology spread, resources), VPA, PDB (operator-managed)

Here's the docs on ots Architecture
https://docs.percona.com/percona-operator-for-mongodb/architecture.html

Here's the docs on its installation on GKE
https://docs.percona.com/percona-operator-for-mongodb/gke.html

Here's that on its K8s installation
https://docs.percona.com/percona-operator-for-mongodb/kubernetes.html

Here's its Helm chart installation docs
https://docs.percona.com/percona-operator-for-mongodb/helm.html
https://artifacthub.io/packages/helm/percona/psmdb-operator

---
# REDIS ARCHITECTURE

## Stack
- **OT-CONTAINER-KIT Redis Operator** — Redis lifecycle management
- **Redis** (via operator's container images) — data plane
- **VPA** (GKE-native) — vertical autoscaling for Replication pods
- **GCS bucket** — RDB snapshot backup target
- **Workload Identity Federation** — GCP auth for backups
- **Prometheus** via operator's built-in metrics annotations
- No connection pooler — Spring Boot Lettuce client handles Sentinel-aware pooling natively

## Topology
- 1 `RedisReplication` CR — 3 pods (1 primary + 2 replicas), zone-spread
- 1 `RedisSentinel` CR — 3 Sentinel pods, zone-spread, monitoring the RedisReplication
- Operator-created headless Service for Sentinel (single DNS name, resolves to all 3 pod IPs)
- Operator-created services for Replication (`-master`, `-replica`)
- Separate PVCs per Replication pod
- *No Istio sidecar injection* on Redis namespace

## Traffic path
- Spring Boot cart service → Sentinel headless Service (`redis-sentinel.shared-services.svc.cluster.local:26379`) → Lettuce queries Sentinel → Lettuce connects directly to current primary for writes, replicas for reads (per `readPreference`)
- On failover: Sentinel promotes a replica → Lettuce re-discovers new primary within seconds

## Application configuration changes [Implement later]
- ConfigMap updated:
  - Add `SPRING_REDIS_SENTINEL_MASTER` (matches operator's master name, default `mymaster`)
  - Add `SPRING_REDIS_SENTINEL_NODES=redis-sentinel.shared-services.svc.cluster.local:26379`
  - Remove `SPRING_REDIS_HOST` and `SPRING_REDIS_PORT`
- Deployment env block updated to reference new ConfigMap keys
- No Java code changes — `CartConfig.java` is factory-agnostic

## Autoscaling
- **VPA** on RedisReplication pods (`Auto` mode)
- Operator-managed PDB ensures eviction ordering (replicas first, primary last)
- VPA `minReplicas: 2` to keep quorum during eviction
- No HPA — Replication is fixed-size; Sentinel is fixed-size

## RedisReplication CR — key configurations
- `clusterSize: 3`
- `topologySpreadConstraints` across `topology.kubernetes.io/zone`, `maxSkew: 1`
- Pod anti-affinity on `kubernetes.io/hostname`
- Persistence enabled (PVCs for RDB/AOF)
- Resource requests/limits (initial; VPA adjusts)
- Auth password via Secret reference
- TLS enabled (existing cert-manager integration)
- No Istio sidecar annotation

## RedisSentinel CR — key configurations
- `clusterSize: 3`
- `redisSentinelConfig.redisReplicationName: <RedisReplication CR name>`
- `redisSentinelConfig.masterGroupName: mymaster`
- `redisSentinelConfig.quorum: "2"` (majority of 3)
- Sentinel config overrides:
  - `down-after-milliseconds: 5000` (faster failover detection)
  - `failover-timeout: 10000`
  - `parallel-syncs: 1`
- `topologySpreadConstraints` across zones
- Pod anti-affinity on `kubernetes.io/hostname`
- Auth password reference (same as Replication)
- No Istio sidecar annotation

## Resilience controls
- Operator-managed PDBs on both Replication and Sentinel StatefulSets
- Pod anti-affinity (one member per node)
- Topology spread constraints (one member per zone)
- Sentinel quorum prevents split-brain decisions
- `min-replicas-to-write: 1` reduces data loss risk during failover [Implement later]
- AOF + periodic RDB snapshots for durability
- Lettuce client-side reconnection on failover

## Multi-tenant isolation (per service)
- One Redis logical database per microservice (Redis databases 0–15)
- Per-service ACL users (Redis 6+) with command and key-pattern restrictions
- Per-service connection limits via Lettuce client config (`maxPoolSize`)

## Deployment
- GitOps via ArgoCD
- Terraform for GCS bucket, IAM bindings, WIF
- Helm for OT-CONTAINER-KIT operator install (`ot-helm/redis-operator`)
- Kubernetes manifests for RedisReplication CR, RedisSentinel CR, VPA, backup config, ConfigMap updates

Here's the Operator Helm chart
https://redis-operator.opstree.dev/docs/installation/installation/

Here's its architecture for Redis Replication and Sentinel
https://redis-operator.opstree.dev/docs/getting-started/replication/

---
# ELASTICSEARCH ARCHITECTURE

## Stack
- **ECK (Elastic Cloud on Kubernetes) Operator** — Elasticsearch lifecycle management (Basic tier, free)
- **Elasticsearch** — data engine
- **cert-manager** (existing) — TLS cert issuance for transport and HTTP layers
- **VPA** (GKE-native) — vertical autoscaling for Elasticsearch pods
- **GCS bucket** — snapshot target, Object Versioning enabled
- **Workload Identity Federation** — GCP auth for snapshots
- **GCS repository plugin** — bundled with Elasticsearch distribution
- **Prometheus** via Elasticsearch metrics endpoint (or elasticsearch_exporter)
- No connection pooler — Node.js Elasticsearch client handles connection pooling and node discovery

## Topology
- 1 Elasticsearch CR — 3 nodes with combined master + data + ingest roles, zone-spread
- Each node eligible to handle reads and writes (sharded architecture)
- Separate PVCs per node
- Shard allocation awareness configured per zone
- No Istio sidecar injection on Elasticsearch namespace

## Traffic path
- Node.js search service → Elasticsearch HTTP Service → any of the 3 nodes
- Client handles node discovery and connection pooling natively
- Writes routed to primary shard, reads can hit primary or replica shards
- Loss of a node: replicas promote, cluster self-heals

## TLS
- cert-manager issues short-lived certs for:
  - Transport layer (inter-node communication)
  - HTTP layer (client-to-cluster communication)
- Auto-rotation via cert-manager renewal policy
- ECK consumes certs via `spec.transport.tls.certificate` and `spec.http.tls.certificate` Secret references
- No self-signed operator-managed certs

## Autoscaling
- **VPA** on Elasticsearch pods (`Off` or `Auto` mode depending on data volume)
- For larger data volumes: prefer manual scaling via CRD (`spec.nodeSets[].resources`) so operator orchestrates graceful shard drain
- Generous `terminationGracePeriodSeconds` (300+) for in-flight flush
- During load tests: VPA in `Initial` mode

## Resilience controls
- Operator-managed PDBs on StatefulSets
- Pod anti-affinity (one node per K8s node)
- Topology spread constraints (one node per zone)
- Shard allocation awareness per zone — replicas never co-located with their primary in the same zone
- 3 master-eligible nodes for consensus quorum
- Per-index `number_of_replicas: 1` minimum for HA
- Graceful shard migration handled by operator on rolling updates

## Backups
- Snapshot repository pointing at GCS bucket
- **Snapshot Lifecycle Management (SLM)** policies:
  - Daily incremental snapshots (inherent — only new segments shipped)
  - Weekly full snapshots
- 30-day retention via SLM retention policy + GCS lifecycle
- Authentication via Workload Identity Federation → GCP SA with `roles/storage.objectAdmin`

## Multi-tenant isolation (per service)
- One index (or index pattern) per microservice
- Per-service Elasticsearch users with role-scoped access to only their indices
- Role-based access control via ECK's `elasticsearch.k8s.elastic.co/v1` user and role CRDs

## Deployment
- GitOps via ArgoCD
- Terraform for GCS bucket, IAM bindings, WIF
- Helm for ECK operator install
- Kubernetes manifests for Elasticsearch CR, cert-manager Certificate resources, SLM policy config, VPA, user/role definitions

Here's the docs on deploying it on Kubernetes
https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s

Here's the docs on installing the CRDs and Operator using the Helm chart
https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/install-using-helm-chart

Here's the docs on configuring the Custom Resource Operator
https://www.elastic.co/docs/deploy-manage/deploy/cloud-on-k8s/elasticsearch-deployment-quickstart