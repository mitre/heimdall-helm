# Troubleshooting Guide

Common issues and solutions for Heimdall Helm chart deployment and operation.

## General Troubleshooting Steps

### 1. Check Pod Status

```bash
# List all pods
kubectl get pods -n heimdall

# Describe problematic pod
kubectl describe pod -n heimdall <pod-name>

# Check pod events
kubectl get events -n heimdall --sort-by='.lastTimestamp' | grep <pod-name>

# View pod logs
kubectl logs -n heimdall <pod-name> -f

# View previous container logs (after crash)
kubectl logs -n heimdall <pod-name> --previous
```

### 2. Check Helm Release Status

```bash
# Get release status
helm status heimdall -n heimdall

# View release history
helm history heimdall -n heimdall

# Get deployed manifest
helm get manifest heimdall -n heimdall

# Get all values (including defaults)
helm get values heimdall -n heimdall --all
```

### 3. Check Resources

```bash
# Get all resources
kubectl get all,configmap,secret,ingress,pvc -n heimdall

# Check resource usage
kubectl top pods -n heimdall
kubectl top nodes
```

## Installation Issues

### Error: "Kubernetes cluster unreachable"

**Symptoms**:
```
Error: Kubernetes cluster unreachable: Get "https://...": dial tcp: i/o timeout
```

**Causes**:
- kubectl not configured
- Cluster not running
- Wrong context selected

**Solutions**:

```bash
# Check cluster status
kubectl cluster-info

# List available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context <context-name>

# Verify connection
kubectl get nodes

# For Docker Desktop: restart Docker
# For kind: kind get clusters && kubectl config use-context kind-<cluster-name>
# For minikube: minikube start
```

### Error: "chart requires kubeVersion"

**Symptoms**:
```
Error: chart requires kubeVersion: >=1.20.0 which is incompatible with Kubernetes v1.19.0
```

**Causes**:
- Kubernetes version too old
- kubeVersion constraint too restrictive

**Solutions**:

```bash
# Check Kubernetes version
kubectl version --short

# Option 1: Upgrade Kubernetes
# For kind: delete and recreate cluster with newer version
kind delete cluster --name heimdall-dev
kind create cluster --name heimdall-dev --image kindest/node:v1.28.0

# Option 2: Modify Chart.yaml (if appropriate)
# Edit heimdall/Chart.yaml
# Change: kubeVersion: ">=1.20.0"
# To: kubeVersion: ">=1.19.0"
```

### Error: "cannot re-use a name that is still in use"

**Symptoms**:
```
Error: INSTALLATION FAILED: cannot re-use a name that is still in use
```

**Causes**:
- Release name already exists
- Previous uninstall incomplete

**Solutions**:

```bash
# Check existing releases
helm list -n heimdall
helm list --all-namespaces

# Option 1: Uninstall existing release
helm uninstall heimdall -n heimdall

# Option 2: Use different release name
helm install heimdall-new ./heimdall -n heimdall

# Option 3: Use upgrade --install (idempotent)
helm upgrade --install heimdall ./heimdall -n heimdall
```

### Error: "rendered manifests contain a resource that already exists"

**Symptoms**:
```
Error: INSTALLATION FAILED: rendered manifests contain a resource that already exists.
Unable to continue with install: Secret "heimdall-secrets" in namespace "heimdall" exists
```

**Causes**:
- Resources from previous installation remain
- Namespace not cleaned up

**Solutions**:

```bash
# Check existing resources
kubectl get all,secret,configmap,pvc -n heimdall

# Delete specific resource
kubectl delete secret -n heimdall heimdall-secrets

# Or delete entire namespace and start fresh
kubectl delete namespace heimdall
helm install heimdall ./heimdall -n heimdall --create-namespace
```

## Pod Startup Issues

### Pod Status: ImagePullBackOff

**Symptoms**:
```
NAME         READY   STATUS             RESTARTS   AGE
heimdall-0   0/1     ImagePullBackOff   0          2m
```

**Causes**:
- Image doesn't exist
- Image tag incorrect
- Private registry without credentials
- Rate limiting (Docker Hub)

**Solutions**:

```bash
# Describe pod to see error
kubectl describe pod -n heimdall heimdall-0 | grep -A 10 Events

# Verify image exists
docker pull mitre/heimdall2:release-latest

# Check image tag in values
helm get values heimdall -n heimdall | grep -A 3 image

# For private registry: create pull secret
kubectl create secret docker-registry regcred -n heimdall \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password>

# Update values to use pull secret
helm upgrade heimdall ./heimdall -n heimdall \
  --set heimdall.imagePullSecrets[0].name=regcred
```

### Pod Status: CrashLoopBackOff

**Symptoms**:
```
NAME         READY   STATUS              RESTARTS   AGE
heimdall-0   0/1     CrashLoopBackOff    5          5m
```

**Causes**:
- Application error on startup
- Missing required environment variables
- Database connection failure
- Failed health probes

**Solutions**:

```bash
# Check logs
kubectl logs -n heimdall heimdall-0

# Check previous container logs
kubectl logs -n heimdall heimdall-0 --previous

# Check environment variables
kubectl exec -n heimdall heimdall-0 -- env | grep DATABASE

# Verify database connection
kubectl exec -n heimdall heimdall-postgresql-0 -- \
  pg_isready -h localhost -p 5432 -U postgres

# Check ConfigMap
kubectl get configmap -n heimdall heimdall-config -o yaml

# Check Secret
kubectl get secret -n heimdall heimdall-secrets -o yaml
```

### Pod Stuck in Init:0/1

**Symptoms**:
```
NAME         READY   STATUS     RESTARTS   AGE
heimdall-0   0/1     Init:0/1   0          10m
```

**Causes**:
- Init container waiting for database
- Database not ready
- Network issues

**Solutions**:

```bash
# Check init container logs
kubectl logs -n heimdall heimdall-0 -c check-db-ready

# Check PostgreSQL pod
kubectl get pods -n heimdall | grep postgresql

# Describe PostgreSQL pod
kubectl describe pod -n heimdall heimdall-postgresql-0

# Manually test database connection
kubectl run -n heimdall pg-test --rm -i --tty \
  --image=postgres:13 -- \
  pg_isready -h heimdall-postgresql -p 5432 -U postgres
```

### Pod Pending (Not Scheduling)

**Symptoms**:
```
NAME         READY   STATUS    RESTARTS   AGE
heimdall-0   0/1     Pending   0          5m
```

**Causes**:
- Insufficient node resources
- PVC provisioning failure
- Node selector mismatch
- Taints/tolerations issue

**Solutions**:

```bash
# Describe pod to see reason
kubectl describe pod -n heimdall heimdall-0 | grep -A 10 Events

# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check PVC status
kubectl get pvc -n heimdall
kubectl describe pvc -n heimdall data-heimdall-postgresql-0

# Check if PV available
kubectl get pv

# For kind/minikube: ensure StorageClass exists
kubectl get storageclass
```

## Database Issues

### PostgreSQL Pod Won't Start

**Symptoms**:
- PostgreSQL pod in CrashLoopBackOff
- Database connection errors

**Solutions**:

```bash
# Check PostgreSQL logs
kubectl logs -n heimdall heimdall-postgresql-0

# Check PVC
kubectl get pvc -n heimdall

# Check if PV bound
kubectl get pv | grep heimdall

# Delete PVC and recreate (DELETES DATA)
helm uninstall heimdall -n heimdall
kubectl delete pvc -n heimdall data-heimdall-postgresql-0
helm install heimdall ./heimdall -n heimdall

# For persistent data: backup first
kubectl exec -n heimdall heimdall-postgresql-0 -- \
  pg_dump -U postgres heimdall > backup.sql
```

### Database Password Mismatch

**Symptoms**:
```
FATAL: password authentication failed for user "postgres"
```

**Causes**:
- PVC from old deployment with different password
- Secret mismatch
- Password changed without restarting

**Solutions**:

```bash
# Get current password from secret
kubectl get secret -n heimdall heimdall-postgresql \
  -o jsonpath="{.data.postgres-password}" | base64 -d

# Option 1: Use same password
# Update values.yaml with old password and upgrade

# Option 2: Reset database (DELETES DATA)
helm uninstall heimdall -n heimdall
kubectl delete pvc -n heimdall data-heimdall-postgresql-0
helm install heimdall ./heimdall -n heimdall

# Option 3: Manually reset password in PostgreSQL
kubectl exec -n heimdall -it heimdall-postgresql-0 -- \
  psql -U postgres -c "ALTER USER postgres PASSWORD 'new-password';"
```

### Migration Job Failed

**Symptoms**:
- Migration job shows "Error" or "BackoffLimitExceeded"
- Application won't start

**Solutions**:

```bash
# Check job status
kubectl get jobs -n heimdall

# Check job logs
kubectl logs -n heimdall job/heimdall-migrate

# Describe job
kubectl describe job -n heimdall heimdall-migrate

# Common issues:
# 1. Database not ready
# 2. Migration syntax error
# 3. Missing database permissions

# Delete failed job and retry
kubectl delete job -n heimdall heimdall-migrate
helm upgrade heimdall ./heimdall -n heimdall

# Manually run migrations
kubectl exec -n heimdall -it heimdall-0 -- \
  npx sequelize-cli db:migrate
```

## Networking Issues

### Cannot Access Application via Port Forward

**Symptoms**:
```bash
kubectl port-forward -n heimdall statefulset/heimdall 3000:3000
# curl http://localhost:3000
# Connection refused
```

**Solutions**:

```bash
# Verify pod is running
kubectl get pods -n heimdall

# Verify pod is ready
kubectl describe pod -n heimdall heimdall-0 | grep -A 5 Conditions

# Check application logs
kubectl logs -n heimdall heimdall-0

# Verify port is correct
kubectl get svc -n heimdall heimdall -o yaml | grep port

# Test from within cluster
kubectl run -n heimdall test --rm -i --tty \
  --image=curlimages/curl -- curl -v http://heimdall:3000
```

### Ingress Not Working

**Symptoms**:
- 404 Not Found
- 502 Bad Gateway
- DNS resolution issues

**Solutions**:

```bash
# Check ingress exists
kubectl get ingress -n heimdall

# Describe ingress
kubectl describe ingress -n heimdall heimdall

# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Verify service backend
kubectl get svc -n heimdall

# Test service directly
kubectl run -n heimdall test --rm -i --tty \
  --image=curlimages/curl -- curl -v http://heimdall:3000

# For local testing: update /etc/hosts
echo "127.0.0.1 heimdall.local" | sudo tee -a /etc/hosts

# Test ingress
curl -H "Host: heimdall.local" http://localhost
```

### Service Not Routing Traffic

**Symptoms**:
- Service exists but requests fail
- Connection timeout

**Solutions**:

```bash
# Check service
kubectl get svc -n heimdall

# Describe service
kubectl describe svc -n heimdall heimdall

# Check endpoints
kubectl get endpoints -n heimdall heimdall

# Verify selector matches pods
kubectl get pods -n heimdall --show-labels
kubectl get svc -n heimdall heimdall -o yaml | grep selector

# Test service from within cluster
kubectl run -n heimdall test --rm -i --tty \
  --image=curlimages/curl -- curl -v http://heimdall:3000
```

## Secrets and Configuration Issues

### Missing Environment Variables

**Symptoms**:
- Application error: "DATABASE_HOST is not defined"
- Missing required configuration

**Solutions**:

```bash
# Check ConfigMap
kubectl get configmap -n heimdall heimdall-config -o yaml

# Check Secret
kubectl get secret -n heimdall heimdall-secrets -o yaml

# Verify pod has envFrom
kubectl get statefulset -n heimdall heimdall -o yaml | grep -A 10 envFrom

# Check environment in pod
kubectl exec -n heimdall heimdall-0 -- env | grep DATABASE

# Recreate ConfigMap/Secret
helm upgrade heimdall ./heimdall -n heimdall
```

### Secrets File Not Found

**Symptoms**:
```
Error: secrets file not found: heimdall/env/heimdall-secrets.yaml
```

**Causes**:
- Secrets file not generated
- File path incorrect
- Using wrong secrets approach

**Solutions**:

```bash
# Generate secrets file
./generate-heimdall-secrets.sh

# Verify file exists
ls -la heimdall/env/heimdall-secrets.yaml

# Or use existing secret instead
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.existingSecret=my-existing-secret

# Or use inline secrets
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.secrets.JWT_SECRET="$(openssl rand -hex 64)"
```

## Helm Chart Issues

### Template Rendering Errors

**Symptoms**:
```
Error: template: heimdall/templates/heimdall-statefulset.yaml:45:20:
  executing "heimdall/templates/heimdall-statefulset.yaml" at <.Values.foo.bar>:
  nil pointer evaluating interface {}.bar
```

**Causes**:
- Missing required value
- Incorrect template syntax
- Wrong value path

**Solutions**:

```bash
# Template with debug output
helm template heimdall ./heimdall --debug 2>&1 | less

# Check specific template
helm template heimdall ./heimdall \
  --show-only templates/heimdall-statefulset.yaml

# Verify values
helm template heimdall ./heimdall --debug | grep -A 5 "foo:"

# Use default values
helm template heimdall ./heimdall --set foo.bar="default"
```

### Dependency Issues

**Symptoms**:
```
Error: found in Chart.yaml, but missing in charts/ directory: postgresql
```

**Causes**:
- Dependencies not downloaded
- Chart.lock out of sync

**Solutions**:

```bash
# Update dependencies
helm dependency update ./heimdall

# Or build from Chart.lock
helm dependency build ./heimdall

# Verify dependencies
helm dependency list ./heimdall
ls -la heimdall/charts/

# Clean and rebuild
rm -rf heimdall/charts/ heimdall/Chart.lock
helm dependency update ./heimdall
```

### Values Validation Errors

**Symptoms**:
```
Error: values don't meet the specifications of the schema(s)
- heimdall.replicaCount: Invalid type. Expected: integer, given: string
```

**Causes**:
- Value type mismatch
- Invalid enum value
- Missing required field

**Solutions**:

```bash
# Check schema
cat heimdall/values.schema.json | jq '.properties.heimdall.properties.replicaCount'

# Fix value type
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.replicaCount=3  # Not "3" (string)

# Skip schema validation (not recommended)
helm install heimdall ./heimdall -n heimdall --skip-schema-validation
```

## Upgrade and Rollback Issues

### Upgrade Failed: Immutable Field

**Symptoms**:
```
Error: UPGRADE FAILED: cannot patch "heimdall" with kind Service:
Service "heimdall" is invalid: spec.clusterIP: Invalid value
```

**Causes**:
- Changed immutable field (e.g., Service clusterIP, PVC size)
- Kubernetes prevents modification

**Solutions**:

```bash
# Delete resource and recreate
kubectl delete service -n heimdall heimdall
helm upgrade heimdall ./heimdall -n heimdall

# Or uninstall and reinstall
helm uninstall heimdall -n heimdall
helm install heimdall ./heimdall -n heimdall

# For PVC size change: backup data, delete PVC, restore
kubectl exec -n heimdall heimdall-postgresql-0 -- \
  pg_dump -U postgres heimdall > backup.sql
kubectl delete pvc -n heimdall data-heimdall-postgresql-0
helm upgrade heimdall ./heimdall -n heimdall --set postgresql.primary.persistence.size=20Gi
# Restore data...
```

### Rollback Failed

**Symptoms**:
- Rollback command fails
- Application in broken state

**Solutions**:

```bash
# Check rollback history
helm history heimdall -n heimdall

# Rollback to specific revision
helm rollback heimdall 2 -n heimdall

# If rollback fails: uninstall and reinstall
helm uninstall heimdall -n heimdall
helm install heimdall ./heimdall -n heimdall --version <stable-version>
```

## Resource Limit Issues

### OOMKilled (Out of Memory)

**Symptoms**:
```
NAME         READY   STATUS      RESTARTS   AGE
heimdall-0   0/1     OOMKilled   3          5m
```

**Causes**:
- Memory limit too low
- Memory leak in application
- Large dataset processing

**Solutions**:

```bash
# Check memory limit
kubectl describe pod -n heimdall heimdall-0 | grep -A 5 Limits

# Increase memory limit
helm upgrade heimdall ./heimdall -n heimdall \
  --set heimdall.resources.limits.memory=2Gi \
  --set heimdall.resources.requests.memory=1Gi

# Monitor memory usage
kubectl top pods -n heimdall --watch

# Check for memory leak
kubectl logs -n heimdall heimdall-0 | grep -i "memory\|heap"
```

### CPU Throttling

**Symptoms**:
- Application slow
- High CPU usage

**Solutions**:

```bash
# Check CPU usage
kubectl top pods -n heimdall

# Check CPU limits
kubectl describe pod -n heimdall heimdall-0 | grep -A 5 Limits

# Increase CPU limits
helm upgrade heimdall ./heimdall -n heimdall \
  --set heimdall.resources.limits.cpu=2000m \
  --set heimdall.resources.requests.cpu=500m

# Enable autoscaling
helm upgrade heimdall ./heimdall -n heimdall \
  --set heimdall.autoscaling.enabled=true \
  --set heimdall.autoscaling.targetCPUUtilizationPercentage=70
```

## Health Probe Failures

### Readiness Probe Failing

**Symptoms**:
- Pod shows 0/1 Ready
- Traffic not routed to pod

**Solutions**:

```bash
# Check readiness probe
kubectl describe pod -n heimdall heimdall-0 | grep -A 5 Readiness

# Test probe endpoint manually
kubectl exec -n heimdall heimdall-0 -- \
  curl -f http://localhost:3000/health_check/database

# Check logs for errors
kubectl logs -n heimdall heimdall-0

# Adjust probe timing
helm upgrade heimdall ./heimdall -n heimdall \
  --set heimdall.readinessProbe.initialDelaySeconds=60 \
  --set heimdall.readinessProbe.periodSeconds=10
```

### Liveness Probe Failing

**Symptoms**:
- Pod constantly restarting
- High restart count

**Solutions**:

```bash
# Check liveness probe failures
kubectl describe pod -n heimdall heimdall-0 | grep -A 10 Liveness

# Test probe endpoint
kubectl exec -n heimdall heimdall-0 -- curl -f http://localhost:3000/up

# Increase timeout/threshold
helm upgrade heimdall ./heimdall -n heimdall \
  --set heimdall.livenessProbe.timeoutSeconds=10 \
  --set heimdall.livenessProbe.failureThreshold=5

# Check for application deadlock
kubectl logs -n heimdall heimdall-0 --previous
```

## Getting Help

### Collect Diagnostic Information

```bash
# Create diagnostic bundle
kubectl get all,configmap,secret,ingress,pvc -n heimdall -o yaml > heimdall-resources.yaml
helm get all heimdall -n heimdall > heimdall-release.yaml
kubectl logs -n heimdall heimdall-0 > heimdall-logs.txt
kubectl logs -n heimdall heimdall-postgresql-0 > postgresql-logs.txt
kubectl get events -n heimdall --sort-by='.lastTimestamp' > heimdall-events.txt

# Package for support
tar czf heimdall-diagnostics.tar.gz heimdall-*.yaml heimdall-*.txt
```

### Report Issue

When reporting issues:

1. **Include environment details**:
   ```bash
   kubectl version
   helm version
   kubectl get nodes -o wide
   ```

2. **Describe the problem**:
   - What were you trying to do?
   - What actually happened?
   - What error messages did you see?

3. **Attach diagnostic bundle**: `heimdall-diagnostics.tar.gz`

4. **Create issue**: https://github.com/mitre/heimdall-helm/issues

## Common Error Messages

### "no matches for kind ... in version ..."

**Meaning**: Kubernetes API version not available
**Fix**: Update apiVersion in template or upgrade Kubernetes

### "admission webhook ... denied the request"

**Meaning**: Admission controller rejected resource
**Fix**: Check admission controller logs, adjust resource specification

### "context deadline exceeded"

**Meaning**: Operation timed out
**Fix**: Increase timeout with `--timeout 10m` or check resource issues

### "unable to build kubernetes objects from release manifest"

**Meaning**: Invalid Kubernetes resource in manifest
**Fix**: Run `helm template` to identify invalid resource

## References

- [Kubernetes Debugging](https://kubernetes.io/docs/tasks/debug/)
- [Helm Troubleshooting](https://helm.sh/docs/faq/troubleshooting/)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
- [Heimdall GitHub Issues](https://github.com/mitre/heimdall-helm/issues)
