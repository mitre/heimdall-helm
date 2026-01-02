#!/usr/bin/env python3
"""
Systematic Environment Variable Name Fixer

Uses heimdall/data/env-vars.yaml (canonical source of truth)
to systematically fix incorrect environment variable names across the
entire Heimdall Helm chart.

This ensures consistency between documentation, templates, tests, and config files.
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple
import yaml

# Files to process
TARGET_PATTERNS = [
    'heimdall/templates/**/*.yaml',
    'heimdall/tests/**/*.yaml',
    'heimdall/env/**/*.yaml',
    'docs/content/**/*.md',
]

# Files to exclude
EXCLUDE_PATTERNS = [
    '.git',
    'node_modules',
    '.beads',
    'charts',
    'heimdall/data/env-vars.yaml',  # Don't modify source of truth
]


def load_canonical_vars(fixture_path: Path) -> Set[str]:
    """Load canonical environment variable names from fixture."""
    with open(fixture_path, 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)

    canonical_vars = set()
    for var in data['environment_variables']:
        canonical_vars.add(var['name'])

    return canonical_vars


def build_correction_map(correct_vars: Set[str]) -> Dict[str, str]:
    """
    Build a mapping of incorrect -> correct variable names.

    Common incorrect patterns:
    - GITLAB_BASE_URL -> GITLAB_BASEURL
    - LDAP_BIND_DN -> LDAP_BINDDN
    - LDAP_SEARCH_BASE -> LDAP_SEARCHBASE
    - LDAP_SEARCH_FILTER -> LDAP_SEARCHFILTER
    - LDAP_MAIL_FIELD -> LDAP_MAILFIELD
    - LDAP_NAME_FIELD -> LDAP_NAMEFIELD
    - OKTA_ISSUER -> OKTA_ISSUER_URL
    - OAUTH_* -> remove prefix
    - *_CLIENT_ID -> *_CLIENTID
    - *_CLIENT_SECRET -> *_CLIENTSECRET (except OIDC_CLIENT_SECRET)
    """
    corrections = {}

    # Build corrections based on canonical variable names
    for correct in correct_vars:
        # OAuth prefix pattern (OAUTH_GITHUB_CLIENTID -> GITHUB_CLIENTID)
        if not correct.startswith('OAUTH_'):
            oauth_variant = f"OAUTH_{correct}"
            corrections[oauth_variant] = correct

        # CLIENTID variations (without underscore is correct)
        if 'CLIENTID' in correct:
            # GITHUB_CLIENTID -> GITHUB_CLIENT_ID (incorrect)
            incorrect = correct.replace('CLIENTID', 'CLIENT_ID')
            corrections[incorrect] = correct

            # OAUTH_GITHUB_CLIENTID -> OAUTH_GITHUB_CLIENT_ID
            oauth_incorrect = f"OAUTH_{incorrect}"
            corrections[oauth_incorrect] = correct

        # CLIENTSECRET variations (without underscore is correct)
        # BUT: OIDC_CLIENT_SECRET is correct (Heimdall uses underscore for OIDC)
        if 'CLIENTSECRET' in correct and not correct.startswith('OIDC_'):
            # GITHUB_CLIENTSECRET -> GITHUB_CLIENT_SECRET (incorrect)
            incorrect = correct.replace('CLIENTSECRET', 'CLIENT_SECRET')
            corrections[incorrect] = correct

            # OAUTH_GITHUB_CLIENTSECRET -> OAUTH_GITHUB_CLIENT_SECRET
            oauth_incorrect = f"OAUTH_{incorrect}"
            corrections[oauth_incorrect] = correct

        # BASEURL variations (no underscore is correct)
        if 'BASEURL' in correct:
            # GITLAB_BASEURL -> GITLAB_BASE_URL (incorrect)
            incorrect = correct.replace('BASEURL', 'BASE_URL')
            corrections[incorrect] = correct

        # LDAP variations with underscores (no underscore is correct)
        if correct.startswith('LDAP_'):
            # LDAP_BINDDN -> LDAP_BIND_DN (incorrect)
            if 'BINDDN' in correct:
                incorrect = correct.replace('BINDDN', 'BIND_DN')
                corrections[incorrect] = correct

            # LDAP_SEARCHBASE -> LDAP_SEARCH_BASE (incorrect)
            if 'SEARCHBASE' in correct:
                incorrect = correct.replace('SEARCHBASE', 'SEARCH_BASE')
                corrections[incorrect] = correct

            # LDAP_SEARCHFILTER -> LDAP_SEARCH_FILTER (incorrect)
            if 'SEARCHFILTER' in correct:
                incorrect = correct.replace('SEARCHFILTER', 'SEARCH_FILTER')
                corrections[incorrect] = correct

            # LDAP_MAILFIELD -> LDAP_MAIL_FIELD (incorrect)
            if 'MAILFIELD' in correct:
                incorrect = correct.replace('MAILFIELD', 'MAIL_FIELD')
                corrections[incorrect] = correct

            # LDAP_NAMEFIELD -> LDAP_NAME_FIELD (incorrect)
            if 'NAMEFIELD' in correct:
                incorrect = correct.replace('NAMEFIELD', 'NAME_FIELD')
                corrections[incorrect] = correct

    # Special case: GITLAB_SECRET variations
    if 'GITLAB_SECRET' in correct_vars:
        corrections['GITLAB_CLIENT_SECRET'] = 'GITLAB_SECRET'
        corrections['GITLAB_CLIENTSECRET'] = 'GITLAB_SECRET'
        corrections['OAUTH_GITLAB_CLIENT_SECRET'] = 'GITLAB_SECRET'
        corrections['OAUTH_GITLAB_CLIENTSECRET'] = 'GITLAB_SECRET'

    # Special case: OKTA_ISSUER_URL
    if 'OKTA_ISSUER_URL' in correct_vars:
        corrections['OKTA_ISSUER'] = 'OKTA_ISSUER_URL'

    # Special case: OAuth enabled flags (these don't exist in Heimdall)
    corrections['OAUTH_GITHUB_ENABLED'] = 'GITHUB_CLIENTID'  # Button visibility determined by CLIENTID
    corrections['OAUTH_GITLAB_ENABLED'] = 'GITLAB_CLIENTID'
    corrections['OAUTH_GOOGLE_ENABLED'] = 'GOOGLE_CLIENTID'
    corrections['OAUTH_OKTA_ENABLED'] = 'OKTA_CLIENTID'

    # Special case: OAuth URL variations
    corrections['OAUTH_GITLAB_URL'] = 'GITLAB_BASEURL'

    # Remove any self-mappings (correct -> correct)
    corrections = {k: v for k, v in corrections.items() if k != v}

    return corrections


def should_exclude(filepath: Path) -> bool:
    """Check if file should be excluded from processing."""
    return any(exclude in str(filepath) for exclude in EXCLUDE_PATTERNS)


def find_files(base_dir: Path, patterns: List[str]) -> List[Path]:
    """Find all files matching patterns."""
    files = []
    for pattern in patterns:
        files.extend(base_dir.glob(pattern))
    return [f for f in files if f.is_file() and not should_exclude(f)]


def fix_content(content: str, corrections: Dict[str, str], filepath: Path) -> Tuple[str, List[str]]:
    """
    Fix environment variable names in content.

    Returns:
        Tuple of (fixed_content, list_of_changes)
    """
    changes = []
    fixed = content

    # Sort by length (longest first) to avoid partial replacements
    sorted_incorrect = sorted(corrections.keys(), key=len, reverse=True)

    for incorrect in sorted_incorrect:
        correct = corrections[incorrect]

        # Create regex pattern that matches whole words only
        # Use word boundary \b, but also handle cases like "VARIABLE:" or "VARIABLE}"
        pattern = r'(?<![A-Z0-9_])' + re.escape(incorrect) + r'(?![A-Z0-9_])'

        # Find all matches
        matches = list(re.finditer(pattern, fixed))

        if matches:
            # Replace all occurrences
            fixed = re.sub(pattern, correct, fixed)
            changes.append(f"  {incorrect} -> {correct} ({len(matches)} occurrence(s))")

    return fixed, changes


def process_file(filepath: Path, corrections: Dict[str, str], dry_run: bool = False) -> bool:
    """
    Process a single file to fix environment variable names.

    Returns:
        True if file was modified, False otherwise
    """
    try:
        # Read file
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()

        # Fix content
        fixed, changes = fix_content(original, corrections, filepath)

        # Check if anything changed
        if original == fixed:
            return False

        # Report changes
        rel_path = filepath.relative_to(Path.cwd())
        print(f"\n📝 {rel_path}")
        for change in changes:
            print(change)

        # Write back if not dry run
        if not dry_run:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed)
            print("  ✅ Updated")
        else:
            print("  🔍 Dry run - no changes written")

        return True

    except Exception as e:
        print(f"❌ Error processing {filepath}: {e}", file=sys.stderr)
        return False


def main():
    """Main execution."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Fix ALL environment variable names across Heimdall Helm chart using fixture as source of truth'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be changed without actually modifying files'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Show files that were checked but not modified'
    )
    parser.add_argument(
        '--show-vars',
        action='store_true',
        help='Show all environment variables from fixture'
    )
    parser.add_argument(
        '--show-corrections',
        action='store_true',
        help='Show all correction mappings'
    )

    args = parser.parse_args()

    # Get base directory (go up 1 level from scripts/ to repo root)
    base_dir = Path(__file__).parent.parent
    os.chdir(base_dir)

    print("🔍 Heimdall Environment Variable Name Fixer")
    print("=" * 60)
    print(f"Base directory: {base_dir}")
    print(f"Mode: {'DRY RUN' if args.dry_run else 'LIVE'}")
    print()

    # Load environment variables from fixture
    fixture_path = base_dir / 'heimdall/data/env-vars.yaml'
    if not fixture_path.exists():
        print(f"❌ ERROR: {fixture_path} not found!", file=sys.stderr)
        return 1

    print(f"📖 Reading source of truth: {fixture_path.name}")
    correct_vars = load_canonical_vars(fixture_path)
    print(f"   Found {len(correct_vars)} environment variables")

    if args.show_vars:
        print("\n📋 Environment Variables (alphabetical):")
        for var in sorted(correct_vars):
            print(f"   - {var}")
        print()

    # Build correction map
    corrections = build_correction_map(correct_vars)
    print(f"   Generated {len(corrections)} correction patterns")

    if args.show_corrections:
        print("\n🔧 Correction Mappings:")
        for incorrect, correct in sorted(corrections.items()):
            print(f"   {incorrect} -> {correct}")
    print()

    # Find all files
    print("Finding files to process...")
    files = find_files(base_dir, TARGET_PATTERNS)
    print(f"Found {len(files)} files")
    print()

    # Process each file
    modified_count = 0
    checked_count = 0

    for filepath in sorted(files):
        checked_count += 1
        if process_file(filepath, corrections, dry_run=args.dry_run):
            modified_count += 1
        elif args.verbose:
            print(f"⏭  {filepath.relative_to(base_dir)} - no changes needed")

    # Summary
    print()
    print("=" * 60)
    print(f"✅ Complete!")
    print(f"   Checked: {checked_count} files")
    print(f"   Modified: {modified_count} files")
    print(f"   Env vars in fixture: {len(correct_vars)}")
    print(f"   Correction patterns: {len(corrections)}")

    if args.dry_run:
        print()
        print("⚠️  This was a DRY RUN - no files were actually modified")
        print("   Run without --dry-run to apply changes")

    return 0


if __name__ == '__main__':
    sys.exit(main())
