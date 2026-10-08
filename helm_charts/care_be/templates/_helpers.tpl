{{/*
Expand the name of the chart.
*/}}
{{- define "care-be.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "care-be.fullname" -}}
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
{{- define "care-be.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "care-be.labels" -}}
helm.sh/chart: {{ include "care-be.chart" . }}
{{ include "care-be.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "care-be.selectorLabels" -}}
app.kubernetes.io/name: {{ include "care-be.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "care-be.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "care-be.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Container image for every care-be workload, honouring an optional private registry
*/}}
{{- define "care-be.image" -}}
{{- $imageTag := .Values.image.tag | default .Chart.AppVersion }}
{{- if .Values.registry.enabled }}
{{- if .Values.registry.port }}
{{- printf "%s:%v/%s:%s" .Values.registry.host .Values.registry.port .Values.image.repository $imageTag | quote }}
{{- else }}
{{- printf "%s/%s:%s" .Values.registry.host .Values.image.repository $imageTag | quote }}
{{- end }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository $imageTag | quote }}
{{- end }}
{{- end }}

{{/*
env and envFrom blocks shared by every care-be container
*/}}
{{- define "care-be.envBlocks" -}}
{{- if or .Values.env .Values.envFromSecretKey }}
env:
  {{- range .Values.env }}
  - name: {{ .name }}
    {{- if .valueFrom }}
    valueFrom:
      {{- if .valueFrom.secretKeyRef }}
      secretKeyRef:
        name: {{ .valueFrom.secretKeyRef.name }}
        key: {{ .valueFrom.secretKeyRef.key }}
      {{- end }}
      {{- if .valueFrom.configMapKeyRef }}
      configMapKeyRef:
        name: {{ .valueFrom.configMapKeyRef.name }}
        key: {{ .valueFrom.configMapKeyRef.key }}
      {{- end }}
    {{- else }}
    value: {{ .value | quote }}
    {{- end }}
  {{- end }}
  {{- range .Values.envFromSecretKey }}
  - name: {{ .name }}
    valueFrom:
      secretKeyRef:
        name: {{ .secretName }}
        key: {{ .key }}
  {{- end }}
{{- end }}
{{- if or .Values.envFromConfigMap .Values.envFromSecret (and .Values.configMap.enabled .Values.configMap.data) (and .Values.secret.enabled .Values.secret.data) }}
envFrom:
  {{- range .Values.envFromConfigMap }}
  - configMapRef:
      name: {{ .name }}
      {{- if .prefix }}
      prefix: {{ .prefix }}
      {{- end }}
  {{- end }}
  {{- range .Values.envFromSecret }}
  - secretRef:
      name: {{ .name }}
      {{- if .prefix }}
      prefix: {{ .prefix }}
      {{- end }}
  {{- end }}
  {{- if and .Values.configMap.enabled .Values.configMap.data }}
  - configMapRef:
      name: {{ include "care-be.fullname" . }}-config
  {{- end }}
  {{- if and .Values.secret.enabled .Values.secret.data }}
  - secretRef:
      name: {{ include "care-be.fullname" . }}-secret
  {{- end }}
{{- end }}
{{- end }}

