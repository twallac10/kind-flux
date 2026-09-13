# Flux Operator Migration + Multi-Tenant ResourceSet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `flux2` Helm chart bootstrap with the Flux Operator (`FluxInstance`-driven), and add a multi-tenant example using the operator's `ResourceSet` CRD.

**Architecture:** `helmfile apply` installs the `flux-operator` OCI chart, then its postsync hook applies a `FluxInstance` CR whose `spec.sync` bootstraps Flux from this repo (replacing the hand-written `bootstrap.yaml`). `clusters/kind/flux-system/` becomes Flux's self-managed config root (holds the `FluxInstance` manifest itself plus `base`/`config`/`tenants`/`app` `Kustomization`s). A `ResourceSet` in `clusters/kind/tenants/` expands two example tenants (`team-a`, `team-b`) into fully isolated namespaces — each with its own `GitRepository`, copied git credentials `Secret`, `ServiceAccount`, and `Kustomization` — required because Flux's multi-tenancy lockdown forbids a tenant's `Kustomization` from referencing a `GitRepository` or `Secret` outside its own namespace.

**Tech Stack:** Flux Operator v0.60.0 (`oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator`), Flux distribution 2.9.x, Helmfile v1.8.0, Kind, kubectl/kustomize.

**Spec:** `docs/superpowers/specs/2026-09-13-flux-operator-migration-design.md`

## Global Constraints

- Flux Operator chart version pinned to `0.60.0`.
- Flux distribution version pinned to `"2.9.x"`, registry `ghcr.io/fluxcd`.
- Enabled Flux components: `source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller` only (matches today's disabled image-automation/image-reflection toggles).
- `cluster.multitenant: true` and `cluster.tenantDefaultServiceAccount: flux-tenant` on the `FluxInstance`.
- Git repo URL: `https://github.com/twallac10/kind-flux`, branch `main` (matches existing `bootstrap.yaml`).
- Git credentials secret name stays `flux-git-repo` everywhere (existing name, referenced by `pullSecret`/`secretRef`).
- Example tenant names: `team-a`, `team-b`.
- Every task's YAML must pass local `kubectl kustomize` / `helmfile build` validation before commit — no cluster is required until Task 5.

---

### Task 1: Switch Helm install to the Flux Operator chart

**Files:**
- Modify: `helmfile.yaml`
- Delete: `values/flux.yaml`

**Interfaces:**
- Produces: a `flux-operator` Helm release in namespace `flux-system`, whose postsync hook runs `kubectl apply -f clusters/kind/flux-system/flux-instance.yaml` (file created in Task 2 — this task's hook will 404 harmlessly if run standalone before Task 2 lands; that's fine, `helmfile build` doesn't execute hooks).

- [ ] **Step 1: Rewrite `helmfile.yaml`**

```yaml
releases:
  - name: flux-operator
    chart: oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator
    version: 0.60.0
    namespace: flux-system
    createNamespace: true
    hooks:
      - events: [postsync]
        command: kubectl
        args:
          - apply
          - -f
          - clusters/kind/flux-system/flux-instance.yaml
```

- [ ] **Step 2: Delete the old flux2 values file**

```bash
git rm values/flux.yaml
```

- [ ] **Step 3: Validate the helmfile resolves and the chart pulls cleanly**

Run: `helmfile build`
Expected: no errors; output shows `chart: oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator`, `version: 0.60.0`, and the postsync hook args ending in `clusters/kind/flux-system/flux-instance.yaml`.

- [ ] **Step 4: Commit**

```bash
git add helmfile.yaml values/flux.yaml
git commit -m "Switch Flux install from flux2 chart to Flux Operator"
```

---

### Task 2: Replace the flux2 self-management manifest with FluxInstance + top-level Kustomizations

**Files:**
- Create: `clusters/kind/flux-system/flux-instance.yaml`
- Create: `clusters/kind/flux-system/kustomizations.yaml`
- Modify: `clusters/kind/flux-system/kustomization.yaml`
- Delete: `clusters/kind/flux-system/flux.yaml`
- Delete: `bootstrap.yaml`
- Delete: `clusters/kind/apps.yaml` (dead file — not referenced by any `kustomization.yaml`; its `app` `Kustomization` spec is recreated verbatim in `kustomizations.yaml` below)

**Interfaces:**
- Produces: a `GitRepository` (implicitly created by the operator from `FluxInstance.spec.sync`, named `flux-system` in namespace `flux-system` — the default name equals the namespace) that `kustomizations.yaml`'s `sourceRef.name: flux-system` and Task 3's tenant `GitRepository`s' sibling relationship both depend on knowing about.

- [ ] **Step 1: Create `clusters/kind/flux-system/flux-instance.yaml`**

```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: FluxInstance
metadata:
  name: flux
  namespace: flux-system
spec:
  distribution:
    version: "2.9.x"
    registry: "ghcr.io/fluxcd"
  components:
    - source-controller
    - kustomize-controller
    - helm-controller
    - notification-controller
  cluster:
    type: kubernetes
    multitenant: true
    tenantDefaultServiceAccount: flux-tenant
  sync:
    kind: GitRepository
    url: "https://github.com/twallac10/kind-flux"
    ref: "refs/heads/main"
    path: "./clusters/kind/flux-system"
    pullSecret: flux-git-repo
    interval: 1m
```

- [ ] **Step 2: Create `clusters/kind/flux-system/kustomizations.yaml`**

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: base
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  prune: false
  path: ./clusters/kind/base
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: config
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  prune: false
  path: ./clusters/kind/config
  dependsOn:
    - name: base
      namespace: flux-system
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: tenants
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  prune: false
  path: ./clusters/kind/tenants
  dependsOn:
    - name: base
      namespace: flux-system
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: app
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./app
  prune: true
  wait: true
  timeout: 5m0s
  dependsOn:
    - name: config
      namespace: flux-system
```

- [ ] **Step 3: Update `clusters/kind/flux-system/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- flux-instance.yaml
- kustomizations.yaml
```

- [ ] **Step 4: Delete the superseded files**

```bash
git rm clusters/kind/flux-system/flux.yaml bootstrap.yaml clusters/kind/apps.yaml
```

- [ ] **Step 5: Validate the kustomization builds**

Run: `kubectl kustomize clusters/kind/flux-system`
Expected: no errors; output contains one `FluxInstance`, and four `Kustomization` objects named `base`, `config`, `tenants`, `app`.

- [ ] **Step 6: Commit**

```bash
git add clusters/kind/flux-system bootstrap.yaml clusters/kind/apps.yaml
git commit -m "Replace flux2 self-management with FluxInstance bootstrap"
```

---

### Task 3: Multi-tenant ResourceSet (team-a, team-b)

**Files:**
- Create: `clusters/kind/tenants/resourceset.yaml`
- Create: `clusters/kind/tenants/kustomization.yaml`
- Create: `tenants/team-a/configmap.yaml`
- Create: `tenants/team-a/kustomization.yaml`
- Create: `tenants/team-b/configmap.yaml`
- Create: `tenants/team-b/kustomization.yaml`

**Interfaces:**
- Consumes: the `flux-git-repo` `Secret` and the git repo URL/branch from Task 2's `FluxInstance` (same values, duplicated per tenant via `copyFrom` and a per-tenant `GitRepository`).
- Produces: for each tenant, a `Kustomization` (name == tenant name, namespace == tenant name) reconciling `./tenants/<tenant>` under `ServiceAccount` `flux`.

- [ ] **Step 1: Create `clusters/kind/tenants/resourceset.yaml`**

```yaml
apiVersion: fluxcd.controlplane.io/v1
kind: ResourceSet
metadata:
  name: tenants
  namespace: flux-system
spec:
  inputs:
    - tenant: team-a
    - tenant: team-b
  resources:
    - apiVersion: v1
      kind: Namespace
      metadata:
        name: << inputs.tenant >>
        labels:
          toolkit.fluxcd.io/tenant: << inputs.tenant >>
    - apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: flux
        namespace: << inputs.tenant >>
    - apiVersion: rbac.authorization.k8s.io/v1
      kind: RoleBinding
      metadata:
        name: flux
        namespace: << inputs.tenant >>
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: edit
      subjects:
        - kind: ServiceAccount
          name: flux
          namespace: << inputs.tenant >>
    - apiVersion: v1
      kind: Secret
      type: Opaque
      metadata:
        name: flux-git-repo
        namespace: << inputs.tenant >>
        annotations:
          fluxcd.controlplane.io/copyFrom: "flux-system/flux-git-repo"
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      metadata:
        name: << inputs.tenant >>
        namespace: << inputs.tenant >>
      spec:
        interval: 1m
        url: "https://github.com/twallac10/kind-flux"
        ref:
          branch: main
        secretRef:
          name: flux-git-repo
    - apiVersion: kustomize.toolkit.fluxcd.io/v1
      kind: Kustomization
      metadata:
        name: << inputs.tenant >>
        namespace: << inputs.tenant >>
      spec:
        interval: 1m0s
        serviceAccountName: flux
        sourceRef:
          kind: GitRepository
          name: << inputs.tenant >>
        path: ./tenants/<< inputs.tenant >>
        prune: true
```

- [ ] **Step 2: Create `clusters/kind/tenants/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- resourceset.yaml
```

- [ ] **Step 3: Create `tenants/team-a/configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello
  namespace: team-a
data:
  message: hello from team-a
```

- [ ] **Step 4: Create `tenants/team-a/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- configmap.yaml
```

- [ ] **Step 5: Create `tenants/team-b/configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello
  namespace: team-b
data:
  message: hello from team-b
```

- [ ] **Step 6: Create `tenants/team-b/kustomization.yaml`**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- configmap.yaml
```

- [ ] **Step 7: Validate all four kustomizations build**

Run:
```bash
kubectl kustomize clusters/kind/tenants
kubectl kustomize tenants/team-a
kubectl kustomize tenants/team-b
```
Expected: all three succeed with no errors; the first shows one `ResourceSet` named `tenants` with the two-entry `inputs` list and six resource templates; the other two each show a single `ConfigMap` named `hello` in the matching namespace.

- [ ] **Step 8: Commit**

```bash
git add clusters/kind/tenants tenants
git commit -m "Add multi-tenant ResourceSet provisioning for team-a and team-b"
```

---

### Task 4: Reorder taskfile so the git secret exists before helmfile applies the FluxInstance

**Files:**
- Modify: `taskfile.yaml`

**Interfaces:**
- Consumes: nothing new — same `gh api user`/`gh auth token`/`kubectl create secret` logic already in the file, just reordered ahead of `helmfile apply`.

**Context:** Today, `helmfile apply`'s postsync hook applies `bootstrap.yaml`, whose `GitRepository` doesn't actually need the secret to exist at apply time (source-controller just retries until it does). With `FluxInstance.spec.sync`, the operator applies its `GitRepository` as part of reconciling the `FluxInstance` the *first* time the hook runs — same retry behavior applies, so this reordering is a robustness improvement (avoid a guaranteed first-attempt failure and retry-wait), not a hard requirement. Do it for a clean first run.

- [ ] **Step 1: Reorder `install_flux` in `taskfile.yaml`**

```yaml
  install_flux:
    desc: Install Flux
    vars:
      GITHUB_USERNAME: $(gh api user | jq -r .login)
      GITHUB_TOKEN: $(gh auth token)
    cmds:
      # Check if secret exists, if not create it
      - |
        if ! kubectl get secret flux-git-repo -n flux-system; then
          echo "Creating secret flux-git-repo"
          kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
          kubectl create secret generic flux-git-repo --from-literal=username={{.GITHUB_USERNAME}} --from-literal=password={{.GITHUB_TOKEN}} -n flux-system
        else
          echo "Secret flux-git-repo already exists"
        fi
      - helmfile apply
```

Note the added `kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -`: the namespace previously existed by the time this step ran (created earlier by `helmfile apply`'s `createNamespace: true` on the `flux` release). Now that secret creation runs first, the namespace doesn't exist yet on a fresh cluster, so it must be created here too. This is idempotent and safe to rerun.

- [ ] **Step 2: Confirm the taskfile still parses and lists correctly**

Run: `task --list`
Expected: no errors; `install_flux`, `build_cluster`, `build`, and `delete_cluster` are all listed as before.

- [ ] **Step 3: Commit**

```bash
git add taskfile.yaml
git commit -m "Create flux-git-repo secret before helmfile apply"
```

---

### Task 5: End-to-end validation on a real Kind cluster

**Files:** none (validation only)

**Interfaces:** none — this task exercises the full stack built by Tasks 1-4.

- [ ] **Step 1: Push to `main`**

```bash
git push origin main
```

- [ ] **Step 2: Build the cluster and install Flux**

Run: `task build`
Expected: `kind create cluster --name flux ...` succeeds, the `flux-git-repo` secret is created, and `helmfile apply` installs the `flux-operator` release without error.

- [ ] **Step 3: Verify the FluxInstance and operator are healthy**

Run:
```bash
kubectl -n flux-system get deployment flux-operator
kubectl -n flux-system get fluxinstance flux -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```
Expected: the deployment is `Available`; the `FluxInstance` condition shows `"status":"True"`.

- [ ] **Step 4: Verify the GitOps sync and the top-level Kustomizations are healthy**

Run:
```bash
kubectl -n flux-system get gitrepository flux-system
for k in base config tenants app; do
  echo -n "$k: "
  kubectl -n flux-system get kustomization "$k" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
done
```
Expected: the `GitRepository` reports `Ready=True` with an artifact revision from `main`; all four `Kustomization`s report `READY=True` (allow a couple of reconcile intervals — up to ~2 minutes — for `app`, which depends on `config`).

- [ ] **Step 5: Verify the tenants were provisioned and are isolated**

Run:
```bash
kubectl get resourceset -n flux-system tenants -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
kubectl get ns team-a team-b
kubectl -n team-a get configmap hello -o jsonpath='{.data.message}'
kubectl -n team-b get configmap hello -o jsonpath='{.data.message}'
kubectl -n team-a get gitrepository,kustomization
kubectl -n team-a get kustomization team-a -o jsonpath='{.status.conditions[?(@.type=="Ready")]}'
```
Expected: the `ResourceSet` is `Ready=True`; both namespaces exist; the ConfigMaps read back `hello from team-a` / `hello from team-b`; `team-a`'s namespace has its own `GitRepository` and `Kustomization` (not a reference to `flux-system`'s), and that `Kustomization` is `Ready=True`.

- [ ] **Step 6: Spot-check the lockdown is actually enforced, not just configured**

Run:
```bash
kubectl -n flux-system get deployment kustomize-controller -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\n' | grep cross-namespace
```
Expected: `--no-cross-namespace-refs=true` is present in the container args, confirming `cluster.multitenant: true` actually flowed through to the controller flag (not just declared in the `FluxInstance` spec).

- [ ] **Step 7: Tear down**

Run: `task delete_cluster`
Expected: the `flux` Kind cluster is deleted.

- [ ] **Step 8: Record the validation result**

If every check in Steps 3-6 passed, no file changes are needed — the plan is complete. If anything failed, fix the relevant task's files, re-push, and repeat from Step 2 before considering the plan done.
