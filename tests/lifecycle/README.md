# Lifecycle tests

These end-to-end scenarios install the `heimdall2/` chart from `main` into a disposable Kubernetes
cluster. Each scenario uses its own namespace and cleans it up when finished.

| Script | Scenario |
|---|---|
| `01-minimal.sh` | Bare-minimum values: install, HTTP validation, and clean uninstall |
| `02-embedded-postgres.sh` | In-chart PostgreSQL with persistent data across a pod restart |
| `03-github-service-postgres.sh` | External PostgreSQL supplied by a GitHub Actions service container |
| `04-sops.sh` | SOPS/age encryption and the chart's externally managed Secret mode |
| `05-vault-secret.sh` | Kubernetes Secret contract used by a Vault integration |
| `06-configmap-certs.sh` | Certificate ConfigMap with direct and system trust-store injection |

The chart on `main` does not have a generic `existingSecret` value. It uses `sops.enabled` to suppress
creation of its built-in Secret and expects an external controller to create a Secret named after the
Helm release. The Vault scenario validates that boundary; it does not deploy Vault or an External
Secrets operator.

## Requirements

Install `helm`, `kubectl`, `openssl`, `curl`, `sops`, and `age`, and use a disposable cluster such as
[kind](https://kind.sigs.k8s.io/). The current context must start with `kind-` or `k3d-` unless
`ALLOW_ANY_CONTEXT=1` is explicitly set.

## Run locally

Create a cluster and an external PostgreSQL container for scenario 3:

```bash
kind create cluster --name heimdall-test
docker run --detach --rm --name heimdall-lifecycle-postgres \
  --env POSTGRES_DB=heimdall \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=lifecycle-postgres-password \
  --publish 15432:5432 \
  postgres:17
```

On Docker Desktop, run every scenario with:

```bash
EXTERNAL_POSTGRES_HOST=host.docker.internal \
EXTERNAL_POSTGRES_PORT=15432 \
tests/lifecycle/run-all.sh
```

Run selected scenarios with `ONLY`, for example:

```bash
ONLY="01 04 05" tests/lifecycle/run-all.sh
```

Clean up afterward:

```bash
docker stop heimdall-lifecycle-postgres
kind delete cluster --name heimdall-test
```

## MITRE Artifactory images

MITRE Artifactory's Docker virtual repository proxies the official PostgreSQL image and includes the
PostgreSQL server and `psql` client:

```text
<MITRE Artifactory URL>/docker/postgres:17
```

The UBI image used by the system-certificate scenario is also available through Artifactory:

```text
<MITRE Artifactory URL>/docker/ubi8/ubi:latest
```

Use the UBI mirror without changing the chart defaults:

```bash
CERTS_IMAGE="<MITRE Artifactory URL>/docker/ubi8/ubi" \
CERTS_IMAGE_TAG=latest \
tests/lifecycle/06-configmap-certs.sh
```

Options include `STORAGE_CLASS` (default `standard`) and `WAIT_TIMEOUT` (default `600s`). Generated
keys, values, and certificates are written to `tests/lifecycle/.generated/`, which is gitignored.
