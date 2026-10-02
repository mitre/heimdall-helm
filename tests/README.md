# Helm chart test suite

This file documents the complete CI suite; it is not documentation for only the unit tests. All
seven stages are defined in [`.github/workflows/test.yml`](../.github/workflows/test.yml), with the
runtime scenario scripts under `tests/lifecycle/`.

Run the following commands from the repository root.

## Workflow linting and dependency updates

The `Lint GitHub Workflows` workflow runs on every pull request to `main` and push to `main`.
It checks `.github/` with zizmor and all workflows with actionlint, including ShellCheck and
pyflakes checks for embedded scripts. Both checks report failures through GitHub annotations.

To run the checks locally, install zizmor, actionlint from `kjanat/actionlint`, ShellCheck, and
pyflakes, then run:

```bash
zizmor .github
actionlint
```

Dependabot checks GitHub Actions daily at 8 p.m. Eastern time and waits seven days after a
release before opening version updates. Action references are pinned to commit hashes, with
version comments for Dependabot to maintain.

The `Auto approve and Merge Dependabot PRs` workflow verifies Dependabot commits, approves
updates, and enables auto-merge once required checks and branch protection rules are satisfied.
Major GitHub Actions updates require manual review and approval; the workflow leaves a comment
explaining this exception. Updates from other ecosystems remain eligible if added to Dependabot.
The workflow uses `pull_request` with explicit `contents: write` and `pull-requests: write`
permissions and never checks out pull request code.
Repository settings must enable auto-merge and allow GitHub Actions to create and approve pull
requests.

## Coverage

| Stage | CI job | Coverage |
|---|---|---|
| 1 | `lint` | Helm chart linting with chart-testing |
| 2 | `unit-test` | Secret template behavior |
| 3 | `env-vars-validation` | Required environment variables and Secret references |
| 4 | `schema-validation` | Strict Helm linting and values rendering |
| 5 | `integration-test` | Installation into Kubernetes 1.30 and the Helm test hook |
| 6 | `template-test` | Embedded PostgreSQL, external PostgreSQL, and ingress rendering |
| 7 | `lifecycle-test` | Runtime installation, PostgreSQL, SOPS, Vault-compatible Secrets, and certificates |

The suite requires Docker Desktop, Helm 3.22.0, `kubectl`, `kind`, chart-testing (`ct`), Python 3
with PyYAML, and the `helm-unittest` plugin. Stage 7 also requires SOPS, age, OpenSSL, and curl.

## Run stages independently

### 1. Lint

Run the same changed-chart lint command used by CI:

```bash
ct lint --config .github/ct.yaml
```

Chart-testing compares the current branch with the target branch configured in `.github/ct.yaml`.
Do not add `--all`, because that does not reproduce CI's changed-chart selection.

### 2. Unit tests

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest \
  --version=6f82a998e0b5461762ca959f87f5dd344af5e4eb
helm unittest --strict -f '../tests/unit/*_test.yaml' ./heimdall2
```

The pinned plugin commit corresponds to release `v1.0.3`.

### 3. Environment variables

Create a temporary Python environment and render the chart:

```bash
python3 -m venv /tmp/heimdall-ci-python
source /tmp/heimdall-ci-python/bin/activate
pip install pyyaml
helm template heimdall ./heimdall2 \
  --set-string jwtSecret=env-test-jwt \
  --set-string databasePassword=env-test-db \
  --set-string apiKeySecret=env-test-api \
  --set-string adminPassword=env-test-admin \
  --set-string externalUrl=http://localhost:3000 \
  --set heimdall.ingress.enabled=false \
  > /tmp/heimdall-env.yaml
```

Run the Python validation block from the `env-vars-validation` job in
`.github/workflows/test.yml`, then run `deactivate`.

### 4. Schema and values

```bash
helm lint --strict ./heimdall2 \
  --set-string jwtSecret=schema-test-jwt \
  --set-string databasePassword=schema-test-db \
  --set-string apiKeySecret=schema-test-api \
  --set-string externalUrl=http://localhost:3000
helm template heimdall ./heimdall2 \
  --set-string jwtSecret=schema-test-jwt \
  --set-string databasePassword=schema-test-db \
  --set-string apiKeySecret=schema-test-api \
  --set-string externalUrl=http://localhost:3000 \
  > /dev/null
```

Helm validates `values.schema.json` automatically when the chart contains one. Until then, this
stage validates strict linting and rendering.

### 5. Kubernetes integration

```bash
kind create cluster --name heimdall-ci-v130 \
  --image kindest/node:v1.30.0@sha256:047357ac0cfea04663786a612ba1eaba9702bef25227a794b52890dd8bcd692e
ct install --config .github/ct.yaml --all \
  --helm-extra-set-args \
  '--set-string jwtSecret=integration-test-jwt --set-string databasePassword=integration-test-db --set-string apiKeySecret=integration-test-api --set-string externalUrl=http://localhost:3000 --set heimdall.ingress.enabled=false'
kind delete cluster --name heimdall-ci-v130
```

### 6. Template rendering

Run the three `helm template` commands and the manifest checks in the workflow's `template-test`
job. They render and verify these configurations independently:

- embedded PostgreSQL;
- external PostgreSQL; and
- ingress enabled.

### 7. Runtime lifecycle

These scenarios install the `heimdall2/` chart from `main` into a disposable Kubernetes cluster.
Each scenario uses its own namespace and attempts to remove it when finished.

| Script | Scenario |
|---|---|
| `01-minimal.sh` | Bare-minimum values: install, HTTP validation, and clean uninstall |
| `02-embedded-postgres.sh` | In-chart PostgreSQL with persistent data across a pod restart |
| `03-github-service-postgres.sh` | External PostgreSQL supplied by a GitHub Actions service container |
| `04-sops.sh` | SOPS/age encryption and the chart's externally managed Secret mode |
| `05-vault-secret.sh` | Kubernetes Secret contract used by a Vault integration |
| `06-configmap-certs.sh` | Certificate ConfigMap with direct and system trust-store injection |

The chart does not have a generic `existingSecret` value. Setting `sops.enabled` suppresses creation
of its built-in Secret, allowing an external controller to create a Secret named after the Helm
release. The Vault scenario validates this contract; it does not deploy Vault or an External Secrets
operator.

Use a disposable cluster such as Kind. The scripts require the current Kubernetes context to start
with `kind-` or `k3d-`; set `ALLOW_ANY_CONTEXT=1` only when intentionally using another context.

Create the cluster and the external PostgreSQL container required by scenario 3:

```bash
kind create cluster --name heimdall-test
docker run --detach --rm --name heimdall-lifecycle-postgres \
  --env POSTGRES_DB=heimdall \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=lifecycle-postgres-password \
  --publish 15432:5432 \
  postgres:17@sha256:d74eeac9a635390a49bc21bd49fccd973de707e2a53a76ac49b552b8712ec46f
EXTERNAL_POSTGRES_HOST=host.docker.internal \
EXTERNAL_POSTGRES_PORT=15432 \
EXTERNAL_POSTGRES_PASSWORD=lifecycle-postgres-password \
tests/lifecycle/run-all.sh
```

Use `ONLY` to run selected scenarios, for example:

```bash
ONLY='01' tests/lifecycle/run-all.sh
ONLY='03 05' \
  EXTERNAL_POSTGRES_HOST=host.docker.internal \
  EXTERNAL_POSTGRES_PORT=15432 \
  tests/lifecycle/run-all.sh
```

Clean up afterward:

```bash
docker stop heimdall-lifecycle-postgres
kind delete cluster --name heimdall-test
```

Options include `STORAGE_CLASS` (default `standard`) and `WAIT_TIMEOUT` (default `600s`). Generated
keys, values, and certificates are written to `tests/lifecycle/.generated/`, which is ignored by Git.
