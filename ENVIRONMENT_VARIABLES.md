# Heimdall Environment Variables

This document lists all environment variables that can be used to configure Heimdall.

**Source**: Heimdall2 application source code (`apps/backend/src/`)
**Last Updated**: 2026-01-02

## ⚠️ Critical OAuth/OIDC Naming Issue

Heimdall has **inconsistent environment variable naming** for OAuth client secrets:

| Provider | Client ID Variable | Client Secret Variable | Consistency |
|----------|-------------------|----------------------|-------------|
| GitHub | `GITHUB_CLIENTID` | `GITHUB_CLIENTSECRET` | ✅ Consistent |
| GitLab | `GITLAB_CLIENTID` | `GITLAB_SECRET` | ❌ Different pattern |
| Google | `GOOGLE_CLIENTID` | `GOOGLE_CLIENTSECRET` | ✅ Consistent |
| Okta | `OKTA_CLIENTID` | `OKTA_CLIENTSECRET` | ✅ Consistent |
| OIDC | `OIDC_CLIENTID` | `OIDC_CLIENT_SECRET` | ❌ Has underscore |

**OAuth Button Visibility**: Heimdall checks for `{PROVIDER}_CLIENTID` (exactly one underscore) to determine which OAuth buttons to display. Using `{PROVIDER}_CLIENT_ID` (two underscores) will prevent the button from appearing.

---

## Node.js Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `NODE_ENV` | Node.js runtime environment | - | `production`, `development`, `test` |
| `PORT` | Port that the application listens on | `3000` | `8080` |

---

## Application Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `EXTERNAL_URL` | Base URL for OAuth callbacks | - | `https://heimdall.example.com` |
| `MAX_FILE_UPLOAD_SIZE` | Maximum evaluation upload size in MB | `50` | `100` |

### Admin User Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `ADMIN_EMAIL` | Administrator email address | `admin@heimdall.local` | `admin@example.com` |
| `ADMIN_PASSWORD` | Administrator password | Auto-generated on first run | `secure-password-123` |
| `ADMIN_USES_EXTERNAL_AUTH` | Admin uses OAuth/OIDC login | `false` | `true`, `false` |

### Authentication Settings

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `LOCAL_LOGIN_DISABLED` | Disable local username/password login | `false` | `true`, `false` |
| `REGISTRATION_DISABLED` | Disable user self-registration | `false` | `true`, `false` |
| `ONE_SESSION_PER_USER` | Allow only one session per user | `false` | `true`, `false` |

### JWT Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `JWT_SECRET` | JSON Web Token signing secret | - | 64+ character random string |
| `JWT_EXPIRE_TIME` | Token expiration time | `60s` | `25m`, `1h`, `7d` |
| `API_KEY_SECRET` | API key token secret | - | 32+ character random string |

### Classification Banner

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `CLASSIFICATION_BANNER_TEXT` | Sensitivity classification banner text | (none) | `UNCLASSIFIED`, `SECRET` |
| `CLASSIFICATION_BANNER_TEXT_COLOR` | Banner text color | `white` | `white`, `black`, `#FF0000` |
| `CLASSIFICATION_BANNER_COLOR` | Banner background color | `red` | `red`, `green`, `#00FF00` |

---

## Database Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_HOST` | PostgreSQL hostname | `127.0.0.1` | `postgres.example.com` |
| `DATABASE_PORT` | PostgreSQL port | `5432` | `5432` |
| `DATABASE_NAME` | Database name | `heimdall-server-{NODE_ENV}` | `heimdall_production` |
| `DATABASE_USERNAME` | Database username | `postgres` | `heimdall_app` |
| `DATABASE_PASSWORD` | Database password | (empty) | `secure-db-password` |

### Database SSL/TLS

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `DATABASE_SSL` | Enable SSL for database connection | `false` | `true`, `false` |
| `DATABASE_SSL_INSECURE` | Ignore SSL certificate validation (security risk) | `false` | `true`, `false` |
| `DATABASE_SSL_KEY` | SSL key file path or content | - | `/path/to/client-key.pem` |
| `DATABASE_SSL_CERT` | SSL certificate file path or content | - | `/path/to/client-cert.pem` |
| `DATABASE_SSL_CA` | SSL CA certificate file path or content | - | `/path/to/ca-cert.pem` |

---

## Authentication Providers

### GitHub OAuth

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `GITHUB_CLIENTID` | GitHub OAuth client ID | ✅ | `abc123def456` |
| `GITHUB_CLIENTSECRET` | GitHub OAuth client secret | ✅ | `secret_key_here` |
| `GITHUB_ENTERPRISE_INSTANCE_BASE_URL` | GitHub Enterprise base URL | - | `https://github.company.com/` |
| `GITHUB_ENTERPRISE_INSTANCE_API_URL` | GitHub Enterprise API URL | - | `https://github.company.com/api/v3/` |

**Note**: Button visibility determined by presence of `GITHUB_CLIENTID`.

---

### GitLab OAuth

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `GITLAB_CLIENTID` | GitLab OAuth client ID | ✅ | `xyz789abc123` |
| `GITLAB_SECRET` | GitLab OAuth client secret | ✅ | `secret_key_here` |
| `GITLAB_BASEURL` | GitLab instance URL | - | `https://gitlab.com` (default) |

**⚠️ Naming Inconsistency**: Uses `GITLAB_SECRET`, not `GITLAB_CLIENTSECRET`.

**Note**: Button visibility determined by presence of `GITLAB_CLIENTID`.

---

### Google OAuth

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `GOOGLE_CLIENTID` | Google OAuth client ID | ✅ | `123456.apps.googleusercontent.com` |
| `GOOGLE_CLIENTSECRET` | Google OAuth client secret | ✅ | `secret_key_here` |

**Note**: Button visibility determined by presence of `GOOGLE_CLIENTID`.

---

### Okta OAuth/OIDC

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `OKTA_CLIENTID` | Okta client ID | ✅ | `0oa1b2c3d4e5f6g7h8` |
| `OKTA_CLIENTSECRET` | Okta client secret | ✅ | `secret_key_here` |
| `OKTA_DOMAIN` | Okta domain (for auto-discovery) | - | `dev-12345.okta.com` |
| `OKTA_ISSUER_URL` | Okta issuer URL | - | `https://dev-12345.okta.com` |
| `OKTA_AUTHORIZATION_URL` | Okta authorization endpoint | - | `https://dev-12345.okta.com/oauth2/v1/authorize` |
| `OKTA_TOKEN_URL` | Okta token endpoint | - | `https://dev-12345.okta.com/oauth2/v1/token` |
| `OKTA_USER_INFO_URL` | Okta userinfo endpoint | - | `https://dev-12345.okta.com/oauth2/v1/userinfo` |
| `OKTA_USE_HTTPS_PROXY` | Use HTTPS proxy for Okta requests | `false` | `true`, `false` |

**Note**: Either `OKTA_DOMAIN` or all manual endpoints must be set. Button visibility determined by presence of `OKTA_CLIENTID`.

---

### Generic OIDC Provider

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `OIDC_NAME` | Display name for OIDC provider | - | `Auth0`, `Keycloak` |
| `OIDC_CLIENTID` | OIDC client ID | ✅ | `your-client-id` |
| `OIDC_CLIENT_SECRET` | OIDC client secret | ✅ | `secret_key_here` |
| `OIDC_ISSUER` | OIDC issuer URL | ✅ | `https://auth.example.com` |
| `OIDC_AUTHORIZATION_URL` | OIDC authorization endpoint | ✅ | `https://auth.example.com/authorize` |
| `OIDC_TOKEN_URL` | OIDC token endpoint | ✅ | `https://auth.example.com/oauth/token` |
| `OIDC_USER_INFO_URL` | OIDC userinfo endpoint | ✅ | `https://auth.example.com/userinfo` |

**⚠️ Naming Inconsistency**: Uses `OIDC_CLIENT_SECRET` (with underscore before SECRET), unlike other providers.

**Note**: Button visibility determined by presence of `OIDC_CLIENTID`.

#### OIDC Advanced Options

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `OIDC_USES_PKCE_PLAIN` | Enable PKCE with plain code challenge | `false` | `true`, `false` |
| `OIDC_USES_PKCE_S256` | Enable PKCE with S256 code challenge | `false` | `true`, `false` |
| `OIDC_USES_VERIFIED_EMAIL` | Require verified email from OIDC provider | `true` | `true`, `false` |
| `OIDC_EXTERNAL_GROUPS` | Enable external group synchronization | `false` | `true`, `false` |
| `OIDC_USE_HTTPS_PROXY` | Use HTTPS proxy for OIDC requests | `false` | `true`, `false` |

---

### LDAP Authentication

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| `LDAP_ENABLED` | Enable LDAP authentication | ✅ | `true`, `false` |
| `LDAP_HOST` | LDAP server hostname | ✅ | `ldap.example.com` |
| `LDAP_PORT` | LDAP server port | - | `389` (LDAP), `636` (LDAPS) |
| `LDAP_BINDDN` | Bind DN for LDAP authentication | ✅ | `cn=admin,dc=example,dc=com` |
| `LDAP_PASSWORD` | Password for bind DN | ✅ | `ldap-bind-password` |
| `LDAP_SEARCHBASE` | LDAP search base DN | ✅ | `ou=users,dc=example,dc=com` |
| `LDAP_SEARCHFILTER` | LDAP search filter | - | `(uid={{username}})`, `(sAMAccountName={{username}})` |
| `LDAP_NAMEFIELD` | LDAP attribute for user's full name | `name` | `cn`, `displayName` |
| `LDAP_MAILFIELD` | LDAP attribute for user's email | `mail` | `mail`, `userPrincipalName` |

#### LDAP SSL/TLS

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `LDAP_SSL` | Enable SSL/TLS for LDAP | `false` | `true`, `false` |
| `LDAP_SSL_INSECURE` | Ignore SSL certificate validation (security risk) | `false` | `true`, `false` |
| `LDAP_SSL_CA` | SSL CA certificate file path or content | - | `/path/to/ca-cert.pem` |

---

## External Integrations

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SPLUNK_HOST_URL` | Splunk integration URL | (none) | `https://splunk.example.com` |
| `TENABLE_HOST_URL` | Tenable.SC integration URL | (none) | `https://tenable.example.com` |
| `FORCE_TENABLE_FRONTEND` | Force Tenable-specific UI features | `false` | `true`, `false` |

---

## Proxy Configuration

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `HTTPS_PROXY` | HTTPS proxy for external requests | (none) | `http://proxy.example.com:8080` |

**Note**: Used by OIDC and Okta OAuth when `*_USE_HTTPS_PROXY` is enabled.

---

## OAuth Callback URL Construction

All OAuth providers construct callback URLs as:
```
{EXTERNAL_URL}/authn/{provider}_callback
```

**Examples**:
- GitHub: `https://heimdall.example.com/authn/github/callback`
- GitLab: `https://heimdall.example.com/authn/gitlab/callback`
- Google: `https://heimdall.example.com/authn/google/callback`
- Okta: `https://heimdall.example.com/authn/okta/callback`
- OIDC: `https://heimdall.example.com/authn/oidc_callback`

**⚠️ Critical**: `EXTERNAL_URL` must be the **base URL only** without `/authn` path. Setting `EXTERNAL_URL=https://example.com/authn` will result in duplicated paths: `https://example.com/authn/authn/oidc_callback`.

---

## OAuth Button Visibility Logic

**Location**: `apps/backend/src/config/config.service.ts:enabledOauthStrategies()`

Heimdall determines which OAuth login buttons to display by checking for client ID variables:

```typescript
supportedOauth.forEach((oauthStrategy) => {
  if (this.get(`${oauthStrategy.toUpperCase()}_CLIENTID`)) {
    enabledOauth.push(oauthStrategy);
  }
});
```

**Pattern**: `{PROVIDER}_CLIENTID` (exactly one underscore)

**Supported providers**: `github`, `gitlab`, `google`, `okta`, `oidc`

**Examples**:
- ✅ `GITHUB_CLIENTID` → GitHub button appears
- ✅ `OIDC_CLIENTID` → OIDC button appears
- ❌ `GITHUB_CLIENT_ID` → Button **will not appear** (two underscores)
- ❌ `GITHUBCLIENTID` → Button **will not appear** (no underscore)

---

## Known Issues

### 1. Inconsistent Client Secret Naming

**Issue**: OAuth client secrets use different naming patterns.

**Affected Variables**:
- `GITLAB_SECRET` (should be `GITLAB_CLIENTSECRET`)
- `OIDC_CLIENT_SECRET` (should be `OIDC_CLIENTSECRET`)

**Impact**: Confusing for users; breaks naming consistency.

**Workaround**: Use the actual variable names documented in this file.

**Status**: Issue to be reported to Heimdall2 upstream.

### 2. .env-example Documentation Bug

**Issue**: `apps/backend/.env-example` documents `GITLAB_CLIENTSECRET` but code uses `GITLAB_SECRET`.

**Impact**: Following `.env-example` will cause GitLab OAuth to fail.

**Workaround**: Use `GITLAB_SECRET` as documented in this file.

**Status**: Issue to be reported to Heimdall2 upstream.

---

## Configuration Examples

### Local Development (Docker Compose)

```bash
NODE_ENV=development
PORT=3000
ADMIN_EMAIL=admin@localhost
DATABASE_HOST=postgres
DATABASE_PORT=5432
DATABASE_NAME=heimdall_development
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=postgres
JWT_SECRET=your-64-character-random-secret-here
```

### Production with External PostgreSQL

```bash
NODE_ENV=production
PORT=3000
EXTERNAL_URL=https://heimdall.example.com
DATABASE_HOST=heimdall-db.abc123.us-east-1.rds.amazonaws.com
DATABASE_PORT=5432
DATABASE_NAME=heimdall_production
DATABASE_USERNAME=heimdall_app
DATABASE_PASSWORD=secure-db-password
DATABASE_SSL=true
JWT_SECRET=your-64-character-random-secret-here
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=secure-admin-password
```

### Production with OIDC (Okta)

```bash
NODE_ENV=production
EXTERNAL_URL=https://heimdall.example.com
LOCAL_LOGIN_DISABLED=true
OIDC_NAME=Okta
OIDC_CLIENTID=0oa1b2c3d4e5f6g7h8
OIDC_CLIENT_SECRET=your-oidc-client-secret
OIDC_ISSUER=https://dev-12345.okta.com
OIDC_AUTHORIZATION_URL=https://dev-12345.okta.com/oauth2/v1/authorize
OIDC_TOKEN_URL=https://dev-12345.okta.com/oauth2/v1/token
OIDC_USER_INFO_URL=https://dev-12345.okta.com/oauth2/v1/userinfo
```

### Production with Multiple OAuth Providers

```bash
NODE_ENV=production
EXTERNAL_URL=https://heimdall.example.com

# GitHub OAuth
GITHUB_CLIENTID=abc123def456
GITHUB_CLIENTSECRET=github-secret-here

# GitLab OAuth
GITLAB_CLIENTID=xyz789abc123
GITLAB_SECRET=gitlab-secret-here

# OIDC (Okta)
OIDC_NAME=Okta
OIDC_CLIENTID=0oa1b2c3d4e5f6g7h8
OIDC_CLIENT_SECRET=oidc-secret-here
OIDC_ISSUER=https://dev-12345.okta.com
OIDC_AUTHORIZATION_URL=https://dev-12345.okta.com/oauth2/v1/authorize
OIDC_TOKEN_URL=https://dev-12345.okta.com/oauth2/v1/token
OIDC_USER_INFO_URL=https://dev-12345.okta.com/oauth2/v1/userinfo
```

---

## Testing OAuth Configuration

Verify OAuth providers are enabled:

```bash
curl http://localhost:3000/api/server | jq '.enabledOAuth'
```

**Expected output** (when OIDC and GitHub are configured):
```json
["github", "oidc"]
```

If a provider doesn't appear in this array, check that the `{PROVIDER}_CLIENTID` variable is set correctly.

---

## References

- **Heimdall2 Source**: https://github.com/mitre/heimdall2
- **Environment Config Example**: `apps/backend/.env-example`
- **OAuth Strategies**: `apps/backend/src/authn/*.strategy.ts`
- **Config Service**: `apps/backend/src/config/config.service.ts`
- **Helm Chart**: https://github.com/mitre/heimdall-helm
