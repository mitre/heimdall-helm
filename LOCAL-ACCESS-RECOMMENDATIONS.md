# Local Kubernetes Service Access - Best Practices for Helm Charts

**Research Date**: 2026-01-03
**Context**: Heimdall Helm chart local development on kind cluster (macOS)
**Goal**: Stable localhost URLs for OAuth callbacks, developer-friendly, CI-compatible

## Executive Summary

After researching current best practices (2025-2026), the recommended approach for local Kubernetes development is:

1. **Primary**: Ingress Controller (Traefik) + LoadBalancer with MetalLB
2. **Secondary**: Port-forwarding automation (kubefwd) for quick testing
3. **DNS**: nip.io/sslip.io for stable hostnames
4. **Avoid**: NodePort (except for ingress controller itself)

## Current State (Heimdall Chart)

```yaml
service:
  type: ClusterIP      # Good - internal only
  port: 3000

ingress:
  enabled: false       # Disabled by default
  className: "traefik"
  hosts:
    - host: heimdall.local
      paths:
        - path: /
          pathType: Prefix
```

**Status**: Chart has ingress support but requires manual setup. No documentation for local development access.

## Recommended Solutions

### Option 1: Ingress + MetalLB (RECOMMENDED)

**Why**: Industry standard, production-like, stable URLs for OAuth

**Setup Time**: 10-15 minutes (one-time)
**Complexity**: Medium
**OAuth Compatible**: Yes
**CI Compatible**: Yes

#### Implementation

**1. Create kind cluster with ingress support:**

```bash
cat <<EOF | kind create cluster --name heimdall-dev --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

**2. Install MetalLB:**

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# Wait for MetalLB pods
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

**3. Configure MetalLB IP pool:**

```bash
# Get kind cluster's Docker network CIDR
docker network inspect kind | jq -r '.[0].IPAM.Config[].Subnet'
# Example output: 172.18.0.0/16

# Create IP pool (use range from cluster CIDR)
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: empty
  namespace: metallb-system
EOF
```

**4. Install Traefik ingress controller:**

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set "ports.web.redirectTo.port=websecure" \
  --set "ports.websecure.tls.enabled=true"
```

**5. Install Heimdall with ingress enabled:**

```bash
# Get LoadBalancer IP
INGRESS_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Install Heimdall using nip.io for DNS
helm upgrade --install heimdall ./heimdall \
  --namespace heimdall --create-namespace \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.className=traefik \
  --set "heimdall.ingress.hosts[0].host=heimdall.${INGRESS_IP}.nip.io" \
  --set "heimdall.ingress.hosts[0].paths[0].path=/" \
  --set "heimdall.ingress.hosts[0].paths[0].pathType=Prefix" \
  --set externalUrl="http://heimdall.${INGRESS_IP}.nip.io"

# Access at: http://heimdall.172.18.255.200.nip.io
```

**Benefits**:
- Stable URLs that work across restarts
- Production-like environment
- OAuth callbacks work reliably
- Multiple services can coexist
- Works in CI (GitHub Actions, GitLab CI)

**Drawbacks**:
- Initial setup complexity
- Requires understanding of MetalLB + Ingress
- DNS relies on external service (nip.io)

**References**:
- [kind LoadBalancer Documentation](https://kind.sigs.k8s.io/docs/user/loadbalancer/)
- [MetalLB with kind Tutorial](https://medium.com/@tylerauerbeck/metallb-and-kind-loads-balanced-locally-1992d60111d8)
- [kind + Calico + Nginx + MetalLB Setup](https://medium.com/@gucriya/setting-up-a-local-kubernetes-cluster-with-kind-calico-nginx-ingress-and-metallb-2121a2b357c4)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)

---

### Option 2: Port-Forward Automation (kubefwd)

**Why**: Simple, no cluster modification, good for quick testing

**Setup Time**: 2 minutes
**Complexity**: Low
**OAuth Compatible**: Limited (localhost only)
**CI Compatible**: No

#### Implementation

**1. Install kubefwd:**

```bash
# macOS
brew install txn2/tap/kubefwd

# Linux (binary release)
wget https://github.com/txn2/kubefwd/releases/download/v1.22.5/kubefwd_Linux_x86_64.tar.gz
tar xzf kubefwd_Linux_x86_64.tar.gz
sudo mv kubefwd /usr/local/bin/
```

**2. Forward all services in namespace:**

```bash
# Forward all heimdall namespace services
sudo kubefwd svc -n heimdall

# Output:
# 127.1.0.1:3000 → heimdall.heimdall
# 127.1.0.2:5432 → heimdall-postgresql.heimdall
```

**3. Access via service name:**

```bash
# /etc/hosts automatically updated
curl http://heimdall.heimdall:3000
```

**Benefits**:
- Zero cluster configuration
- Works with any Kubernetes cluster
- Automatic /etc/hosts management
- Unique IPs per service (no port conflicts)
- Interactive TUI with traffic metrics

**Drawbacks**:
- Requires sudo (modifies /etc/hosts)
- Doesn't survive cluster restarts well
- OAuth callbacks limited to localhost
- Not suitable for CI environments
- Connection breaks when pods restart (auto-reconnects)

**Alternative - Single Service Port Forward:**

```bash
# For simple cases, use kubectl directly
kubectl port-forward -n heimdall svc/heimdall 8080:3000

# Access at: http://localhost:8080
```

**References**:
- [kubefwd GitHub Repository](https://github.com/txn2/kubefwd)
- [kubefwd Official Site](https://kubefwd.com/)
- [kubectl port-forward Guide](https://apipark.com/techblog/en/how-to-use-kubectl-port-forward-a-practical-guide/)

---

### Option 3: Telepresence 2 (ADVANCED)

**Why**: Two-way networking, local dev with cluster integration

**Setup Time**: 15-20 minutes
**Complexity**: High
**OAuth Compatible**: Yes
**CI Compatible**: No (development tool only)

**When to Use**:
- Developing/debugging Heimdall application code
- Need local app to call cluster services
- Need cluster services to call local app
- Running Heimdall locally with production database

**Not Needed For**:
- Helm chart development (our use case)
- Simple service access
- CI/CD testing

Telepresence intercepts traffic for a Kubernetes service and routes it to your local machine, allowing your local application to participate in the cluster's network directly.

**References**:
- [Telepresence 2 for Kubernetes Debugging](https://codefresh.io/blog/telepresence-2-local-development/)
- [Debugging K8s Services - 3 Tools](https://erkanerol.github.io/post/debugging-k8s-services/)

---

## DNS Solutions for Local Development

### nip.io / sslip.io (RECOMMENDED)

**How it works**: DNS service that maps IP addresses embedded in hostnames

```
http://heimdall.172.18.255.200.nip.io  → 172.18.255.200
http://heimdall.127.0.0.1.nip.io       → 127.0.0.1
http://app-name.10.0.0.5.sslip.io      → 10.0.0.5
```

**Stability**:
- nip.io now hosted by sslip.io (merged projects)
- 10+ years of operation
- 5000+ queries/second
- Used by Google and IBM in official docs

**Pros**:
- Zero configuration
- Works anywhere (developers, CI, air-gapped with fallback)
- Automatic DNS resolution
- Supports OAuth callbacks (stable URLs)

**Cons**:
- External dependency (service SLA)
- Requires internet for DNS resolution
- Not suitable for air-gapped environments

**Usage Example**:

```bash
# Get LoadBalancer IP
LB_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Install with nip.io hostname
helm upgrade --install heimdall ./heimdall \
  --set heimdall.ingress.enabled=true \
  --set "heimdall.ingress.hosts[0].host=heimdall.${LB_IP}.nip.io" \
  --set externalUrl="http://heimdall.${LB_IP}.nip.io"

# OAuth callback URL: http://heimdall.172.18.255.200.nip.io/authn/gitlab/callback
```

**References**:
- [nip.io / sslip.io Official Site](https://sslip.io/)
- [Knative Local Development with kind (no DNS headaches)](https://knative.dev/blog/articles/set-up-a-local-knative-environment-with-kind/)
- [Google Cloud - Using test domains](https://cloud.google.com/kubernetes-engine/enterprise/knative-serving/docs/default-domain)

### Local /etc/hosts (SIMPLE)

**Pros**: No external dependencies, works air-gapped
**Cons**: Manual updates, doesn't scale, requires sudo

```bash
# Add to /etc/hosts
echo "127.0.0.1 heimdall.local" | sudo tee -a /etc/hosts

# Use with port-forward
kubectl port-forward -n heimdall svc/heimdall 80:3000

# Access: http://heimdall.local
```

---

## What Major Helm Charts Do

### GitLab Helm Chart

**Approach**: Ingress controller required
**Local Development**: Domain-based access via ingress
**Default Domain**: `gitlab.example.com` (user configures)

From [GitLab Helm chart docs](https://docs.gitlab.com/charts/):
- Requires ingress controller in cluster
- Global `hosts` configuration for all services
- Recommends cloud or local Kubernetes for development
- Local clusters sufficient for simple issues
- Cloud clusters for networking/storage testing

**Key Insight**: No special "local mode" - same ingress approach for dev and prod

### Harbor Helm Chart

**Approach**: Flexible - ingress, NodePort, LoadBalancer, or ClusterIP
**Local Development**: Port-forward for quick access, ingress for OAuth

From [Harbor Helm repository](https://github.com/goharbor/harbor-helm):
- Service exposure via `expose.type`: ingress (default), clusterIP, nodePort, loadBalancer
- Ingress controller must be installed separately
- Supports multiple ingress controllers: default, gce, alb, f5-bigip, ncp
- TLS configuration required for ingress

**Key Insight**: Default to ingress, provide fallbacks for different environments

### Grafana Helm Chart

**Approach**: Service type configurable, ingress optional
**Local Development**: Port-forward documented in README

From [Grafana Helm charts](https://github.com/grafana/helm-charts):
```bash
# Quick access via port-forward
kubectl port-forward svc/grafana 3000:80
# Access: http://localhost:3000
```

**Service Configuration**:
- Default service type: ClusterIP
- Ingress optional with subpath support
- LoadBalancer support for cloud environments

**Key Insight**: Simple default (ClusterIP + port-forward), document ingress setup for production

---

## Recommendation for Heimdall Chart

### Phase 1: Document Current State (Immediate)

Create `docs/content/4.helm-chart/local-development.md`:

```markdown
## Quick Start (Port Forward)

For immediate access without cluster configuration:

```bash
# Install Heimdall
helm install heimdall ./heimdall -n heimdall --create-namespace

# Forward port 8080 → Heimdall service
kubectl port-forward -n heimdall svc/heimdall 8080:3000

# Access: http://localhost:8080
```

**Note**: OAuth providers won't work with localhost URLs (use ingress setup below)

## Production Setup (Ingress)

See [Ingress Configuration](./ingress.md) for stable URLs compatible with OAuth.
```

### Phase 2: Provide Example Values Files (Short-term)

**`values-local-ingress.yaml`** (for developers):

```yaml
# Local development with kind + MetalLB + Traefik
# Assumes ingress controller is already installed
# See: docs/local-development.md for cluster setup

heimdall:
  ingress:
    enabled: true
    className: "traefik"
    hosts:
      - host: "heimdall.172.18.255.200.nip.io"  # Replace with your MetalLB IP
        paths:
          - path: /
            pathType: Prefix

# EXTERNAL_URL for OAuth callbacks
externalUrl: "http://heimdall.172.18.255.200.nip.io"

# Example OAuth configuration (GitLab)
gitlabClientId: "your-client-id"
# Callback URL: http://heimdall.172.18.255.200.nip.io/authn/gitlab/callback
```

**`values-local-portforward.yaml`** (for quick testing):

```yaml
# Quick testing without ingress
# Use with: kubectl port-forward -n heimdall svc/heimdall 8080:3000
# Access: http://localhost:8080

heimdall:
  service:
    type: ClusterIP
    port: 3000

  ingress:
    enabled: false

# WARNING: OAuth providers won't work with localhost
# Use values-local-ingress.yaml for OAuth testing
```

### Phase 3: Add Helper Scripts (Future)

**`scripts/kind-setup.sh`**:
- Automate kind cluster creation with ingress ports
- Install MetalLB + Traefik
- Configure IP pools
- Output ready-to-use Helm values

**`scripts/get-ingress-url.sh`**:
- Detect LoadBalancer IP
- Generate nip.io URL
- Show kubectl port-forward command as fallback

---

## OAuth Callback URL Considerations

### The Challenge

OAuth providers require stable callback URLs:
- `http://localhost:8080/authn/gitlab/callback` ❌ Changes with port
- `http://heimdall.local/authn/gitlab/callback` ❌ Requires /etc/hosts + port-forward
- `http://heimdall.172.18.255.200.nip.io/authn/gitlab/callback` ✅ Stable, works

### Why This Matters

From [OAuth2 Proxy Dynamic Callbacks](https://elsesiy.com/blog/oauth2-proxy-dynamic-callback-urls):
- OAuth providers validate redirect_uri against registered URLs
- Port-forwarded localhost URLs change frequently
- Ingress provides stable hostnames
- nip.io DNS allows IP-based stable URLs without manual DNS

### Best Practice

**Document both approaches**:

1. **Port-forward**: Quick testing, no OAuth
2. **Ingress + nip.io**: Full OAuth support, stable URLs

**Heimdall-specific note**:
- `EXTERNAL_URL` environment variable sets OAuth callback base
- Must match ingress hostname or port-forward URL
- GitLab OAuth bug (issue #7542) requires `EXTERNAL_URL` WITHOUT `/authn` path

---

## CI/CD Considerations

### GitHub Actions

**Recommended**: Ingress + MetalLB (same as local)

```yaml
- name: Create kind cluster
  uses: helm/kind-action@v1
  with:
    config: tests/kind-config.yaml

- name: Install MetalLB
  run: |
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
    # Configure IP pool...

- name: Install Traefik
  run: |
    helm repo add traefik https://traefik.github.io/charts
    helm install traefik traefik/traefik -n traefik --create-namespace

- name: Test Heimdall chart
  run: |
    helm install heimdall ./heimdall -f tests/values-ci.yaml
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=heimdall
```

### GitLab CI

Same approach - kind + MetalLB + Traefik works in GitLab runners

---

## Comparison Matrix

| Approach | Setup Time | OAuth Support | CI Compatible | Stability | Complexity |
|----------|-----------|---------------|---------------|-----------|------------|
| **Ingress + MetalLB** | 15 min | ✅ Yes | ✅ Yes | ⭐⭐⭐⭐⭐ | Medium |
| **Port-forward (manual)** | 30 sec | ❌ No | ⚠️ Limited | ⭐⭐ | Low |
| **kubefwd** | 2 min | ⚠️ Localhost only | ❌ No | ⭐⭐⭐ | Low |
| **Telepresence** | 20 min | ✅ Yes | ❌ No | ⭐⭐⭐⭐ | High |
| **NodePort** | 1 min | ⚠️ Unstable ports | ⚠️ Limited | ⭐⭐ | Low |

**Legend**:
- ✅ Full support
- ⚠️ Partial/limited support
- ❌ Not supported
- ⭐ 1-5 rating

---

## Implementation Plan for Heimdall Chart

### Immediate (Document existing patterns)
1. Create `docs/content/4.helm-chart/local-development.md`
2. Document port-forward quick start
3. Document ingress setup for OAuth

### Short-term (Provide examples)
1. Add `values-local-ingress.yaml` example
2. Add `values-local-portforward.yaml` example
3. Update main README with local access section

### Future (Automation)
1. Create `scripts/kind-setup.sh` for cluster setup
2. Create `scripts/get-access-url.sh` for URL detection
3. Add Makefile targets for common workflows
4. Consider adding local development profile to CI

---

## Key Takeaways

1. **Ingress + MetalLB is the industry standard** for local Kubernetes development
2. **nip.io/sslip.io eliminates DNS hassles** and has been stable for 10+ years
3. **Port-forwarding works for quick tests** but breaks OAuth and isn't production-like
4. **Major charts (GitLab, Harbor, Grafana) default to ingress** with port-forward as fallback
5. **Traefik is recommended over Nginx** (Nginx ingress controller retiring March 2026)
6. **Same setup works for dev and CI** (kind + MetalLB + Traefik)
7. **Document both approaches**: Quick (port-forward) and Full (ingress)

---

## References

### Official Documentation
- [kind LoadBalancer Support](https://kind.sigs.k8s.io/docs/user/loadbalancer/)
- [kind Ingress Setup](https://kind.sigs.k8s.io/docs/user/ingress/)
- [MetalLB Installation](https://metallb.universe.tf/installation/)
- [MetalLB Usage Guide](https://metallb.universe.tf/usage/)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [NGINX Ingress Basic Usage](https://kubernetes.github.io/ingress-nginx/user-guide/basic-usage/)

### Tutorials & Guides
- [MetalLB and kind: Loads Balanced Locally](https://medium.com/@tylerauerbeck/metallb-and-kind-loads-balanced-locally-1992d60111d8)
- [Setting Up Local k8s with kind, Calico, Nginx, MetalLB](https://medium.com/@gucriya/setting-up-a-local-kubernetes-cluster-with-kind-calico-nginx-ingress-and-metallb-2121a2b357c4)
- [Deploy Nginx Ingress on kind Cluster](https://medium.com/@vaklinov81/deploy-nginx-ingress-on-kind-cluster-23b7cfb5ce66)
- [kind Ingress Tutorial](https://dustinspecker.com/posts/test-ingress-in-kind/)
- [Install Traefik with Helm](https://traefik.io/blog/install-and-configure-traefik-with-helm)

### Tools
- [kubefwd - Bulk Port Forwarding](https://github.com/txn2/kubefwd)
- [Telepresence 2](https://codefresh.io/blog/telepresence-2-local-development/)
- [kforward - Lightweight Proxy](https://github.com/sanspareilsmyn/kforward)

### DNS Services
- [nip.io / sslip.io](https://sslip.io/)
- [Knative - Set up local environment without DNS headaches](https://knative.dev/blog/articles/set-up-a-local-knative-environment-with-kind/)

### OAuth & Authentication
- [OAuth2 Proxy with Dynamic Callback URLs](https://elsesiy.com/blog/oauth2-proxy-dynamic-callback-urls)
- [NGINX Ingress - External OAuth Authentication](https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/)
- [OAuth2 Proxy Issue #109 - Ingress Setup](https://github.com/oauth2-proxy/oauth2-proxy/issues/109)

### Major Helm Charts Reference
- [GitLab Helm Chart Documentation](https://docs.gitlab.com/charts/)
- [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
- [Grafana Helm Chart](https://github.com/grafana/helm-charts)

### Comparison Articles
- [Debugging k8s Services: 3 Tools for 3 Scenarios](https://erkanerol.github.io/post/debugging-k8s-services/)
- [HAProxy Ingress Best Practices](https://dev.to/alakkadshaw/haproxy-ingress-controller-kubernetes-installation-configuration-best-practices-2b67)

---

**Document Version**: 1.0
**Last Updated**: 2026-01-03
**Maintained By**: Heimdall Helm Chart Team
