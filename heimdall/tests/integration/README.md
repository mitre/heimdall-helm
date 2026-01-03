# Integration Test Values

This directory contains values files for integration testing with various OAuth/OIDC providers.

## Files

- `values-okta-real.yaml` - Template for Okta OAuth testing (placeholders for secrets)
- `oauth2-mock-server.yaml` - navikt OAuth2 mock server deployment
- `oidc-server-mock.yaml` - Soluto OIDC mock server deployment

## Usage Pattern

### For CI/CD Testing

Use the template files with secrets injected from environment:

```bash
helm install heimdall ./heimdall \
  -n heimdall-test \
  -f heimdall/tests/integration/values-okta-real.yaml \
  --set heimdall.secrets.OKTA_CLIENTSECRET=${{ secrets.OKTA_CLIENT_SECRET }}
```

**See:** [`.github/SECRETS.md`](../../.github/SECRETS.md) for GitHub repository secrets configuration.

### For Local Development

1. **Copy template to local override** (gitignored):
   ```bash
   cp values-okta-real.yaml values-okta-local.yaml
   ```

2. **Edit with real credentials**:
   ```yaml
   # values-okta-local.yaml
   heimdall:
     config:
       OKTA_DOMAIN: "trial-8371755.okta.com"
       OKTA_CLIENTID: "0oayuh2ofdfcXHu95697"
     secrets:
       OKTA_CLIENTSECRET: "your-real-secret-here"
   ```

3. **Deploy with local values**:
   ```bash
   helm install heimdall ./heimdall \
     -n heimdall-test \
     -f heimdall/tests/integration/values-okta-local.yaml
   ```

## Security

- ✅ Template files (`*-real.yaml`) - Safe to commit (placeholders only)
- ❌ Local overrides (`*-local.yaml`) - **NEVER commit** (contains real secrets)
- ✅ `.gitignore` configured to block `*-local.yaml` files

## OAuth Provider Setup

### Okta

1. Create Web Application in Okta Developer Console
2. Set redirect URI: `http://localhost:8080/authn/okta_callback`
3. Copy Client ID and Client Secret
4. Update `values-okta-local.yaml` with real credentials

### GitHub

1. Register OAuth App: https://github.com/settings/developers
2. Set redirect URI: `http://localhost:8080/authn/github/callback`
3. Use `GITHUB_CLIENTID` and `GITHUB_CLIENTSECRET`

### GitLab

1. Create OAuth Application in GitLab settings
2. Set redirect URI: `http://localhost:8080/authn/gitlab/callback`
3. Use `GITLAB_CLIENTID` and `GITLAB_SECRET`

## Mock Servers

For testing OAuth flow without real providers:

```bash
# Deploy OAuth2 mock server
kubectl apply -f oauth2-mock-server.yaml

# Or Soluto OIDC server
kubectl apply -f oidc-server-mock.yaml
```

See individual YAML files for configuration details.
