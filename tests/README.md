# Chart tests

End-to-end scenarios that install the chart into a disposable Kubernetes cluster and check it works.
Each script is standalone and cleans up its own namespace.

| Script | Scenario |
|---|---|
| `01-minimal.sh` | Bare-minimum values; install, verify HTTP 200, uninstall leaves nothing |
| `02-local-postgres.sh` | In-cluster postgres with a PVC; data survives a pod restart |
| `03-ghcr-postgres.sh` | Postgres image from ghcr.io (`GHCR_PG_IMAGE` / `GHCR_PG_TAG` to override) |
| `04-sops.sh` | Secrets encrypted with SOPS (age key), consumed via `sops.enabled=true` |
| `05-certs.sh` | Custom CA certs ConfigMap, single-file and system-certs approaches |

## Requirements

`helm`, `kubectl`, `openssl`, `curl`, `sops`, `age` (for `age-keygen`), and a disposable cluster such as
[kind](https://kind.sigs.k8s.io/) (`kustomize` only for the known-issue checks). The current kubectl
context must be `kind-*` or `k3d-*`, or set `ALLOW_ANY_CONTEXT=1`.

## Run

```bash
kind create cluster --name heimdall-test
tests/run-all.sh                      # everything
ONLY="01 04" tests/run-all.sh         # selected scenarios
RUN_KNOWN_ISSUES=1 tests/run-all.sh   # also assert documented known issues
kind delete cluster --name heimdall-test
```

Options: `STORAGE_CLASS` (default `standard`, kind's class), `WAIT_TIMEOUT` (default `300s`).

Generated keys, certs and secrets are written to `tests/.generated/` (gitignored). A full run takes about 10 minutes.
