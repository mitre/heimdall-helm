# Lifecycle tests

These end-to-end scenarios install the chart in a disposable Kubernetes cluster and validate the
runtime behaviors required by the Helm testing ticket. Every scenario uses its own namespace and
cleans it up on exit.

| Script | Scenario |
|---|---|
| `01-minimal.sh` | Bare-minimum install, HTTP validation, and clean uninstall |
| `02-embedded-postgres.sh` | Embedded PostgreSQL with persistent data across a pod restart |
| `03-github-service-postgres.sh` | External PostgreSQL supplied by a GitHub Actions service container |
| `04-sops.sh` | SOPS/age encryption with an externally managed Kubernetes Secret |
| `05-vault-secret.sh` | `existingSecret` contract used by Vault or External Secrets integrations |
| `06-configmap-certs.sh` | Baseline ConfigMap values and custom CA certificate bundle |

The Vault scenario validates the chart boundary after Vault has synchronized a Kubernetes Secret. It
does not deploy Vault or an External Secrets operator.

## Requirements

Install `helm`, `kubectl`, `openssl`, `curl`, `sops`, and `age`, and use a disposable cluster such as
[kind](https://kind.sigs.k8s.io/). The current context must start with `kind-` or `k3d-` unless
`ALLOW_ANY_CONTEXT=1` is explicitly set.

## Run locally

Create a cluster and a local PostgreSQL container for scenario 3:

```bash
kind create cluster --name heimdall-test
docker run --detach --rm --name heimdall-lifecycle-postgres \
  --env POSTGRES_DB=heimdall \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=lifecycle-postgres-password \
  --publish 15432:5432 \
  postgres:17
```

On Docker Desktop, run all scenarios with:

```bash
EXTERNAL_POSTGRES_HOST=host.docker.internal \
EXTERNAL_POSTGRES_PORT=15432 \
heimdall/tests/lifecycle/run-all.sh
```

Run selected scenarios with `ONLY`, for example:

```bash
ONLY="01 04 05" heimdall/tests/lifecycle/run-all.sh
```

Clean up the local resources afterward:

```bash
docker stop heimdall-lifecycle-postgres
kind delete cluster --name heimdall-test
```

Generated keys, values, and certificates are written to `.generated/`, which is gitignored.
