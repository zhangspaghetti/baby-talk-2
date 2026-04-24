{{/*
Expand the name of the chart.
*/}}
{{- define "babytalk.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "babytalk.fullname" -}}
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
{{- define "babytalk.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "babytalk.labels" -}}
helm.sh/chart: {{ include "babytalk.chart" . }}
{{ include "babytalk.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "babytalk.selectorLabels" -}}
app.kubernetes.io/name: {{ include "babytalk.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component-scoped resource name.
*/}}
{{- define "babytalk.componentFullname" -}}
{{- printf "%s-%s" (include "babytalk.fullname" .root) .component | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Component selector labels.
*/}}
{{- define "babytalk.componentSelectorLabels" -}}
{{ include "babytalk.selectorLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end }}

{{/*
Component labels.
*/}}
{{- define "babytalk.componentLabels" -}}
helm.sh/chart: {{ include "babytalk.chart" .root }}
{{ include "babytalk.componentSelectorLabels" . }}
{{- if .root.Chart.AppVersion }}
app.kubernetes.io/version: {{ .root.Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
{{- end }}

{{/*
Create the name of the shared ConfigMap.
*/}}
{{- define "babytalk.configMapName" -}}
{{- printf "%s-shared-config" (include "babytalk.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the shared Secret.
*/}}
{{- define "babytalk.secretName" -}}
{{- printf "%s-shared-secret" (include "babytalk.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the admin-web proxy ConfigMap.
*/}}
{{- define "babytalk.adminWebProxyConfigMapName" -}}
{{- printf "%s-admin-web-proxy" (include "babytalk.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "babytalk.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "babytalk.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Render the admin-web nginx proxy config from chart truth.
*/}}
{{- define "babytalk.adminWebNginxConfig" -}}
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location /api/ {
        proxy_pass http://{{ include "babytalk.componentFullname" (dict "root" . "component" "admin-api") }}:{{ .Values.adminApi.service.port }};
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /actuator/ {
        proxy_pass http://{{ include "babytalk.componentFullname" (dict "root" . "component" "admin-api") }}:{{ .Values.adminApi.service.port }};
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
