{{/*
Expand the name of the chart.
*/}}
{{- define "babytalk-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "babytalk-app.fullname" -}}
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
{{- define "babytalk-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "babytalk-app.labels" -}}
helm.sh/chart: {{ include "babytalk-app.chart" . }}
{{ include "babytalk-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "babytalk-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "babytalk-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-scoped resource name.
*/}}
{{- define "babytalk-app.componentFullname" -}}
{{- printf "%s-%s" (include "babytalk-app.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Component selector labels.
*/}}
{{- define "babytalk-app.componentSelectorLabels" -}}
{{ include "babytalk-app.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Component labels.
*/}}
{{- define "babytalk-app.componentLabels" -}}
helm.sh/chart: {{ include "babytalk-app.chart" .root }}
{{ include "babytalk-app.componentSelectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Create the name of the shared ConfigMap.
*/}}
{{- define "babytalk-app.configMapName" -}}
{{- printf "%s-shared-config" (include "babytalk-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the shared Secret.
*/}}
{{- define "babytalk-app.secretName" -}}
{{- printf "%s-shared-secret" (include "babytalk-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Create the dedicated Practice discovery owner-key Secret name. */}}
{{- define "babytalk-app.practiceDiscoveryOwnerKeySecretName" -}}
{{- printf "%s-practice-discovery-owner-key" (include "babytalk-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Create the name of the dedicated Practice AI runtime ConfigMap. */}}
{{- define "babytalk-app.practiceAiRuntimeConfigMapName" -}}
{{- printf "%s-practice-ai-runtime" (include "babytalk-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/* Create the name of the dedicated Practice AI Secret. */}}
{{- define "babytalk-app.practiceAiSecretName" -}}
{{- printf "%s-practice-ai-secret" (include "babytalk-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the admin-web proxy ConfigMap.
*/}}
{{- define "babytalk-app.adminWebProxyConfigMapName" -}}
{{- printf "%s-admin-web-proxy" (include "babytalk-app.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "babytalk-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "babytalk-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Render the admin-web nginx proxy config from chart truth.
*/}}
{{- define "babytalk-app.adminWebNginxConfig" -}}
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://{{ include "babytalk-app.componentFullname" (dict "root" . "component" "gateway") }}:{{ .Values.gateway.service.port }};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
{{- end }}
