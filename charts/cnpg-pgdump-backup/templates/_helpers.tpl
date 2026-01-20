{{/*
Expand the name of the chart.
*/}}
{{- define "cnpg-backup.name" -}}
{{- default .Chart.Name .Values.global.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cnpg-backup.fullname" -}}
{{- if .Values.global.fullnameOverride }}
{{- .Values.global.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.global.nameOverride }}
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
{{- define "cnpg-backup.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cnpg-backup.labels" -}}
helm.sh/chart: {{ include "cnpg-backup.chart" . }}
{{ include "cnpg-backup.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cnpg-backup.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cnpg-backup.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
CronJob name
*/}}
{{- define "cnpg-backup.cronjobName" -}}
{{- printf "%s-backup" (include "cnpg-backup.fullname" .) }}
{{- end }}

{{/*
Restore Job name
*/}}
{{- define "cnpg-backup.restoreJobName" -}}
{{- printf "%s-restore" (include "cnpg-backup.fullname" .) }}
{{- end }}

{{/*
Scripts ConfigMap name
*/}}
{{- define "cnpg-backup.scriptsConfigMapName" -}}
{{- printf "%s-scripts" (include "cnpg-backup.fullname" .) }}
{{- end }}

{{/*
S3 destination URL
*/}}
{{- define "cnpg-backup.s3Destination" -}}
{{- $bucket := .Values.s3.bucket }}
{{- $prefix := .Values.s3.prefix }}
{{- $endpoint := .Values.s3.endpoint }}
{{- $usePathStyle := false }}
{{- if contains "minio" $endpoint | or (contains "s3." $endpoint) }}
{{- $usePathStyle = true }}
{{- end }}
{{- if $endpoint }}
s3://{{ $bucket }}/{{ $prefix }}?endpoint={{ $endpoint }}&s3ForcePathStyle={{ $usePathStyle }}
{{- else }}
s3://{{ $bucket }}/{{ $prefix }}
{{- end }}
{{- end }}

{{/*
Backup filename pattern
*/}}
{{- define "cnpg-backup.backupFilename" -}}
{{- .Values.cnpg.database }}_$(date +"%Y-%m-%d_%H-%M-%S").sql.gz
{{- end }}

{{/*
Container security context
*/}}
{{- define "cnpg-backup.securityContext" -}}
{{- toYaml .Values.securityContext }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "cnpg-backup.validateValues" -}}
{{- $requiredErrors := list -}}
{{- if not .Values.cnpg.secretName -}}
{{- $requiredErrors = append $requiredErrors "cnpg.secretName is required" -}}
{{- end -}}
{{- if not .Values.s3.bucket -}}
{{- $requiredErrors = append $requiredErrors "s3.bucket is required" -}}
{{- end -}}
{{- if not .Values.s3.secretName -}}
{{- $requiredErrors = append $requiredErrors "s3.secretName is required" -}}
{{- end -}}
{{- if $requiredErrors -}}
{{- printf "Missing required values:\n%s" (join "\n" $requiredErrors) | fail -}}
{{- end -}}
{{- end -}}