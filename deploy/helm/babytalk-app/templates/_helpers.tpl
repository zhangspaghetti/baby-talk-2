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

{{/* Validate generated utterance audio before rendering any workload. */}}
{{- define "babytalk-app.validateGeneratedAudio" -}}
{{- $audio := .Values.generatedAudio -}}
{{- $mode := required "generatedAudio.providerMode is required" $audio.providerMode -}}
{{- if not (has $mode (list "disabled" "fake" "openai" "dashscope")) -}}
{{- fail "generatedAudio.providerMode must be disabled, fake, openai, or dashscope" -}}
{{- end -}}

{{- if ne $audio.enabled (ne $mode "disabled") -}}
{{- fail "generatedAudio.enabled must match whether providerMode is disabled" -}}
{{- end -}}
{{- if not (regexMatch "^[1-8]s$" (printf "%v" $audio.timeout)) -}}
{{- fail "generatedAudio.timeout must be between 1s and 8s" -}}
{{- end -}}
{{- if or (lt (int $audio.responseMaxBytes) 1) (gt (int $audio.responseMaxBytes) 65536) -}}
{{- fail "generatedAudio.responseMaxBytes must be between 1 and 65536" -}}
{{- end -}}
{{- if or (lt (int $audio.downloadMaxBytes) 1) (gt (int $audio.downloadMaxBytes) 1048576) -}}
{{- fail "generatedAudio.downloadMaxBytes must be between 1 and 1048576" -}}
{{- end -}}
{{- if ne (required "generatedAudio.format is required" $audio.format) "mp3" -}}
{{- fail "generatedAudio.format must be mp3" -}}
{{- end -}}
{{- $voiceVersion := required "generatedAudio.voiceVersion is required" $audio.voiceVersion -}}
{{- $providerProfile := required "generatedAudio.providerProfile is required" $audio.providerProfile -}}
{{- if eq $mode "disabled" -}}
{{- if or $audio.endpoint $audio.apiKeyEnvironmentVariable $audio.model $audio.voice (gt (len $audio.allowedDownloadHosts) 0) -}}
{{- fail "disabled generated audio must not configure network provider fields" -}}
{{- end -}}
{{- end -}}
{{- if eq $mode "fake" -}}
{{- if ne .Values.practiceAi.springProfilesActive "dev" -}}
{{- fail "fake generated audio is restricted to the dev profile" -}}
{{- end -}}
{{- if or $audio.endpoint $audio.apiKeyEnvironmentVariable $audio.model $audio.voice (gt (len $audio.allowedDownloadHosts) 0) -}}
{{- fail "fake generated audio must not configure network provider fields" -}}
{{- end -}}
{{- end -}}
{{- if eq $mode "openai" -}}
{{- $endpoint := required "generatedAudio.endpoint is required" $audio.endpoint -}}
{{- if not (regexMatch "^https?://[^/?#]+(?:/[^?#]*)?$" $endpoint) -}}
{{- fail "OpenAI generatedAudio.endpoint must use HTTP or HTTPS" -}}
{{- end -}}
{{- $environmentVariable := required "generatedAudio.apiKeyEnvironmentVariable is required" $audio.apiKeyEnvironmentVariable -}}
{{- $model := required "generatedAudio.model is required" $audio.model -}}
{{- $voice := required "generatedAudio.voice is required" $audio.voice -}}
{{- if gt (len $audio.allowedDownloadHosts) 0 -}}
{{- fail "OpenAI generated audio must not configure download hosts" -}}
{{- end -}}
{{- $credentialMatch := dict "found" false -}}
{{- range $_, $provider := .Values.practiceAi.providers -}}
{{- if eq (default "" $provider.apiKeyEnvironmentVariable) $environmentVariable -}}
{{- $_ := set $credentialMatch "found" true -}}
{{- end -}}
{{- end -}}
{{- if not (get $credentialMatch "found") -}}
{{- fail "generatedAudio must reuse a configured Practice AI credential" -}}
{{- end -}}
{{- end -}}
{{- if eq $mode "dashscope" -}}
{{- $endpoint := required "generatedAudio.endpoint is required" $audio.endpoint -}}
{{- if not (regexMatch "^https://(dashscope\\.aliyuncs\\.com|[a-z0-9-]+\\.cn-beijing\\.maas\\.aliyuncs\\.com)/api/v1/services/audio/tts/SpeechSynthesizer$" $endpoint) -}}
{{- fail "DashScope generatedAudio.endpoint must be the HTTPS SpeechSynthesizer endpoint" -}}
{{- end -}}
{{- $environmentVariable := required "generatedAudio.apiKeyEnvironmentVariable is required" $audio.apiKeyEnvironmentVariable -}}
{{- if not (regexMatch "^BABY_TALK_AI_PROVIDER_[A-Z0-9_]+_API_KEY$" $environmentVariable) -}}
{{- fail "generatedAudio.apiKeyEnvironmentVariable must name a dedicated Practice AI key" -}}
{{- end -}}
{{- $model := required "generatedAudio.model is required" $audio.model -}}
{{- $voice := required "generatedAudio.voice is required" $audio.voice -}}
{{- if eq (len $audio.allowedDownloadHosts) 0 -}}
{{- fail "DashScope generated audio requires allowedDownloadHosts" -}}
{{- end -}}
{{- range $host := $audio.allowedDownloadHosts -}}
{{- if not (regexMatch "^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$" $host) -}}
{{- fail "generatedAudio.allowedDownloadHosts must contain exact lowercase hostnames" -}}
{{- end -}}
{{- end -}}
{{- $credentialMatch := dict "found" false -}}
{{- range $_, $provider := .Values.practiceAi.providers -}}
{{- if eq (default "" $provider.apiKeyEnvironmentVariable) $environmentVariable -}}
{{- $_ := set $credentialMatch "found" true -}}
{{- end -}}
{{- end -}}
{{- if not (get $credentialMatch "found") -}}
{{- fail "generatedAudio must reuse a configured Practice AI credential" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Reject a QA deployment whose services or migration job are not one candidate. */}}
{{- define "babytalk-app.validateCandidateIdentity" -}}
{{- $candidateId := required "candidate.id is required" .Values.candidate.id -}}
{{- $requiredMigrationVersion := required "candidate.requiredMigrationVersion is required" .Values.candidate.requiredMigrationVersion -}}
{{- if not (regexMatch "^[a-z0-9][a-z0-9._-]{2,127}$" $candidateId) -}}
{{- fail "candidate.id must be a safe immutable candidate identifier" -}}
{{- end -}}
{{- if not (regexMatch "^[0-9]+(?:_[0-9]+)?$" (printf "%v" $requiredMigrationVersion)) -}}
{{- fail "candidate.requiredMigrationVersion must be a Flyway version" -}}
{{- end -}}
{{- if ne $candidateId (required "appApi.image.tag is required" .Values.appApi.image.tag) -}}
{{- fail "appApi.image.tag must equal candidate.id" -}}
{{- end -}}
{{- if ne $candidateId (required "adminApi.image.tag is required" .Values.adminApi.image.tag) -}}
{{- fail "adminApi.image.tag must equal candidate.id" -}}
{{- end -}}
{{- if ne $candidateId (required "adminWeb.image.tag is required" .Values.adminWeb.image.tag) -}}
{{- fail "adminWeb.image.tag must equal candidate.id" -}}
{{- end -}}
{{- if ne $candidateId (required "gateway.image.tag is required" .Values.gateway.image.tag) -}}
{{- fail "gateway.image.tag must equal candidate.id" -}}
{{- end -}}
{{- if ne $candidateId (required "dbMigration.image.tag is required" .Values.dbMigration.image.tag) -}}
{{- fail "dbMigration.image.tag must equal candidate.id" -}}
{{- end -}}
{{- end -}}

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
    client_max_body_size {{ required "adminWeb.nginx.clientMaxBodySize is required" .Values.adminWeb.nginx.clientMaxBodySize }};

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
