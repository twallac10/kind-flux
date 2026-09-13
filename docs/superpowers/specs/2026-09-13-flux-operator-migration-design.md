# Migrate to Flux Operator + Multi-Tenant ResourceSet

## Context

The Kind cluster currently bootstraps GitOps via `helmfile apply`, which
installs the `fluxcd-community/flux2` Helm chart and then (via a postsync
hook) `kubectl apply -f bootstrap.yaml`. `bootstrap.yaml` hand-declares a
`GitRepository` plus four `Kustomization`s (`flux-system`, `base`, `config`,
`app`). Once running, Flux manages its own upgrade via a self-referencing
`HelmRelease` committed at `clusters/kind/flux-system/flux.yaml`.

This migrates the install to the
[Flux Operator](https://fluxoperator.dev) (`controlplaneio-fluxcd`), and adds
a multi-tenant example using the operator's `ResourceSet` API.

## Goals

1. Install Flux via the `flux-operator` OCI Helm chart instead of the `flux2`
   community chart.
2. Configure Flux via a `FluxInstance` custom resource instead of a
   hand-written `GitRepository` + bootstrap `Kustomization`.
3. Stretch: demonstrate Flux multi-tenancy lockdown, provisioning tenants
   declaratively via the operator's `ResourceSet` CRD.

## Non-goals

- Changing what `base`/`config`/`app` actually deploy (kuma, kyverno,
  kube-state-metrics, httpbin) — those move files, not behavior.
- Building real tenant workloads — the tenant examples are minimal proof
  that lockdown works, not new application functionality.

## Design

### Bootstrap flow

1. `task build_cluster` — unchanged.
2. `task install_flux`:
   - Create the `flux-git-repo` secret **first** (moved earlier — the
     postsync hook now needs it immediately, there's no later manual step).
   - `helmfile apply` installs `flux-operator` via its OCI chart, then (via
     the existing postsync hook mechanism) applies
     `clusters/kind/flux-system/flux-instance.yaml`.
   - The `FluxInstance` tells the operator which Flux controllers to run
     (`source-controller`, `kustomize-controller`, `helm-controller`,
     `notification-controller` — same set as today) and declares
     `spec.sync`, pointed at this repo, `main`, path
     `./clusters/kind/flux-system`. The operator creates the `GitRepository`
     and top-level `Kustomization` for that sync itself — no more
     hand-written `bootstrap.yaml`.
   - That top-level Kustomization reconciles `clusters/kind/flux-system/`,
     which contains the `FluxInstance` manifest itself (self-management,
     same trick as today's self-referencing `HelmRelease`) plus the
     `base`, `config`, `tenants`, and `app` `Kustomization` objects (moved
     out of `bootstrap.yaml`).
   - The `tenants` Kustomization applies a `ResourceSet`, which the operator
     expands into per-tenant `Namespace`/`ServiceAccount`/`RoleBinding`/
     `Kustomization` objects. Each tenant `Kustomization` runs under its own
     `ServiceAccount`, pulling `./tenants/<name>`.

### Files

- `helmfile.yaml` — release `flux` → `flux-operator`
  (`oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator`, pinned
  `0.60.0`); postsync hook applies `flux-instance.yaml` instead of
  `bootstrap.yaml`.
- `bootstrap.yaml` — deleted.
- `values/flux.yaml` — deleted (its two toggles are now expressed as the
  `spec.components` list on `FluxInstance`).
- `clusters/kind/flux-system/flux.yaml` — deleted, replaced by
  `clusters/kind/flux-system/flux-instance.yaml`:
  - `distribution.version: "2.9.x"`, `registry: ghcr.io/fluxcd`
  - `components`: source/kustomize/helm/notification-controller only
  - `cluster.multitenant: true`, `cluster.tenantDefaultServiceAccount: flux-tenant`
  - `sync`: `GitRepository`, this repo, `refs/heads/main`,
    `path: ./clusters/kind/flux-system`, `pullSecret: flux-git-repo`,
    `interval: 1m`
- `clusters/kind/flux-system/kustomizations.yaml` — new file holding the
  `base`, `config`, `tenants`, and `app` `Kustomization` objects (moved from
  `bootstrap.yaml`; `app`'s existing home at `clusters/kind/apps.yaml` is
  removed since it's now declared here instead — same spec).
- `clusters/kind/flux-system/kustomization.yaml` — updated `resources:` list.
- `clusters/kind/tenants/resourceset.yaml` — a `ResourceSet`
  (`fluxcd.controlplane.io/v1`) with static `.spec.inputs` for two example
  tenants, `team-a` and `team-b`. Per tenant it generates:
  - `Namespace: <tenant>`
  - `ServiceAccount: flux` in that namespace
  - `RoleBinding` binding that `ServiceAccount` to the built-in `edit`
    `ClusterRole`, scoped to the tenant namespace
  - `Kustomization` (`serviceAccountName: flux`, `targetNamespace: <tenant>`,
    `path: ./tenants/<tenant>`, `prune: true`, `sourceRef` → the
    operator-created `flux-system` `GitRepository`)
- `clusters/kind/tenants/kustomization.yaml` — new, references
  `resourceset.yaml`.
- `tenants/team-a/configmap.yaml`, `tenants/team-b/configmap.yaml` — one
  trivial namespaced `ConfigMap` each, proving the tenant `Kustomization`
  reconciles under its own locked-down `ServiceAccount`.
- `taskfile.yaml` — `install_flux` reordered: create the git secret, then
  `helmfile apply`.

### Multi-tenancy lockdown behavior

`cluster.multitenant: true` turns on Flux's standard tenant lockdown
(mandatory `serviceAccountName` and no cross-namespace source/secret refs
for Kustomizations outside `flux-system`). `base`/`config`/`app` stay in the
`flux-system` namespace and keep running as the default Flux identity —
unaffected. Only the generated tenant `Kustomization`s are subject to
lockdown, confined to their own namespace via their own `ServiceAccount`.

## Testing

`kind`, `helm`, `kubectl`, and `helmfile` are available locally and no Kind
cluster is currently running under the `flux` cluster name this repo's
taskfile uses. Plan: commit these changes, push to `main` (this is a
personal learning repo — confirmed with the user), then run
`task build` (`build_cluster` + `install_flux`) against a real Kind cluster
and verify:

- `flux-operator` deployment comes up in `flux-system`
- `FluxInstance` reports `Ready`
- `base`, `config`, `app` `Kustomization`s reconcile successfully
- the `ResourceSet` expands into `team-a`/`team-b` namespaces, each with its
  `ConfigMap` applied
- a tenant `Kustomization` cannot reach outside its namespace (spot-check
  the lockdown is actually enforced, not just configured)

Tear down with `task delete_cluster` after validation.
