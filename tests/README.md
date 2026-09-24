# Testing the Heimdall Helm chart

The CI workflow in [`.github/workflows/test.yml`](../.github/workflows/test.yml) implements seven
independent test stages for the `heimdall2/` chart on `main`. Chart-testing settings are defined in
[`.github/ct.yaml`](../.github/ct.yaml).

Run all commands in this guide from the repository root.

## Implemented test coverage

| Stage | CI job | Coverage |
|---|---|---|
| 1 | `lint` | Helm chart linting through `ct lint` |
| 2 | `unit-test` | Helm template unit tests for Secret creation, keys, values, encoding, and externally managed mode |
| 3 | `env-vars-validation` | Required StatefulSet environment variables and Secret references |
| 4 | `schema-validation` | Strict Helm linting and values/template rendering |
| 5 | `integration-test` | Installation into Kubernetes 1.30 with `ct install`, followed by the chart's Helm connection test |
| 6 | `template-test` | Rendering with embedded PostgreSQL, external PostgreSQL, and ingress |
| 7 | `lifecycle-test` | Runtime scenarios for minimum values, PostgreSQL, SOPS, Vault-compatible Secrets, and certificate ConfigMaps |

Stage 4 currently cannot perform JSON Schema rejection tests because `main` does not contain
`heimdall2/values.schema.json`. It validates the chart with strict Helm linting and rendering, and CI
reports the missing schema as a notice.

## Local requirements

The stages collectively require:

- Docker Desktop
- Helm 3.22.0
- `kubectl`
- `kind`
- `ct` (Helm chart-testing)
- Python 3 and PyYAML
- The `helm-unittest` plugin
- SOPS and age for Stage 7
- `openssl` and `curl` for Stage 7

Confirm the main tools are available:

```bash
helm version --short
kubectl version --client
kind version
ct version
python3 --version
sops --version
age --version
```

## Stage 1: lint

The CI command is:

```bash
ct lint --config .github/ct.yaml
```

That command only processes charts changed relative to `main`. A test-only branch may therefore
report `No chart changes detected`. To force local validation of the chart, run:

```bash
ct lint --config .github/ct.yaml --all
```

Expected result: `All charts linted successfully`.

## Stage 2: unit tests

The unit suite is in [`tests/unit/secrets_test.yaml`](unit/secrets_test.yaml). It contains four tests
covering the generated Kubernetes Secret and externally managed Secret mode.

If the plugin is not already installed, install the version used by CI:

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest --version=v1.0.3
```

Run Stage 2 independently:

```bash
helm unittest --strict \
  -f '../tests/unit/*_test.yaml' \
  ./heimdall2
```

Expected result:

```text
Test Suites: 1 passed, 1 total
Tests:       4 passed, 4 total
```

## Stage 3: environment-variable validation

Create an isolated Python environment so local Python packages are not modified:

```bash
python3 -m venv /tmp/heimdall-ci-python
source /tmp/heimdall-ci-python/bin/activate
pip install pyyaml
```

Render the chart:

```bash
helm template heimdall ./heimdall2 \
  --set-string jwtSecret=env-test-jwt \
  --set-string databasePassword=env-test-db \
  --set-string apiKeySecret=env-test-api \
  --set-string adminPassword=env-test-admin \
  --set-string externalUrl=http://localhost:3000 \
  --set heimdall.ingress.enabled=false \
  > /tmp/heimdall-env.yaml
```

Validate the rendered StatefulSet:

```bash
python - <<'PY'
import yaml

with open('/tmp/heimdall-env.yaml', encoding='utf-8') as stream:
    documents = [document for document in yaml.safe_load_all(stream) if document]

statefulset = next(
    document for document in documents
    if document.get('kind') == 'StatefulSet'
    and document.get('metadata', {}).get('name') == 'heimdall'
)
environment = statefulset['spec']['template']['spec']['containers'][0]['env']
by_name = {entry['name']: entry for entry in environment}
required = {
    'NODE_ENV', 'DATABASE_HOST', 'DATABASE_PORT', 'DATABASE_NAME',
    'DATABASE_USERNAME', 'DATABASE_PASSWORD', 'JWT_SECRET',
    'API_KEY_SECRET', 'ADMIN_PASSWORD', 'EXTERNAL_URL',
}
missing = sorted(required - by_name.keys())
if missing:
    raise SystemExit(f'Missing environment variables: {missing}')

secret_backed = {
    'DATABASE_USERNAME', 'DATABASE_PASSWORD', 'JWT_SECRET',
    'API_KEY_SECRET', 'ADMIN_PASSWORD',
}
invalid = sorted(
    name for name in secret_backed
    if by_name[name].get('valueFrom', {}).get('secretKeyRef', {}).get('name') != 'heimdall'
)
if invalid:
    raise SystemExit(f'Variables not backed by the Heimdall Secret: {invalid}')

print('Stage 3 passed')
PY
```

Clean up the Python environment:

```bash
deactivate
```

## Stage 4: schema and values validation

Run strict Helm linting:

```bash
helm lint --strict ./heimdall2 \
  --set-string jwtSecret=schema-test-jwt \
  --set-string databasePassword=schema-test-db \
  --set-string apiKeySecret=schema-test-api \
  --set-string externalUrl=http://localhost:3000
```

Validate values processing and template rendering:

```bash
helm template heimdall ./heimdall2 \
  --set-string jwtSecret=schema-test-jwt \
  --set-string databasePassword=schema-test-db \
  --set-string apiKeySecret=schema-test-api \
  --set-string externalUrl=http://localhost:3000 \
  > /dev/null
```

Both commands must exit successfully. Helm will automatically validate `values.schema.json` if one
is added to the chart in the future.

## Stage 5: Kubernetes integration

This stage installs the chart into Kubernetes and runs the chart's Helm test hook. Docker Desktop
must be running.

Create an isolated cluster matching CI's Kubernetes version:

```bash
kind create cluster \
  --name heimdall-ci-v130 \
  --image kindest/node:v1.30.0
```

Run the integration test. Local testing uses `--all` so it does not depend on Git history:

```bash
ct install \
  --config .github/ct.yaml \
  --all \
  --helm-extra-set-args \
  '--set-string jwtSecret=integration-test-jwt --set-string databasePassword=integration-test-db --set-string apiKeySecret=integration-test-api --set-string externalUrl=http://localhost:3000 --set heimdall.ingress.enabled=false'
```

Expected result: `All charts installed successfully`. Chart-testing creates and removes an isolated
namespace automatically.

Delete the temporary cluster:

```bash
kind delete cluster --name heimdall-ci-v130
```

If another local cluster was active before this test, restore its context afterward. For example:

```bash
kubectl config use-context kind-heimdall-test
```

## Stage 6: template rendering

Render the embedded PostgreSQL configuration:

```bash
helm template heimdall ./heimdall2 \
  --set-string jwtSecret=template-test-jwt \
  --set-string databasePassword=template-test-db \
  --set-string apiKeySecret=template-test-api \
  --set-string externalUrl=http://localhost:3000 \
  --set heimdall.ingress.enabled=false \
  > /tmp/heimdall-embedded.yaml
```

Render the external PostgreSQL configuration:

```bash
helm template heimdall ./heimdall2 \
  --set postgresql.enabled=false \
  --set-string databaseHost=db.example.com \
  --set databasePort=5432 \
  --set-string databaseName=heimdall_prod \
  --set-string databaseUsername=heimdall_user \
  --set-string databasePassword=template-test-db \
  --set-string jwtSecret=template-test-jwt \
  --set-string apiKeySecret=template-test-api \
  --set-string externalUrl=http://localhost:3000 \
  --set heimdall.ingress.enabled=false \
  > /tmp/heimdall-external.yaml
```

Render the ingress configuration:

```bash
helm template heimdall ./heimdall2 \
  --set-string jwtSecret=template-test-jwt \
  --set-string databasePassword=template-test-db \
  --set-string apiKeySecret=template-test-api \
  --set-string externalUrl=https://heimdall.example.com \
  --set heimdall.ingress.enabled=true \
  --set-string 'heimdall.ingress.hosts[0].host=heimdall.example.com' \
  > /tmp/heimdall-ingress.yaml
```

Check the rendered resources:

```bash
grep -q '^kind: StatefulSet$' /tmp/heimdall-embedded.yaml
grep -q 'value: "db.example.com"' /tmp/heimdall-external.yaml
grep -q '^kind: Ingress$' /tmp/heimdall-ingress.yaml
echo 'Stage 6 passed'
```

## Stage 7: runtime lifecycle scenarios

The six runtime scenarios are documented in
[`tests/lifecycle/README.md`](lifecycle/README.md). They cover:

1. Bare-minimum install, HTTP validation, and uninstall.
2. Persistent embedded PostgreSQL and data survival after a pod restart.
3. External PostgreSQL supplied through a GitHub Actions service container.
4. SOPS/age encryption and an externally managed Kubernetes Secret.
5. The external Secret contract used by a Vault integration.
6. Certificate ConfigMap injection and the UBI-based system trust store.

For a complete local run, create a Kind cluster and external PostgreSQL container:

```bash
kind create cluster --name heimdall-test
docker run --detach --rm --name heimdall-lifecycle-postgres \
  --env POSTGRES_DB=heimdall \
  --env POSTGRES_USER=postgres \
  --env POSTGRES_PASSWORD=lifecycle-postgres-password \
  --publish 15432:5432 \
  postgres:17
```

Run all scenarios through Docker Desktop and MITRE's UBI mirror:

```bash
EXTERNAL_POSTGRES_HOST=host.docker.internal \
EXTERNAL_POSTGRES_PORT=15432 \
EXTERNAL_POSTGRES_PASSWORD=lifecycle-postgres-password \
CERTS_IMAGE="<MITRE Artifactory URL>/docker/ubi8/ubi" \
CERTS_IMAGE_TAG=latest \
tests/lifecycle/run-all.sh
```

CI reads the Artifactory base URL from the GitHub Actions repository variable
`MITRE_ARTIFACTORY_URL`. If the variable is not configured, the workflow falls back to the chart's
public UBI image.

Run one or more scenarios independently with `ONLY`:

```bash
ONLY='01' tests/lifecycle/run-all.sh
ONLY='03 05' \
  EXTERNAL_POSTGRES_HOST=host.docker.internal \
  EXTERNAL_POSTGRES_PORT=15432 \
  tests/lifecycle/run-all.sh
ONLY='06' \
  CERTS_IMAGE="<MITRE Artifactory URL>/docker/ubi8/ubi" \
  tests/lifecycle/run-all.sh
```

Clean up the local resources:

```bash
docker stop heimdall-lifecycle-postgres
kind delete cluster --name heimdall-test
```

Every lifecycle script uses its own namespace and attempts to remove it on exit. Generated values,
keys, and certificates are stored under `tests/lifecycle/.generated/` and are ignored by Git.
