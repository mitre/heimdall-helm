export default defineAppConfig({
  ui: {
    colors: {
      primary: 'blue',  // MITRE SAF branding
      neutral: 'slate'
    },
    footer: {
      slots: {
        root: 'border-t border-default',
        left: 'text-sm text-muted'
      }
    }
  },
  seo: {
    siteName: 'Heimdall Helm Chart Documentation'
  },
  header: {
    title: 'Heimdall Helm',
    to: '/',
    logo: {
      alt: 'MITRE SAF Heimdall',
      light: '',  // TODO: Add MITRE SAF logo
      dark: ''
    },
    search: true,
    colorMode: true,
    links: [{
      'icon': 'i-simple-icons-github',
      'to': 'https://github.com/mitre/heimdall-helm',
      'target': '_blank',
      'aria-label': 'heimdall-helm on GitHub'
    }]
  },
  footer: {
    credits: `MITRE SAF • © ${new Date().getFullYear()} The MITRE Corporation`,
    colorMode: false,
    links: [{
      'icon': 'i-simple-icons-github',
      'to': 'https://github.com/mitre/heimdall2',
      'target': '_blank',
      'aria-label': 'Heimdall Application on GitHub'
    }, {
      'icon': 'i-lucide-book-open',
      'to': 'https://saf.mitre.org',
      'target': '_blank',
      'aria-label': 'MITRE SAF Documentation'
    }, {
      'icon': 'i-lucide-slack',
      'to': 'https://mitre-saf.slack.com',
      'target': '_blank',
      'aria-label': 'MITRE SAF Slack'
    }]
  },
  toc: {
    title: 'On This Page',
    bottom: {
      title: 'Resources',
      edit: 'https://github.com/mitre/heimdall-helm/edit/main/docs/content',
      links: [{
        icon: 'i-lucide-star',
        label: 'Star on GitHub',
        to: 'https://github.com/mitre/heimdall-helm',
        target: '_blank'
      }, {
        icon: 'i-lucide-package',
        label: 'Helm Repository',
        to: 'https://mitre.github.io/heimdall-helm',
        target: '_blank'
      }, {
        icon: 'i-lucide-box',
        label: 'Artifact Hub',
        to: 'https://artifacthub.io/packages/helm/mitre/heimdall',
        target: '_blank'
      }]
    }
  }
})
