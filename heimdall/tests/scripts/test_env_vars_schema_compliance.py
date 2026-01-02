#!/usr/bin/env python3
"""
Environment Variable Compliance Test

Validates that ALL environment variable references in templates, configs, and tests
match the canonical definitions in heimdall/data/env-vars.yaml.

This is a proper TDD/BDD test that will FAIL if:
1. Templates use incorrect/misspelled variable names
2. Templates use variables not defined in fixture (except whitelisted ones)
3. ConfigMaps reference invalid variables

Exit code 0 = all tests pass
Exit code 1 = tests failed
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Set
import yaml


# Whitelisted variables that are NOT Heimdall vars but are legitimate
WHITELIST = {
    'NODE_EXTRA_CA_CERTS',  # Node.js system var
    'CUSTOM_VAR',           # Test variable
    'BASE_URL',             # Test variable (not EXTERNAL_URL)
    'CLIENT_IP',            # Nginx variable
    'JSON_CONFIG',          # OAuth2 mock server
    'SPLUNK_API_TOKEN',     # Future/deprecated var
    'TENABLE_API_TOKEN',    # Future/deprecated var
    'NUXT_SITE_URL',        # Nuxt template var (not Heimdall)
    'YOUR_CLOUDFLARE_API_TOKEN',  # Documentation placeholder
    'YOUR_AWS_SECRET_KEY',        # Documentation placeholder
    'INSECURE_DEFAULT_CHANGE_ME',  # Template placeholder pattern
    'SELF_SIGNED_CERT_IN_CHAIN',   # Node.js error constant
    'UNABLE_TO_VERIFY_LEAF_SIGNATURE',  # Node.js error constant
}


def load_canonical_vars(fixture_path: Path) -> Dict[str, Dict]:
    """Load canonical environment variables from fixture."""
    with open(fixture_path, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)

    vars_dict = {}
    for var in data['environment_variables']:
        vars_dict[var['name']] = var

    return vars_dict


def extract_env_var_references(content: str) -> Set[str]:
    """Extract all environment variable references from content."""
    # Pattern: Uppercase words with underscores (typical env var pattern)
    pattern = r'\b([A-Z][A-Z0-9_]{2,})\b'

    matches = set()
    for match in re.finditer(pattern, content):
        var_name = match.group(1)
        # Filter out common non-env-var patterns
        if '_' in var_name and not var_name.startswith('HTTP_') and var_name not in ['TRUE', 'FALSE']:
            matches.add(var_name)

    return matches


def test_file_compliance(
    filepath: Path,
    canonical_vars: Dict[str, Dict],
    whitelist: Set[str]
) -> List[str]:
    """
    Test a file for compliance with canonical variable definitions.

    Returns:
        List of error messages (empty if compliant)
    """
    errors = []

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        refs = extract_env_var_references(content)
        canonical_names = set(canonical_vars.keys())

        for ref in refs:
            if ref not in canonical_names and ref not in whitelist:
                # Check if it's a partial match (like DATABASE_ prefix)
                if ref.endswith('_'):
                    continue  # Partial reference, likely in comment or pattern

                errors.append(f"Invalid variable: {ref} (not in fixture)")

    except Exception as e:
        errors.append(f"Error reading file: {e}")

    return errors


def test_oauth_naming_compliance(
    filepath: Path,
    content: str = None
) -> List[str]:
    """
    Test for incorrect OAuth naming patterns.

    Returns:
        List of error messages (empty if compliant)
    """
    errors = []

    if content is None:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

    # Check for incorrect patterns (these should NOT exist)
    incorrect_patterns = [
        (r'\bGITHUB_CLIENT_ID\b', 'GITHUB_CLIENT_ID should be GITHUB_CLIENTID'),
        (r'\bGITLAB_CLIENT_ID\b', 'GITLAB_CLIENT_ID should be GITLAB_CLIENTID'),
        (r'\bGOOGLE_CLIENT_ID\b', 'GOOGLE_CLIENT_ID should be GOOGLE_CLIENTID'),
        (r'\bOKTA_CLIENT_ID\b', 'OKTA_CLIENT_ID should be OKTA_CLIENTID'),
        (r'\bOIDC_CLIENT_ID\b', 'OIDC_CLIENT_ID should be OIDC_CLIENTID'),
        (r'\bGITHUB_CLIENT_SECRET\b', 'GITHUB_CLIENT_SECRET should be GITHUB_CLIENTSECRET'),
        (r'\bGITLAB_CLIENT_SECRET\b', 'GITLAB_CLIENT_SECRET should be GITLAB_SECRET'),
        (r'\bGOOGLE_CLIENT_SECRET\b', 'GOOGLE_CLIENT_SECRET should be GOOGLE_CLIENTSECRET'),
        (r'\bOKTA_CLIENT_SECRET\b', 'OKTA_CLIENT_SECRET should be OKTA_CLIENTSECRET'),
        (r'\bGITLAB_CLIENTSECRET\b', 'GITLAB_CLIENTSECRET should be GITLAB_SECRET'),
        (r'\bGITLAB_BASE_URL\b', 'GITLAB_BASE_URL should be GITLAB_BASEURL'),
        (r'\bLDAP_BIND_DN\b', 'LDAP_BIND_DN should be LDAP_BINDDN'),
        (r'\bLDAP_SEARCH_BASE\b', 'LDAP_SEARCH_BASE should be LDAP_SEARCHBASE'),
        (r'\bLDAP_SEARCH_FILTER\b', 'LDAP_SEARCH_FILTER should be LDAP_SEARCHFILTER'),
        (r'\bLDAP_MAIL_FIELD\b', 'LDAP_MAIL_FIELD should be LDAP_MAILFIELD'),
        (r'\bLDAP_NAME_FIELD\b', 'LDAP_NAME_FIELD should be LDAP_NAMEFIELD'),
        (r'\bOKTA_ISSUER\b(?!_URL)', 'OKTA_ISSUER should be OKTA_ISSUER_URL'),
        (r'\bOAUTH_[A-Z]+_', 'OAUTH_ prefix should not be used (button visibility determined by *_CLIENTID)'),
    ]

    for pattern, message in incorrect_patterns:
        if re.search(pattern, content):
            errors.append(message)

    return errors


def main():
    """Main test execution."""
    # Get base directory
    base_dir = Path(__file__).parent
    os.chdir(base_dir)

    print("🧪 Environment Variable Compliance Test Suite")
    print("=" * 60)

    # Load canonical fixture
    fixture_path = base_dir / 'heimdall/data/env-vars.yaml'
    if not fixture_path.exists():
        print(f"❌ FATAL: Fixture not found: {fixture_path}", file=sys.stderr)
        return 1

    canonical_vars = load_canonical_vars(fixture_path)
    print(f"✅ Loaded {len(canonical_vars)} canonical variables from fixture")
    print(f"✅ Whitelisted {len(WHITELIST)} non-Heimdall variables")
    print()

    # Files to test
    test_patterns = [
        ('Templates', 'heimdall/templates/**/*.yaml'),
        ('Config Files', 'heimdall/env/**/*.yaml'),
        ('Tests', 'heimdall/tests/**/*.yaml'),
        ('Documentation', 'docs/content/**/*.md'),
    ]

    total_files = 0
    total_errors = 0
    failed_files = []

    for category, pattern in test_patterns:
        print(f"📋 Testing {category}...")
        files = list(base_dir.glob(pattern))
        category_errors = 0

        for filepath in files:
            if not filepath.is_file():
                continue

            # Skip fixture itself and generated files
            if 'fixtures/env-vars.yaml' in str(filepath):
                continue

            total_files += 1

            # Test compliance
            errors = test_file_compliance(filepath, canonical_vars, WHITELIST)

            # Test OAuth naming
            oauth_errors = test_oauth_naming_compliance(filepath)
            errors.extend(oauth_errors)

            if errors:
                total_errors += len(errors)
                category_errors += 1
                failed_files.append((filepath, errors))

        if category_errors == 0:
            print(f"   ✅ All {len(files)} {category.lower()} compliant")
        else:
            print(f"   ❌ {category_errors} files with issues")

    print()
    print("=" * 60)

    if total_errors == 0:
        print("✅ ALL TESTS PASSED!")
        print(f"   Validated {total_files} files")
        print(f"   All environment variables match canonical fixture")
        return 0
    else:
        print(f"❌ TESTS FAILED: {total_errors} issues in {len(failed_files)} files")
        print()
        for filepath, errors in failed_files:
            rel_path = filepath.relative_to(base_dir)
            print(f"\n📝 {rel_path}")
            for error in errors:
                print(f"   - {error}")

        print()
        print("=" * 60)
        print("Fix these issues by:")
        print("1. Updating files to use correct variable names from fixture")
        print("2. Running: python3 fix-all-env-vars.py")
        print("3. Re-running this test")

        return 1


if __name__ == '__main__':
    sys.exit(main())
