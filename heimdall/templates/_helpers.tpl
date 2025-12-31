{{/*
Expand the name of the chart.
*/}}
{{- define "heimdall.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "heimdall.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "heimdall.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "heimdall.labels" -}}
helm.sh/chart: {{ include "heimdall.chart" . }}
{{ include "heimdall.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "heimdall.selectorLabels" -}}
app.kubernetes.io/name: {{ include "heimdall.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "heimdall.serviceAccountName" -}}
{{- if .Values.heimdall.serviceAccount.create }}
{{- default (include "heimdall.fullname" .) .Values.heimdall.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.heimdall.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
==============================================================================
Database Abstraction Helpers
==============================================================================
These helpers abstract the difference between using embedded PostgreSQL
StatefulSet and external database, making templates cleaner and more maintainable.
*/}}

{{/*
Get the PostgreSQL fullname (when using embedded StatefulSet)
*/}}
{{- define "heimdall.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "heimdall.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Get the database host
Returns: PostgreSQL service name (if postgresql.enabled=true) or external host
*/}}
{{- define "heimdall.databaseHost" -}}
{{- if .Values.postgresql.enabled }}
{{- include "heimdall.postgresql.fullname" . }}
{{- else }}
{{- required "externalDatabase.host is required when postgresql.enabled=false" .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{/*
Get the database port
Returns: PostgreSQL port from values (default 5432)
*/}}
{{- define "heimdall.databasePort" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.primary.service.ports.postgresql | default 5432 }}
{{- else }}
{{- .Values.externalDatabase.port | default 5432 }}
{{- end }}
{{- end }}

{{/*
Get the database name
Returns: Database name from Bitnami subchart or external database
*/}}
{{- define "heimdall.databaseName" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.database }}
{{- else }}
{{- .Values.externalDatabase.database }}
{{- end }}
{{- end }}

{{/*
Get the database username
Returns: Database username from values (default postgres)
*/}}
{{- define "heimdall.databaseUsername" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.username | default "postgres" }}
{{- else }}
{{- .Values.externalDatabase.username }}
{{- end }}
{{- end }}

{{/*
Get the secret name containing database credentials
Returns: PostgreSQL secret (embedded), external secret, or Heimdall secret
Priority:
  1. Embedded PostgreSQL: Uses Bitnami's auto-generated secret
  2. External DB with existingSecret: Uses user-provided secret
  3. External DB without existingSecret: Uses Heimdall secret
*/}}
{{- define "heimdall.databaseSecretName" -}}
{{- if .Values.postgresql.enabled }}
  {{- if .Values.postgresql.auth.existingSecret }}
{{- .Values.postgresql.auth.existingSecret }}
  {{- else }}
{{- include "heimdall.postgresql.fullname" . }}
  {{- end }}
{{- else }}
  {{- if .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecret }}
  {{- else }}
{{- include "heimdall.fullname" . }}-secrets
  {{- end }}
{{- end }}
{{- end }}

{{/*
Get the secret key for database password
Returns: Key name within secret (differs between embedded and external DB)
  - Embedded PostgreSQL: "postgres-password" (Bitnami standard)
  - External database: "DATABASE_PASSWORD" (Heimdall standard)
*/}}
{{- define "heimdall.databaseSecretKey" -}}
{{- if .Values.postgresql.enabled }}
{{- print "postgres-password" }}
{{- else }}
{{- print "DATABASE_PASSWORD" }}
{{- end }}
{{- end }}

{{/*
Construct DATABASE_URL for Sequelize
Format: postgresql://username:password@host:port/database
Note: Password is injected at runtime via $(DATABASE_PASSWORD) env var substitution
*/}}
{{- define "heimdall.databaseURL" -}}
{{- printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%s/%s"
    (include "heimdall.databaseUsername" .)
    (include "heimdall.databaseHost" .)
    (include "heimdall.databasePort" . | toString)
    (include "heimdall.databaseName" .) }}
{{- end }}
