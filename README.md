# Heimdall Helm Chart

[![Test Helm Chart](https://github.com/mitre/heimdall-helm/actions/workflows/test.yml/badge.svg)](https://github.com/mitre/heimdall-helm/actions/workflows/test.yml)

A Helm chart for deploying the [MITRE SAF Heimdall](https://github.com/mitre/heimdall2) security results visualization application to Kubernetes.

**Chart Version**: 1.0.0
**App Version**: release-latest
**Kubernetes**: 1.28+ (tested on 1.28, 1.29, 1.30)
**Helm**: 3.14+

## Quick Start

### Install from Helm Repository

```bash
# Add the Heimdall Helm repository
helm repo add heimdall https://mitre.github.io/heimdall-helm/
helm repo update

# Search for available versions
helm search repo heimdall

# Install with default values (embedded PostgreSQL)
helm install heimdall heimdall/heimdall \
  --namespace heimdall \
  --create-namespace

# Watch pods starting up
kubectl get pods -n heimdall -w
```

**Note**: Heimdall takes 2-3 minutes to start fully as it runs database migrations and builds the frontend.

### Install from Source

```bash
# Clone the repository
git clone https://github.com/mitre/heimdall-helm.git
cd heimdall-helm

# Generate secrets (required)
./generate-heimdall-secrets.sh

# Install the chart
helm install heimdall ./heimdall \
  --namespace heimdall \
  --create-namespace \
  --values heimdall/env/heimdall-secrets.yaml

# Check deployment status
kubectl get pods -n heimdall -w
```

## Accessing Heimdall

### Port Forward (Development/Testing)

```bash
kubectl port-forward -n heimdall service/heimdall 3000:3000
```

Then open [http://localhost:3000](http://localhost:3000) in your browser.

### Ingress (Production)

Configure ingress in your `values.yaml`:

```yaml
heimdall:
  ingress:
    enabled: true
    className: nginx  # or traefik, etc.
    hosts:
      - host: heimdall.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: heimdall-tls
        hosts:
          - heimdall.example.com
```

Apply the configuration:

```bash
helm upgrade heimdall ./heimdall \
  --namespace heimdall \
  --values values.yaml
```

See [Ingress Documentation](docs/content/4.helm-chart/8.ingress.md) for detailed configuration options.

## Configuration

### Secrets Management

This chart provides three approaches for managing secrets (in priority order):

1. **Existing Secret** (Production - Recommended)
   ```yaml
   heimdall:
     existingSecret: heimdall-secrets  # Managed externally
   ```

2. **File-Based Secrets** (Development)
   ```bash
   ./generate-heimdall-secrets.sh  # Creates heimdall/env/heimdall-secrets.yaml
   helm install heimdall ./heimdall --values heimdall/env/heimdall-secrets.yaml
   ```

3. **Inline Secrets** (CI/CD)
   ```bash
   helm install heimdall ./heimdall \
     --set heimdall.secrets.JWT_SECRET="$(openssl rand -hex 64)" \
     --set heimdall.secrets.DATABASE_PASSWORD="$(openssl rand -hex 33)"
   ```

**Required Secrets:**
- `JWT_SECRET` - Session token signing (128+ chars recommended)
- `DATABASE_PASSWORD` - PostgreSQL password
- `ADMIN_PASSWORD` - Initial admin user password

See [Secrets Documentation](docs/content/4.helm-chart/2.secrets.md) for complete details.

### Database Options

#### Embedded PostgreSQL (Default)

Uses Bitnami PostgreSQL subchart - production-ready with built-in HA support:

```yaml
postgresql:
  enabled: true
  auth:
    database: heimdall
    username: postgres
```

#### External Database

```yaml
postgresql:
  enabled: false

externalDatabase:
  host: postgres.example.com
  port: 5432
  database: heimdall_production
  username: heimdall_app
  # Password from secrets
```

See [Database Documentation](docs/content/4.helm-chart/6.database.md) for HA configurations and backup strategies.

### Values Schema Validation

This chart includes JSON Schema validation (`values.schema.json`) that validates 95+ configuration parameters:

```bash
# This will be rejected:
helm install heimdall ./heimdall --set nodeEnv=invalid
# Error: value must be one of 'production', 'development', 'test'
```

See [Values Schema Documentation](docs/content/4.helm-chart/4.values-schema.md).

## Example Scripts

### Quick Install Script

The `start-heimdall.sh` script demonstrates installation with generated secrets:

```bash
./start-heimdall.sh
```

**Note**: This script uses legacy parameter names. For new deployments, use `generate-heimdall-secrets.sh` instead.

### Secret Generation

Generate random secrets for production use:

```bash
# JWT secret (128 characters)
openssl rand -hex 64

# Database password (66 characters)
openssl rand -hex 33

# API key secret (66 characters)
openssl rand -hex 33
```

Or use the provided script:

```bash
./generate-heimdall-secrets.sh
# Creates: heimdall/env/heimdall-secrets.yaml (gitignored)
```

## Advanced Configuration

### SOPS Encrypted Secrets

The chart supports SOPS for encrypted secrets management:

1. Install [SOPS](https://github.com/getsops/sops) and [Kustomize](https://github.com/kubernetes-sigs/kustomize)

2. Create SOPS config (AWS KMS example):

   ```yaml
   # .sops.yaml
   creation_rules:
     - path_regex: ./sops/.*
       kms: arn:aws:kms:us-east-1:123456789:key/your-kms-key-id
   ```

3. Create encrypted secrets:

   ```bash
   sops sops/secrets/heimdall-secrets.enc.yaml
   ```

4. Modify `sops/secrets-generator.yml` to match your Secret name and namespace

5. Deploy with Kustomize:

   ```bash
   kustomize build sops/ | kubectl apply -f -
   ```

**Important**: The SOPS-generated Secret must have the same name as the Helm release (default: `heimdall`) and be in the same namespace.

### Custom CA Certificates

For environments with custom certificate authorities:

```yaml
extraCertificates:
  enabled: true
  certificates:
    - |
      -----BEGIN CERTIFICATE-----
      your-ca-certificate-here
      -----END CERTIFICATE-----
```

See [Custom CA Certificates Documentation](docs/content/4.helm-chart/10.custom-ca-certificates.md).

### OAuth/OIDC Authentication

Configure external authentication providers:

```yaml
heimdall:
  config:
    OAUTH_GITHUB_CLIENT_ID: "your-client-id"
    # Add secrets to heimdall.secrets:
  secrets:
    OAUTH_GITHUB_CLIENT_SECRET: "your-client-secret"
```

Supported providers: GitHub, GitLab, Google, Okta OIDC, LDAP

See [Configuration Documentation](docs/content/4.helm-chart/3.configuration.md) for all available options.

## Testing

This chart includes comprehensive testing:

- **Unit Tests**: 92 tests with helm-unittest (100% template coverage)
- **Schema Validation**: values.schema.json enforcement
- **Integration Tests**: chart-testing with KIND (K8s 1.28/1.29/1.30)
- **Template Validation**: Embedded/external DB, ingress scenarios

### Run Tests Locally

```bash
# Install helm-unittest
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run unit tests
helm unittest ./heimdall

# Lint chart
helm lint ./heimdall --strict

# Template validation
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -
```

See [Testing Documentation](docs/content/4.helm-chart/12.testing.md) for complete testing guide.

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[Getting Started](docs/content/4.helm-chart/1.index.md)** - Chart overview and quick start
- **[Secrets Management](docs/content/4.helm-chart/2.secrets.md)** - Three secrets approaches
- **[Configuration](docs/content/4.helm-chart/3.configuration.md)** - Complete configuration reference
- **[Database](docs/content/4.helm-chart/6.database.md)** - Embedded vs external, HA setup
- **[Ingress & TLS](docs/content/4.helm-chart/8.ingress.md)** - Ingress controllers, TLS, cert-manager
- **[Health & Availability](docs/content/4.helm-chart/11.health-and-availability.md)** - Probes, HPA, PDB
- **[Testing](docs/content/4.helm-chart/12.testing.md)** - Unit, integration, E2E testing
- **[Architecture](docs/content/4.helm-chart/7.architecture.md)** - Design decisions and patterns

Or view online: [https://mitre.github.io/heimdall-helm/](https://mitre.github.io/heimdall-helm/)

## Requirements

- Kubernetes 1.28+
- Helm 3.14+
- PersistentVolume provisioner (if using embedded PostgreSQL with persistence)

## Upgrading

### From v0.x to v1.0.0

**Breaking Changes:**
- Chart name changed: `heimdall2` → `heimdall`
- Directory renamed: `heimdall2/` → `heimdall/`
- Secrets structure modernized (three-approach pattern)
- Bitnami PostgreSQL subchart (replaces standalone PostgreSQL)

See [CHANGELOG.md](CHANGELOG.md) for migration guide.

## Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

See [LICENSE.md](LICENSE.md)

## Maintainers

- **MITRE SAF Team** - <saf@mitre.org>
- **Michael Joseph Walsh** - <mjwalsh@nemonik.com>

## Support

- **Issues**: [GitHub Issues](https://github.com/mitre/heimdall-helm/issues)
- **Discussions**: [GitHub Discussions](https://github.com/mitre/heimdall-helm/discussions)
- **MITRE SAF Resources**: [https://saf.mitre.org](https://saf.mitre.org)
