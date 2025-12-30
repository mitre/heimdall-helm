#!/bin/bash
# =============================================================================
# Heimdall Helm Chart Secrets Generator
# =============================================================================
# Generates random cryptographically secure secrets for Heimdall deployment
# Following Vulcan chart pattern for consistency across MITRE SAF charts
#
# Usage:
#   ./generate-heimdall-secrets.sh
#
# Output:
#   heimdall/env/heimdall-secrets.yaml (gitignored)
#
# Notes:
#   - File permissions: 0600 (owner read/write only)
#   - Secrets are idempotent - won't overwrite existing values
#   - Delete heimdall/env/heimdall-secrets.yaml to regenerate all secrets
#
# Security:
#   - Uses openssl rand for cryptographically secure randomness
#   - JWT_SECRET: 128 chars (64 bytes hex)
#   - API_KEY_SECRET: 66 chars (33 bytes hex)
#   - DATABASE_PASSWORD: 66 chars (33 bytes hex)
#   - ADMIN_PASSWORD: 32 chars (16 bytes hex with prefix)
# =============================================================================

set -e  # Exit on error

# Color codes for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
NC="\033[0m"  # No Color
UNICORN="\U1F984"

SECRETS_FILE="heimdall/env/heimdall-secrets.yaml"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}   Heimdall Secrets Generator${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
}

print_footer() {
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}${UNICORN}  Secret generation complete!${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. Review generated secrets: cat ${SECRETS_FILE}"
  echo "  2. Install Heimdall: helm install heimdall ./heimdall -n heimdall --create-namespace"
  echo "  3. Or use quickstart: ./start-heimdall.sh"
  echo ""
  echo -e "${YELLOW}Security reminders:${NC}"
  echo "  - Secrets file has 0600 permissions (owner read/write only)"
  echo "  - File is gitignored - never commit to version control"
  echo "  - For production, consider External Secrets Operator or Sealed Secrets"
  echo ""
}

generate_secret_if_missing() {
  local key=$1
  local length=$2
  local description=$3

  if ! grep -qF "${key}:" "${SECRETS_FILE}"; then
    echo -e "${RED}Generating ${description}...${NC}"
    local value=$(openssl rand -hex "${length}")
    echo "${key}: ${value}" >> "${SECRETS_FILE}"
  else
    echo -e "${GREEN}${description} already exists, skipping${NC} ${UNICORN}"
  fi
}

# =============================================================================
# Main Script
# =============================================================================

print_header

# Check if directory exists
if [ ! -d "heimdall/env" ]; then
  echo -e "${RED}Error: heimdall/env directory not found${NC}"
  echo "Please run this script from the repository root (heimdall-helm/)."
  exit 1
fi

echo "Checking for existing secrets file..."
echo ""

if [ -f "${SECRETS_FILE}" ]; then
  echo -e "${GREEN}${SECRETS_FILE} already exists${NC}"
  echo -e "${YELLOW}Existing secrets will be preserved. Only missing secrets will be generated.${NC}"
  echo -e "${RED}To regenerate all secrets, delete ${SECRETS_FILE} and re-run this script.${NC}"
  echo ""
else
  echo -e "${YELLOW}Creating new secrets file...${NC}"
  # Create file with secure permissions (owner read/write only)
  (umask 077; touch "${SECRETS_FILE}")
  chmod 600 "${SECRETS_FILE}"
  echo "# Heimdall Secrets" > "${SECRETS_FILE}"
  echo "# Generated: $(date)" >> "${SECRETS_FILE}"
  echo "# WARNING: Keep this file secure and never commit to Git" >> "${SECRETS_FILE}"
  echo "" >> "${SECRETS_FILE}"
fi

# Generate required secrets (following schema requirements)
echo "Generating missing secrets..."
echo ""

# JWT Secret (minimum 64 chars, using 128 for extra security)
generate_secret_if_missing "JWT_SECRET" 64 "JWT signing secret (128 chars)"

# API Key Secret (minimum 33 chars, using 66 for consistency)
generate_secret_if_missing "API_KEY_SECRET" 33 "API key secret (66 chars)"

# Database Password
generate_secret_if_missing "DATABASE_PASSWORD" 33 "Database password (66 chars)"

# Admin Password (if not using external auth)
# Note: Using alphanumeric for better compatibility with password validators
if ! grep -qF "ADMIN_PASSWORD:" "${SECRETS_FILE}"; then
  echo -e "${RED}Generating admin password...${NC}"
  # Generate strong password with mix of chars
  ADMIN_PASS="Admin_$(openssl rand -hex 16)"
  echo "ADMIN_PASSWORD: ${ADMIN_PASS}" >> "${SECRETS_FILE}"
else
  echo -e "${GREEN}Admin password already exists, skipping${NC} ${UNICORN}"
fi

echo ""
echo "Optional secrets (leave blank if not using these features):"
echo ""

# OAuth/OIDC Client Secrets (optional - user should fill these manually if needed)
if ! grep -qF "# OAuth/OIDC Secrets" "${SECRETS_FILE}"; then
  cat >> "${SECRETS_FILE}" << 'EOF'

# =============================================================================
# OAuth/OIDC Client Secrets (Optional)
# =============================================================================
# Uncomment and fill in these values if using OAuth/OIDC authentication
# Non-sensitive OAuth config (URLs, Client IDs) goes in heimdallconfig.yaml

# GitHub OAuth
# GITHUB_CLIENT_SECRET: ""

# GitLab OAuth
# GITLAB_CLIENT_SECRET: ""

# Google OAuth
# GOOGLE_CLIENT_SECRET: ""

# Okta OIDC
# OKTA_CLIENT_SECRET: ""

# Generic OIDC Provider
# OIDC_CLIENT_SECRET: ""

# =============================================================================
# LDAP Credentials (Optional)
# =============================================================================
# Uncomment and fill in these values if using LDAP authentication
# Non-sensitive LDAP config goes in heimdallconfig.yaml

# LDAP_BIND_DN: "cn=admin,dc=example,dc=com"
# LDAP_PASSWORD: ""

# =============================================================================
# Database SSL Certificates (Optional)
# =============================================================================
# Uncomment and paste certificate content if using SSL with custom CA
# Use literal block scalar (|) for multi-line certificates

# DATABASE_SSL_KEY: |
#   -----BEGIN PRIVATE KEY-----
#   ...
#   -----END PRIVATE KEY-----

# DATABASE_SSL_CERT: |
#   -----BEGIN CERTIFICATE-----
#   ...
#   -----END CERTIFICATE-----

# DATABASE_SSL_CA: |
#   -----BEGIN CERTIFICATE-----
#   ...
#   -----END CERTIFICATE-----

# =============================================================================
# External Integration Secrets (Optional)
# =============================================================================
# Uncomment and fill in if using external integrations
# Non-sensitive config (URLs) goes in heimdallconfig.yaml

# TENABLE_API_TOKEN: ""
# SPLUNK_API_TOKEN: ""
EOF
fi

print_footer
