#!/usr/bin/env python3
"""
Environment Variable Validator

Validates that all environment variable references across the Heimdall Helm chart
match the canonical definitions in heimdall/data/env-vars.yaml.

This ensures:
- No incorrect/misspelled variable names
- Required pairs are validated (e.g., GITHUB_CLIENTID requires GITHUB_CLIENTSECRET)
- All references use correct names
- Documentation examples are accurate
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple
import yaml


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
    # Must be at least 3 chars, contain underscore, all uppercase
    pattern = r'\b([A-Z][A-Z0-9_]{2,})\b'

    matches = set()
    for match in re.finditer(pattern, content):
        var_name = match.group(1)
        # Filter out common non-env-var patterns
        if '_' in var_name and not var_name.startswith('HTTP_') and var_name not in ['TRUE', 'FALSE']:
            matches.add(var_name)

    return matches


def find_invalid_references(
    file_path: Path,
    canonical_vars: Dict[str, Dict],
    content: str = None
) -> List[Tuple[str, str]]:
    """
    Find invalid environment variable references in a file.

    Returns:
        List of (invalid_var, suggested_correction) tuples
    """
    if content is None:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

    refs = extract_env_var_references(content)
    canonical_names = set(canonical_vars.keys())

    invalid = []

    for ref in refs:
        if ref not in canonical_names:
            # Try to find a similar correct variable
            suggestion = find_similar_var(ref, canonical_names)
            invalid.append((ref, suggestion or 'UNKNOWN'))

    return invalid


def find_similar_var(incorrect: str, canonical: Set[str]) -> str:
    """Find the most similar canonical variable name."""
    # Try exact prefix match
    for correct in canonical:
        if incorrect.startswith(correct) or correct.startswith(incorrect):
            return correct

    # Try common incorrect patterns
    corrections = {
        'OAUTH_': '',  # Remove OAUTH_ prefix
        '_CLIENT_ID': '_CLIENTID',
        '_CLIENT_SECRET': '_CLIENTSECRET',
    }

    for pattern, replacement in corrections.items():
        if pattern in incorrect:
            candidate = incorrect.replace(pattern, replacement)
            if candidate in canonical:
                return candidate

    return None


def validate_required_pairs(
    file_path: Path,
    canonical_vars: Dict[str, Dict],
    content: str = None
) -> List[str]:
    """
    Validate that variables requiring pairs are properly configured.

    For example: GITHUB_CLIENTID requires GITHUB_CLIENTSECRET

    Returns:
        List of validation error messages
    """
    if content is None:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

    refs = extract_env_var_references(content)
    errors = []

    for var_name in refs:
        if var_name in canonical_vars:
            var_def = canonical_vars[var_name]
            if 'required_pair' in var_def:
                required_pair = var_def['required_pair']
                if required_pair not in refs:
                    errors.append(
                        f"{var_name} requires {required_pair} to be set"
                    )

    return errors


def scan_directory(
    base_dir: Path,
    patterns: List[str],
    canonical_vars: Dict[str, Dict],
    check_pairs: bool = False
) -> Dict[str, List]:
    """
    Scan directory for files and validate environment variable references.

    Returns:
        Dictionary mapping file paths to issues found
    """
    results = {}

    for pattern in patterns:
        for filepath in base_dir.glob(pattern):
            if not filepath.is_file():
                continue

            try:
                invalid_refs = find_invalid_references(filepath, canonical_vars)

                issues = []
                if invalid_refs:
                    issues.extend([
                        f"Invalid: {inv} (should be: {sugg})"
                        for inv, sugg in invalid_refs
                    ])

                if check_pairs:
                    pair_errors = validate_required_pairs(filepath, canonical_vars)
                    issues.extend(pair_errors)

                if issues:
                    results[str(filepath.relative_to(base_dir))] = issues

            except Exception as e:
                print(f"⚠️  Error processing {filepath}: {e}", file=sys.stderr)

    return results


def main():
    """Main execution."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Validate environment variable names against canonical fixture'
    )
    parser.add_argument(
        '--check-pairs',
        action='store_true',
        help='Check that required pairs are set together'
    )
    parser.add_argument(
        '--show-canonical',
        action='store_true',
        help='Show all canonical environment variables'
    )

    args = parser.parse_args()

    # Get base directory
    base_dir = Path(__file__).parent
    os.chdir(base_dir)

    print("🔍 Heimdall Environment Variable Validator")
    print("=" * 60)

    # Load canonical fixture
    fixture_path = base_dir / 'heimdall/data/env-vars.yaml'
    if not fixture_path.exists():
        print(f"❌ ERROR: Fixture not found: {fixture_path}", file=sys.stderr)
        return 1

    canonical_vars = load_canonical_vars(fixture_path)
    print(f"📖 Loaded {len(canonical_vars)} canonical environment variables")

    if args.show_canonical:
        print("\n📋 Canonical Environment Variables:")
        for name in sorted(canonical_vars.keys()):
            var_def = canonical_vars[name]
            print(f"   - {name} ({var_def['category']})")
        print()

    # Scan patterns
    patterns = [
        'heimdall/templates/**/*.yaml',
        'heimdall/tests/**/*.yaml',
        'heimdall/env/**/*.yaml',
        'docs/content/**/*.md',
    ]

    print("\n🔎 Scanning files for invalid references...")
    results = scan_directory(base_dir, patterns, canonical_vars, args.check_pairs)

    # Report results
    if not results:
        print("\n✅ No issues found! All environment variable references are valid.")
        return 0

    print(f"\n❌ Found issues in {len(results)} file(s):")
    for filepath, issues in sorted(results.items()):
        print(f"\n📝 {filepath}")
        for issue in issues:
            print(f"   - {issue}")

    print("\n" + "=" * 60)
    print(f"❌ Validation failed: {len(results)} file(s) with issues")

    return 1


if __name__ == '__main__':
    sys.exit(main())
