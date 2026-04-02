{{/*
	Name helpers for microservice

	We keep these very small because most naming
	is driven directly from .Values.name in the
	Deployment/StatefulSet templates.
*/}}

{{- define "microservice.name" -}}
{{- default .Values.name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "microservice.fullname" -}}
{{- include "microservice.name" . -}}
{{- end }}

{{/*
	Common labels helper, based on .Values.name
*/}}
{{- define "microservice.labels" -}}
app.kubernetes.io/name: {{ .Values.name | quote }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{/*
	ServiceAccount name helper; uses the explicit
	.Values.serviceAccountName when set, otherwise
	falls back to the chart name.
*/}}
{{- define "microservice.serviceAccountName" -}}
{{- if .Values.serviceAccountName }}
{{- .Values.serviceAccountName -}}
{{- else -}}
{{- include "microservice.name" . -}}
{{- end -}}
{{- end }}

