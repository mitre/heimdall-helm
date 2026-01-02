<template>
  <div v-if="envVarsData?.meta?.environment_variables">
    <MDC :value="generateCategoryMdc(categoryVars)" />
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  category?: string
}>()

const { data: envVarsData } = await useAsyncData('env-vars', () =>
  queryCollection('envVars').first()
)

const categoryTitles: Record<string, string> = {
  'nodejs': 'Node.js Configuration',
  'application': 'Application Settings',
  'admin': 'Admin User',
  'auth_local': 'Local Authentication',
  'auth_session': 'Session Management',
  'auth_jwt': 'JWT & API Keys',
  'ui': 'UI Customization',
  'database': 'Database Connection',
  'database_ssl': 'Database SSL/TLS',
  'auth_oauth': 'OAuth Providers',
  'auth_oidc': 'OpenID Connect (OIDC)',
  'auth_ldap': 'LDAP Authentication',
  'integration': 'External Integrations',
  'proxy': 'Proxy Configuration'
}

const categoryVars = computed<any[]>(() => {
  const vars = envVarsData.value?.meta?.environment_variables
  if (!vars || !Array.isArray(vars)) {
    return []
  }

  // Filter by category prop
  const filtered = props.category
    ? vars.filter((v: any) => v.category === props.category)
    : vars

  // Sort by name
  return filtered.sort((a: any, b: any) => a.name.localeCompare(b.name))
})

function generateCategoryMdc(vars: any[]): string {
  let mdc = '::field-group\n'

  vars.forEach(varDef => {
    mdc += '\n'

    // Build props string for field component
    const props = [`name="${varDef.name}"`]
    if (varDef.type) props.push(`type="${varDef.type}"`)
    if (varDef.required) props.push('required')

    mdc += `::field{${props.join(' ')}}\n`

    // Just description in the field slot
    if (varDef.description) {
      mdc += varDef.description + '\n'
    }

    mdc += '::\n\n'

    // Metadata as table outside the field component
    const tableRows: string[] = []

    if (varDef.default !== null && varDef.default !== undefined && varDef.default !== '') {
      tableRows.push(`| Default | \`${varDef.default}\` |`)
    }

    if (varDef.examples && varDef.examples.length > 0) {
      const examplesList = varDef.examples.map((ex: any) => `\`${ex}\``).join(', ')
      tableRows.push(`| Examples | ${examplesList} |`)
    }

    if (varDef.provider) {
      const providerName = varDef.provider.charAt(0).toUpperCase() + varDef.provider.slice(1)
      tableRows.push(`| Provider | ${providerName} |`)
    }

    if (varDef.required_pair) {
      tableRows.push(`| Requires | \`${varDef.required_pair}\` |`)
    }

    if (varDef.validation) {
      if (varDef.validation.pattern) {
        tableRows.push(`| Pattern | \`${varDef.validation.pattern}\` |`)
      }
      if (varDef.validation.min_length) {
        tableRows.push(`| Min length | ${varDef.validation.min_length} |`)
      }
      if (varDef.validation.error) {
        tableRows.push(`| Validation | ${varDef.validation.error} |`)
      }
    }

    if (varDef.notes) {
      tableRows.push(`| Note | ${varDef.notes} |`)
    }

    if (tableRows.length > 0) {
      mdc += '| Property | Value |\n'
      mdc += '|----------|-------|\n'
      mdc += tableRows.join('\n') + '\n\n'
    }
  })

  mdc += '::\n'
  return mdc
}
</script>
