{{/*
Create the name of the service account to use
*/}}
{{- define "litellm.migration.serviceAccountName" -}}
{{- if .Values.litellm.serviceAccount.create }}
{{- default (include "litellm.fullname" .) .Values.litellm.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.litellm.serviceAccount.name }}
{{- end }}
{{- end }}
