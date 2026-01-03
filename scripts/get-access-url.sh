#!/bin/bash
set -e

# Get Heimdall access URL from existing installation
# Works with both ingress and port-forward setups

NAMESPACE=${1:-heimdall}

echo "Checking Heimdall installation in namespace: $NAMESPACE"
echo ""

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "Error: Namespace '$NAMESPACE' not found"
    echo ""
    echo "Available namespaces:"
    kubectl get namespaces
    exit 1
fi

# Check if Heimdall is installed
if ! kubectl get deployment,statefulset -n "$NAMESPACE" -l app.kubernetes.io/name=heimdall >/dev/null 2>&1; then
    echo "Error: Heimdall not found in namespace '$NAMESPACE'"
    exit 1
fi

# Check for ingress
INGRESS_ENABLED=$(kubectl get ingress -n "$NAMESPACE" 2>/dev/null | grep -c heimdall || echo "0")

if [ "$INGRESS_ENABLED" -gt 0 ]; then
    echo "✓ Ingress detected"
    echo ""

    # Get ingress host
    INGRESS_HOST=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.rules[0].host}')

    # Check if TLS is enabled
    TLS_ENABLED=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{.items[0].spec.tls}' | grep -c secretName || echo "0")

    if [ "$TLS_ENABLED" -gt 0 ]; then
        PROTOCOL="https"
    else
        PROTOCOL="http"
    fi

    HEIMDALL_URL="${PROTOCOL}://${INGRESS_HOST}"

    echo "Heimdall URL: $HEIMDALL_URL"
    echo ""
    echo "OAuth Callback URLs:"
    echo "  GitLab: ${HEIMDALL_URL}/authn/gitlab/callback"
    echo "  GitHub: ${HEIMDALL_URL}/authn/github/callback"
    echo "  Google: ${HEIMDALL_URL}/authn/google/callback"
    echo "  Okta:   ${HEIMDALL_URL}/authn/okta/callback"
    echo ""

    # Check if ingress controller has LoadBalancer IP
    echo "Checking ingress controller status..."

    # Try common ingress controller namespaces
    for NS in traefik ingress-nginx nginx-ingress kube-system; do
        LB_IP=$(kubectl get svc -n "$NS" -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [ -n "$LB_IP" ]; then
            echo "✓ Ingress controller LoadBalancer IP: $LB_IP (namespace: $NS)"
            break
        fi
    done

    if [ -z "$LB_IP" ]; then
        echo "⚠ Warning: Ingress controller LoadBalancer IP not found"
        echo "  Ingress may not be accessible from outside the cluster"
    fi
else
    echo "✗ No ingress detected"
    echo ""
    echo "Heimdall is running with ClusterIP service only."
    echo ""
    echo "To access Heimdall, use port-forwarding:"
    echo ""

    # Get service port
    SVC_PORT=$(kubectl get svc -n "$NAMESPACE" -l app.kubernetes.io/name=heimdall -o jsonpath='{.items[0].spec.ports[0].port}')

    echo "kubectl port-forward -n $NAMESPACE svc/heimdall 8080:${SVC_PORT}"
    echo ""
    echo "Then access at: http://localhost:8080"
    echo ""
    echo "⚠ Note: OAuth providers won't work with localhost URLs"
    echo "   To enable OAuth, configure ingress. See: QUICKSTART-LOCAL-SETUP.md"
fi

echo ""
echo "Useful commands:"
echo "  Check pods:      kubectl get pods -n $NAMESPACE"
echo "  View logs:       kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=heimdall -f"
echo "  Check ingress:   kubectl get ingress -n $NAMESPACE"
echo "  Check service:   kubectl get svc -n $NAMESPACE"
echo ""
