---
seo:
  title: Heimdall Helm Chart
  description: Deploy MITRE SAF Heimdall to Kubernetes with production-ready Helm charts.
---

::u-page-hero{class="dark:bg-gradient-to-b from-neutral-900 to-neutral-950"}
---
orientation: horizontal
---
#top
:hero-background

#title
[Heimdall]{.text-primary} Helm Chart

#description
Deploy MITRE SAF Heimdall to Kubernetes with production-ready Helm charts. Built following industry best practices with Bitnami PostgreSQL, comprehensive validation, and flexible secrets management.

#links
  :::u-button
  ---
  to: /getting-started
  size: xl
  trailing-icon: i-lucide-arrow-right
  ---
  Get started
  :::

  :::u-button
  ---
  icon: i-simple-icons-github
  color: neutral
  variant: outline
  size: xl
  to: https://github.com/mitre/heimdall-helm
  target: _blank
  ---
  View on GitHub
  :::

#default
  :::prose-pre
  ---
  code: |
    # Add Heimdall Helm repository
    helm repo add mitre https://mitre.github.io/heimdall-helm
    helm repo update

    # Install Heimdall
    helm install heimdall mitre/heimdall \
      --namespace heimdall \
      --create-namespace
  filename: install.sh
  ---

  ```bash [install.sh]
  # Add Heimdall Helm repository
  helm repo add mitre https://mitre.github.io/heimdall-helm
  helm repo update

  # Install Heimdall
  helm install heimdall mitre/heimdall \
    --namespace heimdall \
    --create-namespace
  ```
  :::
::

::u-page-section{class="dark:bg-neutral-950"}
#title
Production-Ready Helm Chart

#links
  :::u-button
  ---
  color: neutral
  size: lg
  target: _blank
  to: https://helm.sh/docs/chart_best_practices/
  trailingIcon: i-lucide-arrow-right
  variant: subtle
  ---
  Helm Best Practices
  :::

#features
  :::u-page-feature
  ---
  icon: i-lucide-shield-check
  ---
  #title
  High Availability

  #description
  Built-in PodDisruptionBudget, rolling updates, health probes, and HorizontalPodAutoscaler support for zero-downtime deployments.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-database
  ---
  #title
  Flexible Database Options

  #description
  Use embedded Bitnami PostgreSQL StatefulSet or connect to external database (AWS RDS, Google Cloud SQL, Azure Database).
  :::

  :::u-page-feature
  ---
  icon: i-lucide-lock
  ---
  #title
  Secure by Default

  #description
  Three secrets approaches (existingSecret, files, inline), values.schema.json validation, and security contexts out of the box.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-key
  ---
  #title
  Multiple Auth Providers

  #description
  Support for local authentication, LDAP, OAuth (GitHub, GitLab, Google), OIDC, and Okta with configurable callback URLs.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-gauge
  ---
  #title
  Full Observability

  #description
  Health check endpoints, Prometheus ServiceMonitor support, structured logging to stdout/stderr, and metrics exporters.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-scaling
  ---
  #title
  Auto-Scaling Ready

  #description
  HorizontalPodAutoscaler with CPU/memory metrics, configurable replica counts, and resource requests/limits.
  :::
::

::u-page-section{class="dark:bg-neutral-950"}
#title
Following Helm Best Practices

#links
  :::u-button
  ---
  color: neutral
  size: lg
  target: _blank
  to: https://github.com/mitre/vulcan-helm
  trailingIcon: i-lucide-arrow-right
  variant: subtle
  ---
  Vulcan Chart Reference
  :::

#features
  :::u-page-feature
  ---
  icon: i-lucide-file-json
  ---
  #title
  Schema Validation

  #description
  Comprehensive values.schema.json validates all 95+ environment variables with type checking, enums, and required field enforcement.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-code
  ---
  #title
  Database Abstraction Helpers

  #description
  Template helpers abstract embedded vs external database configuration, making it easy to switch between deployment modes.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-package
  ---
  #title
  Bitnami Dependencies

  #description
  Uses battle-tested Bitnami PostgreSQL subchart with millions of deployments, built-in HA, backup/restore, and metrics.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-git-branch
  ---
  #title
  Helm Hooks

  #description
  Database migrations run via Helm hooks before app deployment. Automatic admin user creation with post-install jobs.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-network
  ---
  #title
  Network Policies

  #description
  Optional NetworkPolicy resources for zero-trust security. Restrict traffic between pods and external services.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-certificate
  ---
  #title
  Custom CA Certificates

  #description
  Inject custom CA certificates for corporate environments. Support for both system-wide and application-specific trust stores.
  :::
::

::u-page-section{class="dark:bg-gradient-to-b from-neutral-950 to-neutral-900"}
  :::u-page-c-t-a
  ---
  links:
    - label: Start deploying
      to: '/getting-started'
      trailingIcon: i-lucide-arrow-right
    - label: View Chart Repository
      to: 'https://mitre.github.io/heimdall-helm'
      target: _blank
      variant: subtle
      icon: i-lucide-package
  title: Ready to deploy Heimdall to Kubernetes?
  description: Join organizations using MITRE SAF for security automation. Install this chart and start visualizing InSpec results today.
  class: dark:bg-neutral-950
  ---

  :stars-bg
  :::
::
