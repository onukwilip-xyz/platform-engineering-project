# microservice Helm Chart

`microservice` is a **generic application chart** for Kubernetes.

It can deploy **either** a `Deployment` **or** a `StatefulSet` with:

- One or more containers and init containers
- Optional Service, HPA, VPA and PodDisruptionBudget
- Optional ExternalSecret integration
- Flexible env vars (plain, Secret, ConfigMap, external secret)
- Optional ServiceAccount (created by the chart, or external)

You use the **same values schema** for all apps; only the values file changes.

---

## Installation

From the OCI registry (adjust version and registry as needed):

```bash
# Template from registry
helm template my-app \
  oci://me-central2-docker.pkg.dev/microservice-434907/helm-charts/microservice \
  --version 1.0.0 \
  -f helm/values/microservice-demo.yaml

# Install into a cluster
helm install my-app \
  oci://me-central2-docker.pkg.dev/microservice-434907/helm-charts/microservice \
  --version 1.0.0 \
  -f helm/values/microservice-demo.yaml
```

From the local chart directory:

```bash
helm install my-app ./helm/custom-charts/microservice \
  -f helm/values/microservice-demo.yaml
```

The **release name** (e.g. `my-app`) is used in resource names and labels (e.g. `my-app-deployment`, `my-app-service`, pods labeled `app.kubernetes.io/name: my-app-pod`).

---

## Top-Level Values

```yaml
useDeployment: true # if true, renders a Deployment
useStatefulSet: false # if true, renders a StatefulSet (mutually exclusive)

replicas: 1
```

- Set **exactly one** of `useDeployment` / `useStatefulSet` to `true`.

---

## Containers and Init Containers

### Main containers

```yaml
containers:
  - name: api
    image: nginx:1.27.2
    imagePullPolicy: IfNotPresent
    resources: {} # full K8s resources spec or leave empty for defaults
    env: {} # simple key: value env
    externalSecrets: {} # env -> key in ExternalSecret target Secret
    secrets: [] # native secretKeyRef entries
    configMaps: [] # native configMapKeyRef entries
    secretRef: [] # list of Secret names for envFrom
    configMapRef: [] # list of ConfigMap names for envFrom
    volumeMounts: [] # standard volumeMounts list
    otherSpecs: {} # extra container fields (probes, args, ports, etc.)
```

#### `env`

Simple key/value env vars:

```yaml
env:
  ENVIRONMENT: "production"
  SERVER_PORT: ":9000"
```

#### `externalSecrets`

Links env vars to keys in the target Secret created via `ExternalSecret`:

```yaml
externalSecrets:
  BLOCKCHAIN_RPC_HTTP_URL_FULL: blockchain-rpc-http-url-full
  THREE_XPL_API_KEY: three-xpl-api-key
```

For each entry, the chart generates:

- An `env` with `valueFrom.secretKeyRef.name = <ExternalSecret target Secret>`
- `valueFrom.secretKeyRef.key = <VALUE>` (e.g. `blockchain-rpc-http-url-full`).

#### `secrets` (native `secretKeyRef`)

```yaml
secrets:
  - name: BITCOIN_RPC_PASSWORD
    valueFrom:
      secretKeyRef:
        name: bitcoin-secret
        key: BITCOIN_RPC_PASSWORD_ARCHIVE
```

#### `configMaps` (native `configMapKeyRef`)

```yaml
configMaps:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: LOG_LEVEL
```

#### `secretRef` / `configMapRef` (for `envFrom`)

```yaml
secretRef:
  - blockchain-secret
configMapRef:
  - app-config
```

#### `volumeMounts`

```yaml
volumeMounts:
  - mountPath: /etc/app/config
    name: app-config-volume
    readOnly: true
```

#### `otherSpecs` (container extras)

Merged directly into the container spec:

```yaml
otherSpecs:
  ports:
    - containerPort: 8080
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8080
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
```

### Init containers

Use the same schema as `containers`:

```yaml
initContainers:
  - name: init-api
    image: ubuntu:22.04
    imagePullPolicy: IfNotPresent
    env: {}
    externalSecrets: {}
    secrets: []
    configMaps: []
    secretRef: []
    configMapRef: []
    volumeMounts: []
    resources: {}
    otherSpecs: {}
```

You can put probes and other fields into `initContainers[].otherSpecs` as needed.

---

## Pod-Level Settings

```yaml
podAnnotations: {}
podLabels: {}
podSecurityContext: {}
securityContext: {} # (reserved; container-level is via otherSpecs)
nodeSelector: {}
affinity: {}
tolerations: []
volumes: [] # standard pod.spec.volumes

# Extra fragment into workload spec (Deployment/StatefulSet .spec)
otherSpecs: {}

# Extra fragment merged into pod template spec (pod.spec)
otherTemplateSpecs: {}
```

Examples:

```yaml
volumes:
  - name: app-config-volume
    secret:
      secretName: cockroach-cockroachdb-ca-secret
      items:
        - key: ca.crt
          path: ca.crt

otherTemplateSpecs:
  restartPolicy: Always
  hostAliases:
    - ip: "127.0.0.1"
      hostnames:
        - "local.example.com"

otherSpecs:
  strategy:
    type: RollingUpdate
```

---

## ServiceAccount

You can either let the chart create a ServiceAccount, or reference an existing one.

### Managed ServiceAccount

```yaml
serviceAccount:
  enabled: true
  name: gke-service-account-name # optional; default is "<release-name>-sa"
  labels: {}
  annotations:
    iam.gke.io/gcp-service-account: microservice-kubernetes-cluster-sa@microservice-434907.iam.gserviceaccount.com

serviceAccountName: "" # ignored when serviceAccount.enabled is true
```

### External ServiceAccount

```yaml
serviceAccount:
  enabled: false

serviceAccountName: existing-service-account
```

Resolution rules in the pod:

1. If `serviceAccount.enabled: true` and `serviceAccount.name` is set → use that.
2. If `serviceAccount.enabled: true` and `serviceAccount.name` is empty → use `<release-name>-sa`.
3. Else, if `serviceAccountName` is non-empty → use `serviceAccountName`.
4. Else → no `serviceAccountName` on the pod.

---

## Service

```yaml
service:
  enabled: true
  type: ClusterIP
  port: 80
  targetPort: 80
  protocol: TCP
  nodePort: null
  annotations: {}
  labels: {}
```

- Service name: `<release-name>-service`
- Selector: `app.kubernetes.io/name: "<release-name>-pod"`

---

## HPA (HorizontalPodAutoscaler)

```yaml
hpa:
  enabled: true
  minReplicas: 1
  maxReplicas: 5
  targetCPUUtilizationPercentage: 80
```

- Targets the Deployment named `<release-name>-deployment`.

---

## VPA (VerticalPodAutoscaler)

```yaml
vpa:
  enabled: true
  updateMode: "Auto"
```

- Creates a VPA resource (see `templates/vpa.yaml`) to adjust pod resources.

---

## PodDisruptionBudget (PDB)

```yaml
pdb:
  enabled: true
  minAvailable: 1
  maxUnavailable: null
```

- Name: `<release-name>-pdb`
- Selects pods labeled `app.kubernetes.io/name: "<release-name>-pod"`.

Only set **one** of `minAvailable` or `maxUnavailable`.

---

## ExternalSecret (external-secrets.io)

```yaml
externalSecret:
  enabled: true
  name: "" # default "<release-name>-externalsecret"
  secretStoreRef:
    name: google-secret-manager-store
    kind: SecretStore
  refreshInterval: 24h
  targetName: "" # default "<release-name>-secret"
```

- ExternalSecret name: `<release-name>-externalsecret` (or `externalSecret.name`).
- Target Secret name: `<release-name>-secret` (or `externalSecret.targetName`).
- For each `containers[].externalSecrets` entry, the chart adds:

  ```yaml
  - secretKey: "<value>"
    remoteRef:
      key: "<value>"
  ```

  and wires the pod `env` to that target Secret/key.

---

## Typical Use Cases

### 1. Simple Deployment with one container and Service

```yaml
useDeployment: true
useStatefulSet: false

replicas: 2

containers:
  - name: api
    image: your-image:tag
    env:
      ENVIRONMENT: "staging"
    otherSpecs:
      ports:
        - containerPort: 8080
      livenessProbe:
        httpGet:
          path: /healthz
          port: 8080

service:
  enabled: true
  port: 80
  targetPort: 8080
```

Install:

```bash
helm install my-api \
  oci://me-central2-docker.pkg.dev/microservice-434907/helm-charts/microservice \
  --version 1.0.0 \
  -f ./helm/values/my-api.yaml
```

### 2. StatefulSet for a database

```yaml
useDeployment: false
useStatefulSet: true

replicas: 3

containers:
  - name: db
    image: postgres:16
    env:
      POSTGRES_DB: mydb
    volumeMounts:
      - name: data
        mountPath: /var/lib/postgresql/data
    otherSpecs:
      ports:
        - containerPort: 5432

volumes:
  - name: data
    persistentVolumeClaim:
      claimName: my-pvc
```

### 3. App using ExternalSecret + managed ServiceAccount

```yaml
containers:
  - name: api
    image: my-app:latest
    externalSecrets:
      DB_PASSWORD: db-password
      API_KEY: api-key
    env:
      APP_MODE: production

externalSecret:
  enabled: true
  # name/targetName defaults are fine

serviceAccount:
  enabled: true
  name: gke-service-account-name
  annotations:
    iam.gke.io/gcp-service-account: microservice-kubernetes-cluster-sa@microservice-434907.iam.gserviceaccount.com

service:
  enabled: true
  port: 80
  targetPort: 8080
```

---

For more specific stacks you can build
additional values files on top of the same schema and reuse this chart.
