# Ingress, TLS, and Certificate Management Research

**Date**: 2025-12-31
**Research Scope**: Industry best practices for Helm chart ingress, TLS, and corporate CA certificates

## Executive Summary

Researched how well-established Helm charts (Bitnami, Grafana, GitLab, Vulcan) handle:
1. **Ingress abstraction** - Supporting multiple controllers (Nginx, Traefik, cloud load balancers)
2. **TLS/SSL configuration** - cert-manager integration and manual certificate support
3. **Corporate CA certificates** - Custom CA bundles for proxy/MITM environments

**Key Finding**: There is a **standardized pattern** across major charts that provides the right level of abstraction while remaining flexible for different deployment scenarios.

## 1. Ingress Configuration Best Practices

### Standard Pattern (Grafana, Vulcan, Bitnami)

All major charts follow this structure:

```yaml
ingress:
  # -- Enable ingress controller resource
  enabled: false

  # -- Ingress class name (nginx, traefik, kong, etc.)
  # For Kubernetes >= 1.18, use ingressClassName
  className: "nginx"

  # -- Custom annotations (controller-specific)
  annotations: {}
    # nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"
    # traefik.ingress.kubernetes.io/router.entrypoints: websecure

  # -- Ingress hosts with paths
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: Prefix

  # -- TLS configuration
  tls: []
    # - secretName: chart-example-tls
    #   hosts:
    #     - chart-example.local
```

**Why This Works**:
- **Controller-agnostic**: `className` + `annotations` pattern supports any ingress controller
- **Kubernetes version compatibility**: Uses `ingressClassName` for K8s 1.18+ with backward compatibility
- **Flexible**: Annotations allow controller-specific features without hardcoding
- **Multi-host support**: Array of hosts with individual path configurations

### Vulcan Reference Implementation

Vulcan's `ingress.yaml` template (see `/Users/alippold/github/mitre/vulcan-helm/vulcan/templates/ingress.yaml`):

```yaml
{{- if .Values.vulcan.ingress.enabled -}}
{{- $fullName := include "vulcan.fullname" . -}}
{{- $svcPort := .Values.vulcan.service.port -}}

# Kubernetes version compatibility (1.14+, 1.18+, 1.19+)
{{- if and .Values.vulcan.ingress.className (not (semverCompare ">=1.18-0" .Capabilities.KubeVersion.GitVersion)) }}
  # Fallback to annotation for K8s < 1.18
  {{- if not (hasKey .Values.vulcan.ingress.annotations "kubernetes.io/ingress.class") }}
  {{- $_ := set .Values.vulcan.ingress.annotations "kubernetes.io/ingress.class" .Values.vulcan.ingress.className}}
  {{- end }}
{{- end }}

apiVersion: networking.k8s.io/v1  # K8s 1.19+
kind: Ingress
metadata:
  name: {{ $fullName }}
  {{- with .Values.vulcan.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and .Values.vulcan.ingress.className (semverCompare ">=1.18-0" .Capabilities.KubeVersion.GitVersion) }}
  ingressClassName: {{ .Values.vulcan.ingress.className }}
  {{- end }}

  {{- if .Values.vulcan.ingress.tls }}
  tls:
    {{- range .Values.vulcan.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}

  rules:
    {{- range .Values.vulcan.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
          {{- end }}
    {{- end }}
{{- end }}
```

**Key Features**:
- ✅ Kubernetes version detection with `semverCompare`
- ✅ Automatic fallback to annotation for older K8s versions
- ✅ Clean iteration over hosts, paths, and TLS configurations
- ✅ No hardcoded values - all from `values.yaml`

### Controller-Specific Annotations (Examples)

**Nginx Ingress Controller**:
```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-body-size: "100m"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

**Traefik**:
```yaml
annotations:
  traefik.ingress.kubernetes.io/router.entrypoints: websecure
  traefik.ingress.kubernetes.io/router.tls: "true"
  traefik.ingress.kubernetes.io/service.sticky.cookie: "true"
```

**cert-manager (works with any controller)**:
```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
  cert-manager.io/acme-challenge-type: http01
```

## 2. TLS/SSL Configuration Best Practices

### cert-manager Integration (Recommended for Production)

**Source**: [cert-manager Best Practices](https://cert-manager.io/docs/installation/best-practice/)

**Installation**:
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

**Key Best Practices**:

1. **Security Isolation**:
   - Run cert-manager on dedicated nodes reserved for platform operators
   - Set `automountServiceAccountToken: false` and manually add projected volumes
   - Implement least-privilege network policies

2. **Resource Management**:
   - Configure `cainjector` to only watch cert-manager namespace (reduces memory)
   - Use vertical scaling for sufficient CPU resources
   - Higher CPU requirements on clusters with frequent updates

3. **Dynamic Certificate Management**:
   - Pull from Kubernetes secret created by cert-manager
   - Avoids manual copy/paste
   - Makes cert rotation seamless

**ClusterIssuer Example (Let's Encrypt)**:
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Ingress with cert-manager**:
```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: heimdall.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: heimdall-tls  # cert-manager creates this
      hosts:
        - heimdall.example.com
```

### Manual Certificate Management

**For existing certificates**:

```bash
# Create TLS secret manually
kubectl create secret tls heimdall-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n heimdall
```

**values.yaml**:
```yaml
ingress:
  enabled: true
  tls:
    - secretName: heimdall-tls  # Reference existing secret
      hosts:
        - heimdall.example.com
```

### Vulcan Production Example

From Vulcan's README (production deployment pattern):

```yaml
vulcan:
  forceSSL: true  # Enable HTTPS enforcement
  ingress:
    enabled: true
    className: "nginx"
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
      nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    hosts:
      - host: vulcan.example.com
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: vulcan-tls
        hosts:
          - vulcan.example.com
```

## 3. Corporate CA Certificates Best Practices

### The Challenge

**Source**: [Helm chart custom CA certificate challenges](https://github.com/kubernetes-sigs/external-dns/issues/3825)

**Key Issues**:
- ❌ **No standardized approach**: Each chart may or may not support custom CA bundles
- ❌ **Base image differences**: Alpine uses different paths than Ubuntu; Node.js expects different locations
- ❌ **Security risks**: Normalizes `--insecure` or `curl -k` behavior when not handled properly

**Common Use Cases**:
- Corporate MITM HTTP/HTTPS proxy
- Privately hosted DNS with custom CA
- Applications encountering "x509: certificate signed by unknown authority" errors

### Vulcan's Approach (Recommended Pattern)

**values.yaml**:
```yaml
extraCertificates:
  # -- Enable custom CA certificate injection
  enabled: false
  # -- Name of existing ConfigMap with CA certificates (.crt or .pem files)
  configMapName: ""
  # -- Or provide certificates directly (creates ConfigMap)
  certificates:
    - filename: corporate-ca.crt
      contents: |
        -----BEGIN CERTIFICATE-----
        ...
        -----END CERTIFICATE-----
```

**Implementation Options**:

1. **Existing ConfigMap** (Production):
   ```yaml
   extraCertificates:
     enabled: true
     configMapName: "corporate-ca-bundle"
   ```

2. **Inline Certificates** (Development):
   ```yaml
   extraCertificates:
     enabled: true
     certificates:
       - filename: ca.crt
         contents: |
           -----BEGIN CERTIFICATE-----
           ...
   ```

### Heimdall's Current Implementation

**Already has certificate support** but needs standardization:

```yaml
certs:
  enabled: false
  systemCertsApproach:
    enabled: false  # If true, uses init container with update-ca-trust
    image:
      repository: registry.access.redhat.com/ubi8/ubi
      tag: "latest"
    command: "['sh', '-c', 'update-ca-trust']"
    injectedCertsMountPath: /etc/pki/ca-trust/source/anchors
    processedCertsMountPaths: [...]

  name: heimdall-cacerts
  certificates:
    - filename: certs.pem
      contents: |
        replace with certificate file contents
```

**Two Approaches**:

1. **System Certs Approach** (enabled: true):
   - Uses init container with UBI8 image
   - Runs `update-ca-trust` to process certificates
   - Mounts to RHEL-style paths (`/etc/pki/ca-trust/`)

2. **Node.js Approach** (enabled: false):
   - Sets `NODE_EXTRA_CA_CERTS` environment variable
   - Sets `SSL_CERT_FILE` environment variable
   - Requires all certificates in single `.pem` file

**Issues with Current Implementation**:
- ❌ Overly complex (two different approaches)
- ❌ UBI8 image dependency (large, RHEL-specific)
- ❌ Not following standard Vulcan pattern

## 4. Comparison: Heimdall vs Best Practices

### Current Heimdall Ingress Configuration

**values.yaml** (lines 308-335):
```yaml
ingress:
  enabled: true
  apiVersion: networking.k8s.io/v1  # ❌ SHOULD NOT be in values.yaml
  kind: Ingress                      # ❌ SHOULD NOT be in values.yaml

  hosts:
    - host: localhost
      paths:
        - path: /
          pathType: Prefix
          backend:                    # ❌ Should be in template, not values
            service:
              name: heimdall
              port:
                number: 3000

# annotations:                        # ✅ Good - commented examples
#   traefik.ingress.kubernetes.io/router.entrypoints: websecure

# className: ingress class name       # ❌ Should be uncommented with default

# tls:                                # ✅ Good structure
#   - name: nginx
#     secretName: ingress-secret
#     hosts:
#       - heimdall.example.com

gateway:                              # ❓ Gateway API support (advanced)
  enabled: false
  # ... VirtualService config
```

**Issues**:

1. ❌ **apiVersion in values.yaml**: Should be in template with version detection
2. ❌ **kind in values.yaml**: Should be in template
3. ❌ **backend in values.yaml**: Template should construct this from service name/port
4. ❌ **No className**: Missing the standard `className` field
5. ❌ **No annotations**: Should have empty `annotations: {}` by default
6. ✅ **TLS structure**: Correct (but commented)
7. ❓ **Gateway API**: Advanced feature (Istio VirtualService) - should be separate epic

### Recommended Changes

**Phase 4: Ingress Epic Should Implement**:

1. **Standardize values.yaml structure**:
   ```yaml
   ingress:
     enabled: false  # Disabled by default (like Vulcan)
     className: "nginx"
     annotations: {}
     hosts:
       - host: heimdall.local
         paths:
           - path: /
             pathType: Prefix
     tls: []
   ```

2. **Create/update ingress.yaml template** (following Vulcan pattern):
   - Remove `apiVersion`, `kind`, `backend` from values.yaml
   - Add Kubernetes version detection (`semverCompare`)
   - Use template helpers for service name/port
   - Support K8s 1.14+ (backward compatibility)

3. **Document common scenarios** (like Vulcan README):
   - Local development (HTTP, no ingress)
   - Production Nginx (HTTPS, cert-manager)
   - Production Traefik (HTTPS, Let's Encrypt)
   - Cloud load balancers (AWS ALB, GCP)

## 5. Critical Timeline: NGINX Ingress Controller Retirement

**Source**: [Traefik Migration Guide](https://traefik.io/blog/migrate-from-ingress-nginx-to-traefik-now)

### The Deadline

**November 12, 2025**: Maintainers announced:
- ⚠️ **Ingress NGINX Controller will be retired in March 2026**
- ❌ After March 2026: No releases, no bug fixes, **no security updates**
- ⏰ Organizations have **~4 months** to migrate (as of 2025-12-31)

### Traefik as Drop-in Replacement

**Why Traefik**:
- ✅ Native support for `nginx.ingress.kubernetes.io` annotations
- ✅ Only drop-in replacement in the industry
- ✅ Most commonly used Nginx annotations handled natively
- ✅ Ingress objects work **unchanged**

**Migration Strategy**:
1. **New Deployments**: Start with Traefik
2. **Existing Clusters**: Progressive migration
   - Deploy new clusters with Traefik
   - Gradually transition workloads

### Impact on Heimdall Chart

**Recommendation**:
- ✅ Keep controller-agnostic design (className + annotations)
- ✅ Document both Nginx and Traefik in examples
- ✅ Add Traefik-specific annotation examples
- ⚠️ Warn users about March 2026 Nginx retirement in docs
- ✅ Default to `className: "nginx"` now, but make easy to switch

**Example Values for Both Controllers**:

```yaml
# Nginx (current default, deprecated March 2026)
ingress:
  enabled: true
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"

# Traefik (recommended for new deployments)
ingress:
  enabled: true
  className: "traefik"
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## 6. Recommendations

### Phase 4: Ingress (P1 Epic - heimdall-helm-opy)

**Scope**:
1. ✅ Refactor ingress values.yaml to match industry standard
2. ✅ Create/update ingress.yaml template (borrow from Vulcan)
3. ✅ Add Kubernetes version detection (1.14+, 1.18+, 1.19+)
4. ✅ Document common scenarios (Nginx, Traefik, cloud LBs)
5. ✅ Add migration warning for Nginx retirement
6. ❌ **NOT in scope**: Gateway API (defer to Phase 7 or separate epic)

**Estimated Effort**: 4-6 hours
- Research complete (this document)
- Template exists in Vulcan (copy/adapt)
- Testing with local kind cluster

### Phase 5: TLS/SSL (P1 Epic - heimdall-helm-xta)

**Scope**:
1. ✅ Document cert-manager integration (ClusterIssuer examples)
2. ✅ Document manual certificate workflow
3. ✅ Add TLS examples to NOTES.txt
4. ✅ Test with Let's Encrypt staging
5. ✅ Document forceSSL equivalent for Heimdall (if applicable)

**Estimated Effort**: 3-4 hours
- cert-manager is standard (well-documented)
- NOTES.txt updates minor

### Custom CA Certificates (Phase 6 or Separate Epic?)

**Recommendation**: **Simplify and standardize**

Current Heimdall implementation is overly complex. Follow Vulcan pattern:

**Proposed values.yaml**:
```yaml
heimdall:
  # Custom CA Certificates (for corporate proxies, internal APIs)
  extraCertificates:
    enabled: false
    # Option 1: Reference existing ConfigMap
    configMapName: ""
    # Option 2: Provide certificates inline
    certificates: []
      # - filename: corporate-ca.crt
      #   contents: |
      #     -----BEGIN CERTIFICATE-----
```

**Implementation**:
- Use `NODE_EXTRA_CA_CERTS` environment variable (Node.js native)
- No init container required (simpler)
- ConfigMap mounted as volume
- Set `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt`

**Remove**:
- ❌ `certs.systemCertsApproach` (too complex, UBI8 dependency)
- ❌ `update-ca-trust` approach (RHEL-specific)

**Estimated Effort**: 2-3 hours
- Remove old implementation
- Copy Vulcan pattern
- Test with corporate CA

## 7. Sources

### Research Sources

**Ingress Best Practices**:
- [Bitnami NGINX Ingress Controller](https://github.com/bitnami/charts/blob/main/bitnami/nginx-ingress-controller/README.md)
- [Grafana Helm Chart Values](https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml)
- [GitLab Helm Chart Ingress Configuration](https://docs.gitlab.com/charts/charts/globals/)
- [Traefik Migration from NGINX](https://traefik.io/blog/migrate-from-ingress-nginx-to-traefik-now)

**TLS/SSL and cert-manager**:
- [cert-manager Best Practices](https://cert-manager.io/docs/installation/best-practice/)
- [cert-manager Helm Installation](https://cert-manager.io/docs/installation/helm/)
- [GitLab TLS Configuration](https://docs.gitlab.com/charts/installation/tls/)

**Custom CA Certificates**:
- [Custom CA Bundle Support Discussion](https://github.com/kubernetes-sigs/external-dns/issues/3825)
- [HashiCorp Vault Custom Certificate](https://discuss.hashicorp.com/t/add-custom-certificate-to-helm-chart-instalation/49035)
- [Stop Breaking TLS](https://www.markround.com/blog/2025/12/09/stop-breaking-tls/)

**Reference Implementation**:
- Vulcan Helm Chart: `/Users/alippold/github/mitre/vulcan-helm/vulcan/`

## 8. Next Steps

1. **Review this document** with stakeholder
2. **Update Phase 4 epic** (heimdall-helm-opy) with specific tasks
3. **Begin implementation**:
   - Start with ingress.yaml template (copy from Vulcan)
   - Update values.yaml structure
   - Test with kind cluster (Nginx + Traefik)
4. **Document examples** in chart README
5. **Update NOTES.txt** with ingress/TLS instructions
