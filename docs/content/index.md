---
seo:
  title: Heimdall Helm Chart
  description: Deploy MITRE SAF Heimdall to Kubernetes.
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
Deploy MITRE SAF Heimdall to Kubernetes.

#links
  :::u-button
  ---
  to: /getting-started/quickstart
  size: xl
  trailing-icon: i-lucide-arrow-right
  ---
  Quickstart
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
  GitHub
  :::

#default
  :::prose-pre
  ---
  code: |
    # Add Helm repository
    helm repo add mitre https://mitre.github.io/heimdall-helm
    helm repo update

    # Install
    helm install heimdall mitre/heimdall \
      --namespace heimdall \
      --create-namespace
  filename: install.sh
  ---

  ```bash [install.sh]
  # Add Helm repository
  helm repo add mitre https://mitre.github.io/heimdall-helm
  helm repo update

  # Install
  helm install heimdall mitre/heimdall \
    --namespace heimdall \
    --create-namespace
  ```
  :::
::

::u-page-section{class="dark:bg-neutral-950"}
#title
Features

#features
  :::u-page-feature
  ---
  icon: i-lucide-shield-check
  ---
  #title
  High Availability

  #description
  PodDisruptionBudget, health probes, HorizontalPodAutoscaler, rolling updates.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-database
  ---
  #title
  Database Options

  #description
  Embedded PostgreSQL or external database (AWS RDS, GCP Cloud SQL, Azure Database).
  :::

  :::u-page-feature
  ---
  icon: i-lucide-lock
  ---
  #title
  Secrets Management

  #description
  Three approaches: existing secret, file-based, or inline values.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-key
  ---
  #title
  Authentication

  #description
  Local, LDAP, GitHub, GitLab, Google OAuth, Okta OIDC.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-network
  ---
  #title
  Ingress Support

  #description
  Traefik, Nginx, AWS ALB, GCP Load Balancer, Azure App Gateway, Kong.
  :::

  :::u-page-feature
  ---
  icon: i-lucide-certificate
  ---
  #title
  TLS/SSL

  #description
  Automated with cert-manager or manual certificates.
  :::
::

::u-page-section{class="dark:bg-gradient-to-b from-neutral-950 to-neutral-900"}
  :::u-page-c-t-a
  ---
  links:
    - label: Quickstart
      to: '/getting-started/quickstart'
      trailingIcon: i-lucide-arrow-right
    - label: Common Scenarios
      to: '/getting-started/common-scenarios'
      variant: subtle
      icon: i-lucide-copy
  title: Deploy Heimdall to Kubernetes
  description: 5-minute quickstart or copy-paste configurations for GitHub, GitLab, and Okta auth.
  class: dark:bg-neutral-950
  ---

  :stars-bg
  :::
::
