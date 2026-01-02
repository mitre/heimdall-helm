# Documentation Improvement Plan

Analysis of all 14 Helm chart documentation files for MDC component usage, grammar, and clarity improvements.

## Available MDC Components (from essentials/prose-components.md)

### Structural Components
- `::accordion` / `:::accordion-item` - Collapsible FAQ-style content
- `::tabs` / `:::tabs-item` - Tabbed content (great for code alternatives)
- `::steps` - Auto-numbered sequential instructions
- `::collapsible` - Hide/reveal optional content

### Content Components
- `::card` / `::card-group` - Highlight features, resources
- `::field` / `::field-group` - Document properties/parameters
- `::callout` - Generic callout
- `::note` - Additional information (blue)
- `::tip` - Helpful suggestions (green)
- `::warning` - Caution about unexpected results (yellow)
- `::caution` - Cannot be undone actions (red)

### Code Components
- `::code-group` - Multiple code blocks in tabs
- `::code-tree` - File tree view
- `::code-preview` - Show code + output
- `::code-collapse` - Collapsible long code blocks

### Inline
- `:icon{name="..."}` - Insert icons
- `:kbd{value="..."}` - Keyboard shortcuts
- `:badge` - Status indicators

## File-by-File Improvements Needed

### 1. getting-started/01.overview.md
**Current**: 81 lines, 243 words
**Issues**:
- Design Principles section uses bullet lists - could be `::card-group`
- No obvious grammar issues

**Improvements**:
- Convert Design Principles to card-group for visual appeal
- Already has proper semantic callouts

### 2. getting-started/02.database.md
**Current**: 388 lines, 923 words, 17 code blocks, 3 callouts
**Issues**:
- Many code examples for different scenarios - could use `::tabs` or `::code-group`
- Some callouts may not be semantic (::tip, ::warning, ::note)

**Improvements**:
- Group embedded vs external database examples in `::tabs`
- Verify all 3 callouts use correct semantic types
- Consider `::steps` for configuration workflow

### 3. getting-started/03.secrets.md
**Current**: 214 lines, 615 words, 12 code blocks, 4 callouts
**Issues**:
- Three approaches presented linearly - could be `::tabs`
- CI/CD example vs dev example could be tabbed

**Improvements**:
- Use `::tabs` for the three secrets approaches
- Verify callout semantic types
- Add `::caution` for security warnings

### 4. configuration/01.environment-variables.md
**Current**: 291 lines, 721 words, 8 code blocks, numbered lists, 4 callouts
**Issues**:
- Configuration Loading Strategy (numbered list) → `::steps`
- Environment variable tables → `::field-group`
- File/inline/CLI override examples → `::tabs` or `::code-group`

**Improvements**:
- Convert numbered "layered approach" to `::steps`
- Replace tables with `::field-group` for env vars
- Group override examples in `::tabs`

### 5. configuration/02.validation.md
**Current**: 390 lines, 1097 words, 19 code blocks, 3 callouts
**Issues**:
- Multiple provider validations (GitHub, GitLab, Google, OIDC, Okta) - could be `::accordion`
- Correct/incorrect examples → `::code-group` with tabs
- Troubleshooting section → `::accordion`

**Improvements**:
- Use `::accordion` for each OAuth provider's validation rules
- Convert correct/incorrect examples to `::code-group`
- Make troubleshooting collapsible with `::accordion`

### 6. configuration/03.ingress.md
**Current**: 509 lines, 1102 words, 29 code blocks, numbered lists
**Issues**:
- Multiple ingress controller examples (Traefik, Nginx, Kong) → `::tabs`
- Numbered setup steps → `::steps`

**Improvements**:
- Use `::tabs` for different ingress controllers
- Convert numbered lists to `::steps`
- Consider `::accordion` for controller-specific configuration

### 7. configuration/04.tls.md
**Current**: 571 lines, 1364 words, 41 code blocks, numbered lists
**Issues**:
- Automated vs Manual TLS → `::tabs`
- cert-manager setup → `::steps`
- Multiple certificate examples → `::tabs` or `::code-group`

**Improvements**:
- Major refactor: use `::tabs` at top level (Automated / Manual)
- Convert installation steps to `::steps`
- Group certificate examples

### 8. configuration/05.custom-ca-certificates.md
**Current**: 401 lines, 1185 words, 31 code blocks, numbered lists
**Issues**:
- Single cert vs multiple certs → `::tabs`
- Configuration steps → `::steps`
- Many code examples → `::code-group`

**Improvements**:
- Use `::tabs` for usage patterns
- Convert numbered instructions to `::steps`

### 9. advanced/01.database-migrations.md
**Current**: 278 lines, 1101 words, 13 code blocks, numbered lists
**Issues**:
- Migration workflow steps → `::steps`
- Automatic vs Helm Hook approach → `::tabs`

**Improvements**:
- Convert migration steps to `::steps`
- Tab between approaches
- Add `::warning` callouts for migration risks

### 10. advanced/02.health-and-availability.md
**Current**: 663 lines, 1917 words, 43 code blocks, numbered lists
**Issues**:
- Startup/Liveness/Readiness probes → `::tabs`
- Configuration examples → `::code-group`
- Testing steps → `::steps`

**Improvements**:
- Use `::tabs` for different probe types
- Group related code examples
- Convert testing workflows to `::steps`

### 11. reference/01.values-schema.md
**Current**: 290 lines, 748 words, 16 code blocks, 2 callouts
**Issues**:
- Schema validation examples → `::code-group`
- Pattern examples → `::code-group`

**Improvements**:
- Group valid/invalid examples in tabs
- Verify callout types

### 12. reference/02.template-helpers.md
**Current**: 408 lines, 1178 words, 25 code blocks, numbered lists, 1 callout
**Issues**:
- Multiple helper examples → `::code-group`
- Usage steps → `::steps`

**Improvements**:
- Tab between different helper uses
- Convert workflows to `::steps`

### 13. reference/03.architecture.md
**Current**: 405 lines, 1408 words, 7 code blocks, 2 callouts
**Issues**:
- Before/after comparisons → `::code-group` with tabs
- Design decision sections → `::card-group`

**Improvements**:
- Use tabs for old vs new patterns
- Convert decision sections to cards

### 14. development/01.testing.md
**Current**: 310 lines, 927 words, 11 code blocks
**Issues**:
- Test examples → `::code-group`
- Running tests workflow → `::steps`
- Pre-commit checklist → interactive checklist

**Improvements**:
- Tab between test types
- Convert workflows to `::steps`

## Grammar & Clarity Issues Found

### Passive Voice
- Minimal passive voice detected across all docs
- Most sentences use active voice appropriately

### Clarity Issues
- Some sections have unclear pronoun references ("this", "it", "that" without clear antecedent)
- Need to review each instance manually

### Consistency Issues
- Mixed use of "you" vs "we" vs passive constructions
- Should standardize to imperative ("Configure X") or second person ("You can configure X")

## Priority Order for Implementation

### Phase 1: High-Impact Structural Improvements
1. `configuration/02.validation.md` - Add accordion for OAuth providers
2. `configuration/04.tls.md` - Major refactor with tabs (Automated/Manual)
3. `configuration/03.ingress.md` - Tabs for different controllers
4. `getting-started/03.secrets.md` - Tabs for three approaches

### Phase 2: Code Organization
1. Add `::code-group` for examples with alternatives (helm/kubectl, dev/prod)
2. Add `::steps` for all numbered instruction lists
3. Collapse long code blocks with `::code-collapse`

### Phase 3: Content Enhancement
1. Convert environment variable tables to `::field-group`
2. Verify all callouts use semantic types (note/tip/warning/caution)
3. Add `::card-group` for feature highlights

### Phase 4: Polish
1. Grammar review for pronoun clarity
2. Standardize voice (imperative mode preferred)
3. Add keyboard shortcuts with `:kbd` where applicable

## Next Steps

1. Start with Phase 1 priority files
2. Make one comprehensive commit per file
3. Test Nuxt rendering after each change
4. Verify all links still work
5. Check mobile responsiveness of new components
