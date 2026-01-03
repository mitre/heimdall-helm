# GitHub Repository Secrets Configuration

This document lists the secrets that should be configured in GitHub repository settings for CI/CD workflows.

## How to Add Secrets

1. Go to: `https://github.com/mitre/heimdall-helm/settings/secrets/actions`
2. Click **New repository secret**
3. Add each secret below

## Required Secrets for OAuth Testing

### Okta OAuth Testing

Used by integration tests to verify Okta OAuth flow:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `OKTA_DOMAIN` | Your Okta developer domain | `trial-8371755.okta.com` |
| `OKTA_CLIENT_ID` | Okta Web Application Client ID | `0oayuh2ofdfcXHu95697` |
| `OKTA_CLIENT_SECRET` | Okta Web Application Client Secret | `9lbqSAxG...` (keep secret!) |

**Okta App Configuration:**
- Application Type: Web Application
- Redirect URI: `https://heimdall.example.com/authn/okta_callback` (update for CI environment)
- Grant Types: Authorization Code, Refresh Token

### GitHub OAuth Testing (Future)

| Secret Name | Description |
|-------------|-------------|
| `GITHUB_CLIENT_ID` | GitHub OAuth App Client ID |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth App Client Secret |

### GitLab OAuth Testing (Future)

| Secret Name | Description |
|-------------|-------------|
| `GITLAB_CLIENT_ID` | GitLab OAuth Application ID |
| `GITLAB_CLIENT_SECRET` | GitLab OAuth Application Secret |

## Usage in Workflows

Secrets are accessed in GitHub Actions workflows via `${{ secrets.SECRET_NAME }}`:

```yaml
name: Test OAuth Integration

on: [push, pull_request]

jobs:
  test-okta:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup kind cluster
        uses: helm/kind-action@v1

      - name: Test Okta OAuth
        run: |
          helm install heimdall ./heimdall \
            -n heimdall-test \
            -f heimdall/tests/integration/values-okta-real.yaml \
            --set heimdall.config.OKTA_DOMAIN=${{ secrets.OKTA_DOMAIN }} \
            --set heimdall.config.OKTA_CLIENTID=${{ secrets.OKTA_CLIENT_ID }} \
            --set heimdall.secrets.OKTA_CLIENTSECRET=${{ secrets.OKTA_CLIENT_SECRET }}
```

## Security Notes

- ✅ Secrets are encrypted at rest in GitHub
- ✅ Secrets are redacted from logs automatically
- ✅ Only accessible to workflows in this repository
- ❌ **Never commit secrets to git history**
- ❌ **Never echo secrets in workflow logs**

## Rotating Secrets

When rotating OAuth credentials:

1. Update secret in GitHub repository settings
2. Update corresponding OAuth application (Okta/GitHub/GitLab)
3. Ensure redirect URIs match deployment environment
4. Test workflow runs with new credentials

## Current Secret Status

| Secret | Configured | Last Verified | Notes |
|--------|-----------|---------------|-------|
| `OKTA_DOMAIN` | ❌ | - | Add in repository settings |
| `OKTA_CLIENT_ID` | ❌ | - | Add in repository settings |
| `OKTA_CLIENT_SECRET` | ❌ | - | Add in repository settings |

## Adding Your Okta Secrets

**Current values for your Okta developer account:**

```bash
# DO NOT commit these values - add to GitHub Secrets UI instead!
OKTA_DOMAIN="trial-8371755.okta.com"
OKTA_CLIENT_ID="0oayuh2ofdfcXHu95697"
OKTA_CLIENT_SECRET="9lbqSAxGNJQTFzbYINBmgtBJbdVwvqFoWn_fZvPOLinOP2MsP2uDk6aoZvWArMz4"
```

**Steps:**
1. Go to https://github.com/mitre/heimdall-helm/settings/secrets/actions
2. Click "New repository secret"
3. Name: `OKTA_DOMAIN`, Value: `trial-8371755.okta.com`
4. Click "New repository secret"
5. Name: `OKTA_CLIENT_ID`, Value: `0oayuh2ofdfcXHu95697`
6. Click "New repository secret"
7. Name: `OKTA_CLIENT_SECRET`, Value: `9lbqSAxGNJQTFzbYINBmgtBJbdVwvqFoWn_fZvPOLinOP2MsP2uDk6aoZvWArMz4`

## Verification

After adding secrets, verify they're configured:

```bash
# This will show secret names (not values)
gh secret list
```

Expected output:
```
OKTA_CLIENT_ID      Updated 2026-01-03
OKTA_CLIENT_SECRET  Updated 2026-01-03
OKTA_DOMAIN         Updated 2026-01-03
```
