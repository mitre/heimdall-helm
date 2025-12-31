# Heimdall Ingress Configuration: Current vs Best Practices

Quick visual comparison of what needs to change.

## Current Heimdall (values.yaml lines 308-335)

```yaml
ingress:
  enabled: true
  apiVersion: networking.k8s.io/v1    # ❌ WRONG: Should be in template
  kind: Ingress                        # ❌ WRONG: Should be in template

  hosts:
    - host: localhost
      paths:
        - path: /
          pathType: Prefix
          backend:                      # ❌ WRONG: Should be in template
            service:
              name: heimdall
              port:
                number: 3000

#     annotations:                      # ⚠️ Should be uncommented
#       traefik.ingress.kubernetes.io/router.entrypoints: websecure

#     className: ingress class name     # ❌ WRONG: Should have real default

#     tls:
#       - name: nginx                   # ❌ WRONG: 'name' field doesn't exist
#         secretName: ingress-secret
#         hosts:
#           - heimdall.example.com
```

**Problems**:
1. ❌ `apiVersion` and `kind` belong in **template**, not values
2. ❌ `backend` structure belongs in **template**, not values
3. ❌ No `className` field (standard since K8s 1.18)
4. ❌ No `annotations` field (should be empty dict by default)
5. ❌ TLS has invalid `name` field
6. ❌ Enabled by default (should be disabled like other charts)

---

## Best Practice (Vulcan/Grafana/Bitnami Pattern)

### values.yaml

```yaml
ingress:
  # -- Enable ingress controller resource
  enabled: false                      # ✅ Disabled by default

  # -- Ingress class name (nginx, traefik, kong, etc.)
  className: "nginx"                  # ✅ Standard field

  # -- Custom annotations (controller-specific)
  annotations: {}                     # ✅ Empty by default
    # nginx.ingress.kubernetes.io/proxy-body-size: "100m"
    # cert-manager.io/cluster-issuer: "letsencrypt-prod"

  # -- Ingress hosts with paths
  hosts:
    - host: heimdall.local            # ✅ Example domain
      paths:
        - path: /
          pathType: Prefix

  # -- TLS configuration
  tls: []                             # ✅ Empty array by default
    # - secretName: heimdall-tls
    #   hosts:
    #     - heimdall.example.com
```

**Why This Works**:
- ✅ Controller-agnostic (works with any ingress controller)
- ✅ Clean separation: values = configuration, templates = Kubernetes resources
- ✅ Kubernetes version compatibility built into template
- ✅ Flexible annotations for any controller

### templates/ingress.yaml (from Vulcan)

```yaml
{{- if .Values.heimdall.ingress.enabled -}}
{{- $fullName := include "heimdall.fullname" . -}}
{{- $svcPort := .Values.heimdall.service.port -}}

# Backward compatibility for K8s < 1.18 (use annotation instead of className)
{{- if and .Values.heimdall.ingress.className (not (semverCompare ">=1.18-0" .Capabilities.KubeVersion.GitVersion)) }}
  {{- if not (hasKey .Values.heimdall.ingress.annotations "kubernetes.io/ingress.class") }}
  {{- $_ := set .Values.heimdall.ingress.annotations "kubernetes.io/ingress.class" .Values.heimdall.ingress.className}}
  {{- end }}
{{- end }}

# Kubernetes version detection
{{- if semverCompare ">=1.19-0" .Capabilities.KubeVersion.GitVersion -}}
apiVersion: networking.k8s.io/v1
{{- else if semverCompare ">=1.14-0" .Capabilities.KubeVersion.GitVersion -}}
apiVersion: networking.k8s.io/v1beta1
{{- else -}}
apiVersion: extensions/v1beta1
{{- end }}
kind: Ingress
metadata:
  name: {{ $fullName }}
  labels:
    {{- include "heimdall.labels" . | nindent 4 }}
  {{- with .Values.heimdall.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if and .Values.heimdall.ingress.className (semverCompare ">=1.18-0" .Capabilities.KubeVersion.GitVersion) }}
  ingressClassName: {{ .Values.heimdall.ingress.className }}
  {{- end }}

  {{- if .Values.heimdall.ingress.tls }}
  tls:
    {{- range .Values.heimdall.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}

  rules:
    {{- range .Values.heimdall.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            {{- if and .pathType (semverCompare ">=1.18-0" $.Capabilities.KubeVersion.GitVersion) }}
            pathType: {{ .pathType }}
            {{- end }}
            backend:
              {{- if semverCompare ">=1.19-0" $.Capabilities.KubeVersion.GitVersion }}
              service:
                name: {{ $fullName }}
                port:
                  number: {{ $svcPort }}
              {{- else }}
              serviceName: {{ $fullName }}
              servicePort: {{ $svcPort }}
              {{- end }}
          {{- end }}
    {{- end }}
{{- end }}
```

**Template Features**:
- ✅ Kubernetes version detection (supports 1.14, 1.18, 1.19+)
- ✅ Automatic className → annotation fallback for old K8s
- ✅ Dynamic service name/port (no hardcoding)
- ✅ Clean iteration over hosts, paths, TLS
- ✅ Only renders if `enabled: true`

---

## Side-by-Side: Common Scenarios

### Local Development (HTTP, port-forward)

**Current Heimdall** ❌:
```yaml
ingress:
  enabled: true  # ❌ Enabled but shouldn't be for local dev
  hosts:
    - host: localhost
```

**Best Practice** ✅:
```yaml
ingress:
  enabled: false  # ✅ Disabled for local (use port-forward)
```

### Production Nginx + cert-manager

**Current Heimdall** ❌:
```yaml
ingress:
  enabled: true
  # className: ???  # ❌ Missing
  hosts:
    - host: heimdall.example.com
  # tls: ???  # ❌ Commented out, invalid structure
```

**Best Practice** ✅:
```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
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

### Production Traefik (Nginx alternative after March 2026)

**Current Heimdall** ❌:
```yaml
# annotations:  # ❌ Commented examples won't help users
#   traefik.ingress.kubernetes.io/router.entrypoints: websecure
```

**Best Practice** ✅:
```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
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

---

## What Needs to Change (Phase 4 Tasks)

### 1. Update `heimdall/values.yaml` (lines 308-335)

**Remove**:
```yaml
apiVersion: networking.k8s.io/v1  # ❌ Delete
kind: Ingress                      # ❌ Delete
backend: { ... }                   # ❌ Delete (template will construct)
```

**Add**:
```yaml
className: "nginx"                 # ✅ Add
annotations: {}                    # ✅ Add
```

**Fix**:
```yaml
enabled: true  →  enabled: false   # ✅ Change default
host: localhost  →  host: heimdall.local  # ✅ Better example

tls:
  - name: nginx  # ❌ Remove 'name' field (doesn't exist)
    secretName: ...
  →
tls:
  - secretName: heimdall-tls  # ✅ Correct structure
    hosts:
      - heimdall.example.com
```

### 2. Create/Update `heimdall/templates/ingress.yaml`

**Action**: Copy Vulcan's `ingress.yaml` template and adapt:
- Change `{{ include "vulcan.fullname" . }}` → `{{ include "heimdall.fullname" . }}`
- Change `.Values.vulcan.` → `.Values.heimdall.`
- Keep all Kubernetes version detection logic
- Keep all semverCompare conditions

**Source**: `/Users/alippold/github/mitre/vulcan-helm/vulcan/templates/ingress.yaml`

### 3. Document Common Scenarios (README or docs/)

Add examples for:
- ✅ Local development (ingress disabled)
- ✅ Nginx + cert-manager (Let's Encrypt)
- ✅ Traefik (Nginx alternative)
- ✅ Manual TLS certificates
- ✅ Cloud load balancers (AWS ALB, GCP, Azure)

### 4. Update NOTES.txt

Add ingress access instructions (already has service type conditionals):

```yaml
{{- if .Values.heimdall.ingress.enabled }}
2. Access Heimdall via Ingress:
{{- range $host := .Values.heimdall.ingress.hosts }}
     http{{ if $.Values.heimdall.ingress.tls }}s{{ end }}://{{ $host.host }}
{{- end }}
{{- else if contains "NodePort" .Values.heimdall.service.type }}
  ... existing NodePort instructions ...
```

---

## Estimated Effort

**Phase 4: Ingress (P1 Epic)**:
- Research: ✅ Complete (this document)
- Update values.yaml: 1 hour
- Create/update ingress.yaml template: 1-2 hours (copy from Vulcan)
- Testing (kind cluster, Nginx + Traefik): 1-2 hours
- Documentation (README, examples): 1 hour
- Update NOTES.txt: 0.5 hour

**Total**: 4-6 hours

---

## Testing Plan

1. **Local kind cluster** (Nginx Ingress Controller):
   ```bash
   kind create cluster --name heimdall-ingress-test
   kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
   ```

2. **Install chart with ingress enabled**:
   ```bash
   helm install heimdall ./heimdall -n heimdall --create-namespace \
     --set heimdall.ingress.enabled=true \
     --set heimdall.ingress.className=nginx \
     --set heimdall.ingress.hosts[0].host=heimdall.local
   ```

3. **Verify ingress created**:
   ```bash
   kubectl get ingress -n heimdall
   kubectl describe ingress heimdall -n heimdall
   ```

4. **Test with port-forward to ingress controller**:
   ```bash
   kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80
   curl -H "Host: heimdall.local" http://localhost:8080
   ```

5. **Repeat with Traefik**:
   ```bash
   helm install traefik traefik/traefik -n traefik --create-namespace
   helm upgrade heimdall ./heimdall -n heimdall \
     --set heimdall.ingress.className=traefik
   ```

6. **Test cert-manager integration** (staging):
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   # Create staging ClusterIssuer
   # Update chart with cert-manager annotation
   # Verify certificate creation
   ```

---

## Key Takeaways

1. **Current implementation mixes concerns**: values.yaml has template logic (`apiVersion`, `kind`, `backend`)
2. **Missing standard fields**: `className` and `annotations` are industry standard
3. **Template should handle complexity**: Kubernetes version detection, backward compatibility
4. **Vulcan is the reference**: Already implements best practices, copy/adapt pattern
5. **Easy fix**: Most work is deleting/moving code, not writing new code

**Bottom Line**: Heimdall's ingress config is close, but needs refactoring to match industry standards for maintainability and user experience.
