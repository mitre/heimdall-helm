# Changelog

All notable changes to the Heimdall Helm chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-01

### Added
- **Bitnami PostgreSQL Subchart**: Replaced standalone PostgreSQL templates with battle-tested Bitnami PostgreSQL subchart (~18.2.0)
- **Three Secrets Approaches**: Support for existingSecret (production), secretsFiles (development), and inline secrets (CI/CD)
- **values.schema.json**: JSON Schema validation for 95+ configuration variables
- **Template Helpers**: Database abstraction helpers for embedded vs external PostgreSQL
- **envFrom Pattern**: Simplified environment variable injection using ConfigMap and Secret references
- **Custom CA Certificates**: Dynamic certificate concatenation with init container
- **Health Probes**: Comprehensive startup, liveness, and readiness probe configuration
- **High Availability**: PodDisruptionBudget and HorizontalPodAutoscaler support
- **Network Policy**: Optional NetworkPolicy for traffic restriction (DNS, PostgreSQL, ingress)
- **Rolling Updates**: StatefulSet updateStrategy for zero-downtime deployments
- **Gateway API**: Support for Gateway API as alternative to Ingress
- **ServiceAccount**: Configurable ServiceAccount with cloud IAM annotation support
- **Helm Tests**: Comprehensive test suite with 102 unit tests using helm-unittest
- **Documentation Site**: Nuxt UI-based documentation at https://mitre.github.io/heimdall-helm

### Changed
- **Chart Name**: Renamed from `heimdall2` to `heimdall` for consistency
- **Repository Name**: Renamed from `heimdall2-helm` to `heimdall-helm`
- **Database Migrations**: Now handled automatically by application on startup (Sequelize)
- **StatefulSet Simplification**: Reduced from 482 lines to 168 lines (65% reduction)
- **Ingress Default**: Changed default ingress controller from nginx to traefik (nginx retiring March 2026)
- **PostgreSQL Version**: Updated from manual deployment to Bitnami subchart 18.2.0

### Fixed
- **Issue #6**: Duplicate host configuration in ingress (closed)
- **Issue #33**: CA certificate filename now dynamic instead of hardcoded

### Security
- Pod security contexts configured by default
- Non-root container execution
- Read-only root filesystem support
- NetworkPolicy for traffic restriction (optional)

### Documentation
- Comprehensive Nuxt UI documentation site (13 pages)
- Auto-generated README.md using helm-docs
- Migration guides for upgrading from v3.3.3
- Architecture diagrams and design decision documentation
- OAuth/OIDC configuration guides

### Testing
- 102 unit tests with helm-unittest
- Helm test templates for connection validation
- Strict linting with `helm lint --strict`
- JSON Schema validation for values.yaml
- CI/CD workflows for automated testing

### Migration from v3.3.3

This is a **major version upgrade** with breaking changes. Please review the [Migration Guide](docs/content/4.helm-chart/architecture.md#chart-version-history) before upgrading.

**Key Breaking Changes**:
- Chart name changed from `heimdall2` to `heimdall`
- PostgreSQL now managed by Bitnami subchart
- Values structure reorganized under `heimdall.*` namespace
- Secrets management uses three-approach priority system

**Upgrade Path**:
1. Backup existing Heimdall database
2. Export current configuration
3. Update values.yaml to v1.0.0 structure
4. Test in non-production environment
5. Perform upgrade with `helm upgrade`

See documentation for detailed migration instructions.

## [Unreleased]

### Planned
- Database migration Helm hooks (Phase 2 enhancement)
- Admin user creation job (Phase 5)
- OAuth/OIDC GitLab authentication debugging (Phase 5, Issue tracked separately)
- Backup/restore procedures
- Monitoring integration guides (Prometheus, Grafana)

### Open Issues Being Investigated
- **Issue #13**: PV reconnection behavior verification needed
- **Issue #24**: Consider moving databasePassword to stringData section
- **Issue #22**: Additional validation utilities beyond JSON Schema
- **Issue #29**: UBI 9 for init container (currently uses postgres:16-alpine)

---

[1.0.0]: https://github.com/mitre/heimdall-helm/releases/tag/v1.0.0
