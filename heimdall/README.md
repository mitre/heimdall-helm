# heimdall

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: release-latest](https://img.shields.io/badge/AppVersion-release--latest-informational?style=flat-square)

Heimdall is a security results visualization tool that lets you view, store, and compare security scan results.

**Homepage:** <https://github.com/mitre/heimdall-helm>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| MITRE SAF | <saf@mitre.org> |  |

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | postgresql | ~18.2.0 |

## Quick Start

### Prerequisites

- Kubernetes 1.28+
- Helm 3.x or 4.x
- PostgreSQL 16+ (embedded via Bitnami subchart or external)

### Installation

```bash
# Add MITRE Helm repository
helm repo add mitre https://mitre.github.io/heimdall-helm
helm repo update

# Install with default values (embedded PostgreSQL)
helm install heimdall mitre/heimdall -n heimdall --create-namespace

# Install with external database
helm install heimdall mitre/heimdall -n heimdall --create-namespace \
  --set postgresql.enabled=false \
  --set externalDatabase.host=db.example.com \
  --set externalDatabase.database=heimdall_production \
  --set externalDatabase.username=heimdall_user \
  --set externalDatabase.password=secure_password
```

### Accessing Heimdall

```bash
# Port forward for local access
kubectl port-forward -n heimdall svc/heimdall 3000:3000

# Visit http://localhost:3000
```

## Configuration Examples

### Enable Ingress with TLS

```yaml
heimdall:
  ingress:
    enabled: true
    className: traefik
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
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

### External Database

```yaml
postgresql:
  enabled: false

externalDatabase:
  host: db.example.com
  port: 5432
  database: heimdall_production
  username: heimdall_user
  password: secure_password
```

### Custom CA Certificates

```yaml
extraCertificates:
  enabled: true
  certificates:
    corporate-ca.crt: |
      -----BEGIN CERTIFICATE-----
      ... your CA certificate ...
      -----END CERTIFICATE-----
```

### High Availability

```yaml
heimdall:
  replicaCount: 3
 
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
 
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

## Documentation

For comprehensive documentation, see:
- **Getting Started**: https://mitre.github.io/heimdall-helm/getting-started
- **Configuration Guide**: https://mitre.github.io/heimdall-helm/helm-chart/configuration
- **Ingress & TLS**: https://mitre.github.io/heimdall-helm/helm-chart/ingress-tls
- **High Availability**: https://mitre.github.io/heimdall-helm/helm-chart/high-availability

## Testing

```bash
# Lint the chart
helm lint ./heimdall --strict

# Unit tests (requires helm-unittest plugin)
helm unittest ./heimdall

# Install and test
helm install heimdall ./heimdall -n heimdall-test --create-namespace
helm test heimdall -n heimdall-test
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| databaseName | string | `"heimdall-database"` |  |
| databaseUsername | string | `"postgres"` |  |
| externalDatabase.database | string | `"heimdall"` | External database name |
| externalDatabase.existingSecret | string | `""` | Existing secret containing database password Secret must have key matching existingSecretPasswordKey |
| externalDatabase.existingSecretPasswordKey | string | `"password"` | Key in existingSecret that contains the password |
| externalDatabase.host | string | `""` | External PostgreSQL hostname (e.g., heimdall-db.abc123.us-east-1.rds.amazonaws.com) |
| externalDatabase.port | int | `5432` | External PostgreSQL port |
| externalDatabase.username | string | `"postgres"` | External database username |
| extraCertificates.certificates | object | `{}` | Or provide certificates directly (chart will create ConfigMap) Supports multiple certificates with any filename (.crt or .pem extensions) All certificates will be automatically concatenated into ca-bundle.pem |
| extraCertificates.configMapName | string | `""` | Name of existing ConfigMap containing CA certificates (.crt or .pem files) The ConfigMap should be created in the same namespace as Heimdall Example: kubectl create configmap custom-ca-certs --from-file=mitre-ca.crt -n heimdall All certificates will be concatenated into a single bundle file at runtime |
| extraCertificates.enabled | bool | `false` | Enable custom CA certificate injection |
| heimdall.affinity | object | `{}` |  |
| heimdall.autoscaling.enabled | bool | `false` |  |
| heimdall.autoscaling.maxReplicas | int | `3` |  |
| heimdall.autoscaling.minReplicas | int | `1` |  |
| heimdall.autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| heimdall.config | object | `{}` |  |
| heimdall.configmap.name | string | `"heimdall-config"` |  |
| heimdall.existingSecret | string | `""` |  |
| heimdall.gateway.enabled | bool | `false` |  |
| heimdall.image.pullPolicy | string | `"IfNotPresent"` |  |
| heimdall.image.repository | string | `"mitre/heimdall2"` |  |
| heimdall.image.tag | string | `"release-latest"` |  |
| heimdall.imagePullSecrets | list | `[]` |  |
| heimdall.ingress.annotations | object | `{}` | Custom annotations (controller-specific) |
| heimdall.ingress.className | string | `"traefik"` | Ingress class name (traefik, nginx, kong, etc.) Traefik is the recommended default (Nginx will be retired March 2026) |
| heimdall.ingress.enabled | bool | `false` | Enable ingress controller resource (disabled by default, enable for production) |
| heimdall.ingress.hosts | list | `[{"host":"heimdall.local","paths":[{"path":"/","pathType":"Prefix"}]}]` | Ingress hosts with paths |
| heimdall.ingress.tls | list | `[]` | TLS configuration for ingress |
| heimdall.livenessProbe.failureThreshold | int | `3` |  |
| heimdall.livenessProbe.httpGet.path | string | `"/"` |  |
| heimdall.livenessProbe.httpGet.port | int | `3000` |  |
| heimdall.livenessProbe.initialDelaySeconds | int | `0` |  |
| heimdall.livenessProbe.periodSeconds | int | `10` |  |
| heimdall.livenessProbe.timeoutSeconds | int | `5` |  |
| heimdall.networkPolicy.egress | object | `{"extraRules":[]}` | Egress rules - Allow traffic FROM Heimdall pods |
| heimdall.networkPolicy.egress.extraRules | list | `[]` | Additional egress rules beyond DNS and PostgreSQL DNS and PostgreSQL are allowed by default Example - Allow HTTPS to external services: extraRules:   - to:       - podSelector: {}     ports:       - protocol: TCP         port: 443 |
| heimdall.networkPolicy.enabled | bool | `false` | Enable NetworkPolicy (disabled by default for backwards compatibility) |
| heimdall.networkPolicy.ingress | object | `{"enabled":true,"namespaceSelector":{},"podSelector":{}}` | Ingress rules - Allow traffic TO Heimdall pods |
| heimdall.networkPolicy.ingress.enabled | bool | `true` | Enable ingress rules |
| heimdall.networkPolicy.ingress.namespaceSelector | object | `{}` | Allow traffic from specific namespace (e.g., ingress-nginx) Example for nginx-ingress: namespaceSelector:   matchLabels:     name: ingress-nginx |
| heimdall.networkPolicy.ingress.podSelector | object | `{}` | Allow traffic from specific pods Example: podSelector:   matchLabels:     app: nginx-ingress |
| heimdall.nodeSelector | object | `{}` |  |
| heimdall.podAnnotations | object | `{}` |  |
| heimdall.podDisruptionBudget.enabled | bool | `false` |  |
| heimdall.podDisruptionBudget.minAvailable | int | `1` |  |
| heimdall.podSecurityContext | object | `{}` |  |
| heimdall.readinessProbe.failureThreshold | int | `3` |  |
| heimdall.readinessProbe.httpGet.path | string | `"/"` |  |
| heimdall.readinessProbe.httpGet.port | int | `3000` |  |
| heimdall.readinessProbe.initialDelaySeconds | int | `0` |  |
| heimdall.readinessProbe.periodSeconds | int | `10` |  |
| heimdall.readinessProbe.timeoutSeconds | int | `5` |  |
| heimdall.resources | object | `{}` |  |
| heimdall.secret.name | string | `"heimdall-secrets"` |  |
| heimdall.secrets | object | `{}` |  |
| heimdall.secretsFiles[0] | string | `"env/heimdall-secrets.yaml"` |  |
| heimdall.securityContext | object | `{}` |  |
| heimdall.service.port | int | `3000` |  |
| heimdall.service.type | string | `"ClusterIP"` |  |
| heimdall.serviceAccount.annotations | object | `{}` |  |
| heimdall.serviceAccount.create | bool | `true` |  |
| heimdall.serviceAccount.name | string | `""` |  |
| heimdall.startupProbe.enabled | bool | `true` |  |
| heimdall.startupProbe.failureThreshold | int | `36` |  |
| heimdall.startupProbe.httpGet.path | string | `"/"` |  |
| heimdall.startupProbe.httpGet.port | int | `3000` |  |
| heimdall.startupProbe.initialDelaySeconds | int | `10` |  |
| heimdall.startupProbe.periodSeconds | int | `10` |  |
| heimdall.startupProbe.timeoutSeconds | int | `5` |  |
| heimdall.tolerations | list | `[]` |  |
| nodeEnv | string | `"production"` |  |
| postgresql.auth.database | string | `"heimdall"` | PostgreSQL database name |
| postgresql.auth.password | string | `""` | PostgreSQL password (leave empty for auto-generated, recommended) To retrieve auto-generated password: kubectl get secret -n <namespace> <release>-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d Note: Do NOT use existingSecret - it has known issues with Bitnami chart |
| postgresql.auth.username | string | `"postgres"` | PostgreSQL username (default: postgres) |
| postgresql.enabled | bool | `true` | Deploy PostgreSQL using Bitnami subchart (set false to use external database) |
| postgresql.image.tag | string | `"latest"` | PostgreSQL image tag (Bitnami uses 'latest' for free tier) |
| postgresql.primary.persistence.enabled | bool | `true` | Enable persistent storage for PostgreSQL data |
| postgresql.primary.persistence.size | string | `"10Gi"` | Size of persistent volume claim |
| postgresql.primary.persistence.storageClass | string | `""` | Storage class for PVC (leave empty for default) |
| postgresql.primary.resources.limits.cpu | string | `"200m"` |  |
| postgresql.primary.resources.limits.memory | string | `"256Mi"` |  |
| postgresql.primary.resources.requests.cpu | string | `"100m"` |  |
| postgresql.primary.resources.requests.memory | string | `"128Mi"` |  |
| postgresql.primary.service.ports | object | `{"postgresql":5432}` | PostgreSQL service port |
| sops.enabled | bool | `false` |  |
| sops.secrets | list | `[]` |  |

## License

Apache 2.0 - See LICENSE.md for details

---

Generated with [helm-docs](https://github.com/norwoodj/helm-docs)
