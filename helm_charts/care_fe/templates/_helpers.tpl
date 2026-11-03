{{/*
Expand the name of the chart.
*/}}
{{- define "care-fe.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "care-fe.fullname" -}}
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
{{- define "care-fe.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "care-fe.labels" -}}
helm.sh/chart: {{ include "care-fe.chart" . }}
{{ include "care-fe.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "care-fe.selectorLabels" -}}
app.kubernetes.io/name: {{ include "care-fe.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "care-fe.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "care-fe.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Build the Content-Security-Policy value. Origins listed in
.Values.httpRoute.csp.allowedHosts are added to script-src, style-src and
worker-src (the directives that gate code execution); everything else is
already open to any https: origin.
*/}}
{{- define "care-fe.csp" -}}
{{- $hosts := join " " (.Values.httpRoute.csp.allowedHosts | default list) -}}
{{- $hosts = ternary "" (printf " %s" $hosts) (eq $hosts "") -}}
default-src 'self' https: data: blob:;
{{- printf " script-src 'self' 'unsafe-inline' 'unsafe-eval'%s;" $hosts }}
{{- printf " style-src 'self' 'unsafe-inline'%s;" $hosts }}
{{- printf " worker-src 'self' blob:%s;" $hosts }}
{{- " img-src 'self' data: blob: https:;" }}
{{- " connect-src 'self' https: wss:;" }}
{{- " font-src 'self' data: https:;" }}
{{- " frame-src 'self' https:;" }}
{{- " object-src 'self' blob: https:;" }}
{{- " frame-ancestors 'self';" }}
{{- " base-uri 'self';" }}
{{- " form-action 'self' https:;" }}
{{- " upgrade-insecure-requests" }}
{{- end }}
